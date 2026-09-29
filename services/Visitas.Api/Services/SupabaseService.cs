using System.Text.Json;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;

namespace Visitas.Api.Services;

public class SupabaseService : ISupabaseService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<SupabaseService> _logger;
    private readonly string _supabaseUrl;
    private readonly string _anonKey;
    private readonly string _serviceRoleKey;

    private const string VwMisVisitas = "vw_mis_visitas";
    private const string VwVisitasHoy = "vw_visitas_hoy";
    private const string VwVisitasHistorico = "vw_visitas_historico";

    private const string RpcAltaVisita = "alta_visita";
    private const string RpcCambioVisita = "cambio_visita";
    private const string RpcCancelarVisita = "cancelar_visita";
    private const string RpcValidarCodigoVisita = "validar_codigo_visita";
    private const string RpcRegistrarEntradaVisita = "registrar_entrada_visita";
    private const string RpcRegistrarSalidaVisita = "registrar_salida_visita";
    private const string RpcAltaNotificacion = "alta_notificacion";

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

    public async Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken)
    {
        return await SupabaseUserContextClient.GetContextoUsuarioAsync(
            _httpClient,
            _supabaseUrl,
            _anonKey,
            userId,
            accessToken
        );
    }
}
