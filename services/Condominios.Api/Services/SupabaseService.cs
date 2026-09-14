using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Condominios.Api.DTOs;
using HavenApi.Shared.Exceptions;

namespace Condominios.Api.Services;

public class SupabaseService : ISupabaseService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<SupabaseService> _logger;
    private readonly string _supabaseUrl;
    private readonly string _anonKey;
    private readonly string _serviceRoleKey;

    public SupabaseService(HttpClient httpClient, IConfiguration configuration, ILogger<SupabaseService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _supabaseUrl = configuration["Supabase:Url"] ?? throw new InvalidOperationException("Supabase:Url is not configured.");
        _anonKey = configuration["Supabase:AnonKey"] ?? throw new InvalidOperationException("Supabase:AnonKey is not configured.");
        _serviceRoleKey = configuration["Supabase:ServiceRoleKey"] ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
    }

    private async Task<HttpResponseMessage> SendRequestAsync(HttpRequestMessage request)
    {
        try
        {
            return await _httpClient.SendAsync(request);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Network error when calling Supabase at {Url}", request.RequestUri);
            throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogError(ex, "Timeout when calling Supabase at {Url}", request.RequestUri);
            throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
        }
    }

    private async Task<T?> ParseJsonAsync<T>(HttpContent content)
    {
        try
        {
            return await content.ReadFromJsonAsync<T>();
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse JSON response from Supabase.");
            throw new SupabaseResponseException("Received an invalid JSON response from Supabase.", ex);
        }
    }

    public async Task<List<CondominioDto>> GetCondominiosAsync(string? nombre = null)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_condominios?select=*";
        if (!string.IsNullOrWhiteSpace(nombre))
        {
            var filterValue = Uri.EscapeDataString(nombre.Trim());
            requestUrl += $"&nombre=ilike.*{filterValue}*";
        }

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch condominios. Status: {StatusCode}", response.StatusCode);
            return new List<CondominioDto>();
        }

        var condominios = await ParseJsonAsync<List<CondominioDto>>(response.Content);
        return condominios ?? new List<CondominioDto>();
    }

    public async Task<CondominioDto?> GetCondominioByIdAsync(Guid id)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_condominios?id=eq.{id}&select=*";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch condominio {Id}. Status: {StatusCode}", id, response.StatusCode);
            return null;
        }

        var condominios = await ParseJsonAsync<List<CondominioDto>>(response.Content);
        return condominios?.FirstOrDefault();
    }

    public async Task<(CondominioDto? condominio, string? error)> CrearCondominioAsync(CreateCondominioRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/alta_condominio";
        var payload = new { p_nombre = dto.Nombre };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("CrearCondominio failed. Status: {StatusCode}, Body: {Body}", response.StatusCode, errorBody);
            return (null, $"Error al crear condominio: {errorBody}");
        }

        var result = await ParseJsonAsync<CondominioDto>(response.Content);
        return (result, null);
    }

    public async Task<bool> DesactivarCondominioAsync(Guid id)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/baja_condominio";
        var payload = new { p_id = id };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("DesactivarCondominio {Id} failed. Status: {StatusCode}", id, response.StatusCode);
            return false;
        }

        return await ParseJsonAsync<bool>(response.Content);
    }

    public async Task<(CondominioDto? condominio, string? error)> ActualizarCondominioAsync(Guid id, UpdateCondominioRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/cambio_condominio";
        var payload = new Dictionary<string, object> { { "p_id", id } };
        if (dto.Nombre != null) payload["p_nombre"] = dto.Nombre;

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            if (errorBody.Contains("no encontrad"))
            {
                _logger.LogWarning("ActualizarCondominio {Id} failed: no encontrado.", id);
                return (null, "Condominio no encontrado");
            }

            _logger.LogError("ActualizarCondominio {Id} failed. Status: {StatusCode}, Body: {Body}", id, response.StatusCode, errorBody);
            return (null, $"Error al actualizar condominio: {errorBody}");
        }

        var updated = await ParseJsonAsync<CondominioDto>(response.Content);
        if (updated == null)
            return (null, "Condominio no encontrado o no se pudo actualizar");

        return (updated, null);
    }

    public async Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_usuarios?id=eq.{userId}&select=rol_nombre,condominio_id";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch user context. Status: {StatusCode}", response.StatusCode);
            return (null, null);
        }

        var json = await response.Content.ReadAsStringAsync();
        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse JSON when getting user context.");
            throw new SupabaseResponseException("Invalid JSON response from Supabase.", ex);
        }

        using (doc)
        {
            if (doc.RootElement.GetArrayLength() == 0) return (null, null);

            var el = doc.RootElement[0];
            string? rolNombre = null;
            Guid? condominioId = null;

            if (el.TryGetProperty("rol_nombre", out var rn) && rn.ValueKind != JsonValueKind.Null)
            {
                rolNombre = rn.GetString();
            }

            if (el.TryGetProperty("condominio_id", out var ci) && ci.ValueKind != JsonValueKind.Null)
            {
                if (Guid.TryParse(ci.GetString(), out var parsedId))
                {
                    condominioId = parsedId;
                }
            }

            return (rolNombre, condominioId);
        }
    }
}
