using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using HavenApi.Shared.Exceptions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Utils;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación de almacenamiento de comprobantes sobre la API REST de Supabase Storage.
/// </summary>
public class ComprobanteStorageService : IComprobanteStorageService
{
    private readonly HttpClient _httpClient;
    private readonly StorageOptions _options;
    private readonly ILogger<ComprobanteStorageService> _logger;
    private readonly string _supabaseUrl;
    private readonly string _serviceRoleKey;

    public ComprobanteStorageService(
        HttpClient httpClient,
        IConfiguration configuration,
        IOptions<StorageOptions> options,
        ILogger<ComprobanteStorageService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _options = options?.Value ?? new StorageOptions();
        _supabaseUrl = (configuration["Supabase:Url"] ?? throw new InvalidOperationException("Supabase:Url is not configured.")).TrimEnd('/');
        _serviceRoleKey = configuration["Supabase:ServiceRoleKey"] ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
    }

    private void AddAuthHeaders(HttpRequestMessage request)
    {
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
    }

    private async Task<HttpResponseMessage> SendRequestAsync(HttpRequestMessage request, CancellationToken cancellationToken)
    {
        try
        {
            return await _httpClient.SendAsync(request, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Error de red al comunicarse con Supabase Storage en {Endpoint}", request.RequestUri?.AbsolutePath);
            throw new SupabaseUnavailableException("Ocurrió un error de red al comunicarse con Supabase Storage.", ex);
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogError(ex, "Timeout al comunicarse con Supabase Storage en {Endpoint}", request.RequestUri?.AbsolutePath);
            throw new SupabaseUnavailableException("La solicitud a Supabase Storage excedió el tiempo límite.", ex);
        }
    }

    private async Task EnsureSuccessAsync(HttpResponseMessage response, string rutaObjeto, CancellationToken cancellationToken)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
        _logger.LogWarning("Operación en Supabase Storage falló con código HTTP {StatusCode}", response.StatusCode);

        if (response.StatusCode == HttpStatusCode.NotFound ||
            errorBody.Contains("not found", StringComparison.OrdinalIgnoreCase) ||
            errorBody.Contains("NoSuchKey", StringComparison.OrdinalIgnoreCase))
        {
            throw new KeyNotFoundException($"El comprobante no fue encontrado en la ruta '{rutaObjeto}'.");
        }

        if (response.StatusCode == HttpStatusCode.Conflict ||
            errorBody.Contains("duplicate", StringComparison.OrdinalIgnoreCase) ||
            errorBody.Contains("already exists", StringComparison.OrdinalIgnoreCase))
        {
            throw new PostgrestException((int)HttpStatusCode.Conflict, "409", "Ya existe un comprobante en la ruta especificada.");
        }

        throw PostgrestErrorTranslator.ParseAndTranslate(errorBody);
    }

    public async Task<string> SubirAsync(
        byte[] bytes,
        string contentType,
        string rutaObjeto,
        CancellationToken cancellationToken = default)
    {
        ComprobanteRutaHelper.ValidarRuta(rutaObjeto);
        ArgumentNullException.ThrowIfNull(bytes);

        if (bytes.Length == 0)
        {
            throw new ArgumentException("El contenido del archivo no puede estar vacío.", nameof(bytes));
        }

        if (string.IsNullOrWhiteSpace(contentType))
        {
            throw new ArgumentException("El Content-Type es obligatorio.", nameof(contentType));
        }

        var rutaLimpia = rutaObjeto.TrimStart('/');
        var url = $"{_supabaseUrl}/storage/v1/object/{_options.BucketComprobantes}/{rutaLimpia}";

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request);
        request.Headers.Add("x-upsert", "false"); // No sobrescribe si ya existe

        request.Content = new ByteArrayContent(bytes);
        request.Content.Headers.ContentType = MediaTypeHeaderValue.Parse(contentType);

        var response = await SendRequestAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.Conflict)
        {
            throw new PostgrestException((int)HttpStatusCode.Conflict, "409", "Ya existe un comprobante en la ruta especificada.");
        }

        await EnsureSuccessAsync(response, rutaObjeto, cancellationToken);
        return rutaObjeto;
    }

    public async Task<string> CrearUrlFirmadaAsync(
        string rutaObjeto,
        int? expiracionSegundos = null,
        CancellationToken cancellationToken = default)
    {
        ComprobanteRutaHelper.ValidarRuta(rutaObjeto);

        int segundos = expiracionSegundos ?? _options.UrlExpiracionSegundos;
        if (segundos <= 0 || segundos > _options.MaxExpiracionSegundos)
        {
            throw new ArgumentOutOfRangeException(
                nameof(expiracionSegundos),
                $"Los segundos de expiración deben estar entre 1 y {_options.MaxExpiracionSegundos}.");
        }

        var rutaLimpia = rutaObjeto.TrimStart('/');
        var url = $"{_supabaseUrl}/storage/v1/object/sign/{_options.BucketComprobantes}/{rutaLimpia}";

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request);

        var payload = new { expiresIn = segundos };
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request, cancellationToken);
        if (response.StatusCode == HttpStatusCode.NotFound)
        {
            throw new KeyNotFoundException($"El comprobante no fue encontrado en la ruta '{rutaObjeto}'.");
        }

        await EnsureSuccessAsync(response, rutaObjeto, cancellationToken);

        using var jsonDoc = await JsonDocument.ParseAsync(await response.Content.ReadAsStreamAsync(cancellationToken), cancellationToken: cancellationToken);
        string? rawSignedUrl = null;

        if (jsonDoc.RootElement.TryGetProperty("signedURL", out var propSignedUrl) ||
            jsonDoc.RootElement.TryGetProperty("signedUrl", out propSignedUrl))
        {
            rawSignedUrl = propSignedUrl.GetString();
        }

        if (string.IsNullOrWhiteSpace(rawSignedUrl))
        {
            throw new InvalidOperationException("Supabase Storage no devolvió una URL firmada válida.");
        }

        if (rawSignedUrl.StartsWith("http://", StringComparison.OrdinalIgnoreCase) ||
            rawSignedUrl.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
        {
            return rawSignedUrl;
        }

        // Supabase devuelve signedURL relativo a /storage/v1 (ej. "/object/sign/..."),
        // así que hay que anteponer ese prefijo si no viene incluido.
        var relativePath = rawSignedUrl.StartsWith('/') ? rawSignedUrl : $"/{rawSignedUrl}";
        if (!relativePath.StartsWith("/storage/v1/", StringComparison.OrdinalIgnoreCase))
        {
            relativePath = $"/storage/v1{relativePath}";
        }
        return $"{_supabaseUrl}{relativePath}";
    }

    public async Task EliminarAsync(string rutaObjeto, CancellationToken cancellationToken = default)
    {
        ComprobanteRutaHelper.ValidarRuta(rutaObjeto);

        var rutaLimpia = rutaObjeto.TrimStart('/');
        var url = $"{_supabaseUrl}/storage/v1/object/{_options.BucketComprobantes}/{rutaLimpia}";

        using var request = new HttpRequestMessage(HttpMethod.Delete, url);
        AddAuthHeaders(request);

        var response = await SendRequestAsync(request, cancellationToken);
        await EnsureSuccessAsync(response, rutaObjeto, cancellationToken);
    }
}
