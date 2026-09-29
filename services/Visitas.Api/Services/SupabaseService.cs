using System.Text.Json;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;
using Visitas.Api.DTOs;

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

    public async Task<VisitaDto> CreateVisitaAsync(CreateVisitaRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_vivienda_id", dto.ViviendaId },
            { "p_nombre_visitante", dto.NombreVisitante.Trim() },
            { "p_apellidos_visitante", dto.ApellidosVisitante.Trim() },
            { "p_motivo", dto.Motivo.Trim().ToLowerInvariant() },
            { "p_num_acompanantes", dto.NumAcompanantes },
            { "p_fecha_llegada_esperada", dto.FechaLlegadaEsperada }
        };

        if (dto.TelefonoVisitante != null)
        {
            payload["p_telefono_visitante"] = dto.TelefonoVisitante.Trim();
        }

        if (dto.VehiculoPlacas != null)
        {
            payload["p_vehiculo_placas"] = dto.VehiculoPlacas.Trim();
        }

        if (dto.Notas != null)
        {
            payload["p_notas"] = dto.Notas.Trim();
        }

        if (dto.HorasVigencia.HasValue)
        {
            payload["p_horas_vigencia"] = dto.HorasVigencia.Value;
        }

        var result = await SupabaseRpcClient.PostRpcAsync<VisitaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, RpcAltaVisita, payload, actorId);

        if (result == null)
        {
            throw new SupabaseResponseException("Error inesperado: la base de datos no devolvió la visita creada.");
        }

        return result;
    }

    public async Task<VisitaDto> UpdateVisitaAsync(Guid id, Guid actorId, UpdateVisitaRequestDto dto)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_id", id },
            { "p_actor_id", actorId }
        };

        if (dto.NombreVisitante != null)
        {
            payload["p_nombre_visitante"] = dto.NombreVisitante.Trim();
        }

        if (dto.ApellidosVisitante != null)
        {
            payload["p_apellidos_visitante"] = dto.ApellidosVisitante.Trim();
        }

        if (dto.TelefonoVisitante != null)
        {
            payload["p_telefono_visitante"] = dto.TelefonoVisitante.Trim();
        }

        if (dto.Motivo != null)
        {
            payload["p_motivo"] = dto.Motivo.Trim().ToLowerInvariant();
        }

        if (dto.NumAcompanantes.HasValue)
        {
            payload["p_num_acompanantes"] = dto.NumAcompanantes.Value;
        }

        if (dto.VehiculoPlacas != null)
        {
            payload["p_vehiculo_placas"] = dto.VehiculoPlacas.Trim();
        }

        if (dto.Notas != null)
        {
            payload["p_notas"] = dto.Notas.Trim();
        }

        if (dto.FechaLlegadaEsperada.HasValue)
        {
            payload["p_fecha_llegada_esperada"] = dto.FechaLlegadaEsperada.Value;
        }

        if (dto.HorasVigencia.HasValue)
        {
            payload["p_horas_vigencia"] = dto.HorasVigencia.Value;
        }

        var result = await SupabaseRpcClient.PostRpcAsync<VisitaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, RpcCambioVisita, payload, actorId);

        if (result == null)
        {
            throw new SupabaseResponseException("Error inesperado: la base de datos no devolvió la visita actualizada.");
        }

        return result;
    }

    public async Task<bool> CancelVisitaAsync(Guid id, Guid actorId)
    {
        var payload = new
        {
            p_id = id,
            p_actor_id = actorId
        };

        var result = await SupabaseRpcClient.PostRpcAsync<bool?>(
            _httpClient, _supabaseUrl, _serviceRoleKey, RpcCancelarVisita, payload, actorId);

        return result ?? false;
    }
}
