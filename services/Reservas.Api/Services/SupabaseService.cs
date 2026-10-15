using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;
using HavenApi.Shared.Pagination;
using Reservas.Api.DTOs;
using System.Collections.Generic;
using System.Linq;
using System;

namespace Reservas.Api.Services;

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

    public async Task<(List<AreaComunDto>? Items, int? TotalCount)> GetAreasAsync(Guid condominioId, bool soloActivas, PaginationParams paginacion)
    {
        var resourcePath = $"vw_areas_comunes?condominio_id=eq.{condominioId}";
        if (soloActivas)
        {
            resourcePath += "&activo=eq.true";
        }
        resourcePath += "&order=nombre.asc";

        return await SupabaseQueryClient.GetPagedAsync<AreaComunDto>(
            _httpClient,
            _supabaseUrl,
            _serviceRoleKey,
            _serviceRoleKey,
            resourcePath,
            paginacion
        );
    }

    public async Task<AreaComunDto?> GetAreaByIdAsync(Guid id)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_areas_comunes?id=eq.{id}&select=*";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch area {Id}. Status: {StatusCode}", id, response.StatusCode);
            return null;
        }

        var areas = await ParseJsonAsync<List<AreaComunDto>>(response.Content);
        return areas?.FirstOrDefault();
    }

    public async Task<AreaComunDto?> CrearAreaAsync(Guid condominioId, CreateAreaComunRequestDto dto, Guid actorId)
    {
        var payload = new
        {
            p_actor_id = actorId,
            p_condominio_id = condominioId,
            p_nombre = dto.Nombre,
            p_descripcion = dto.Descripcion,
            p_hora_apertura = dto.HoraApertura!.Value.ToString("HH:mm:ss"),
            p_hora_cierre = dto.HoraCierre!.Value.ToString("HH:mm:ss")
        };

        return await SupabaseRpcClient.PostRpcAsync<AreaComunDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "alta_area_comun", payload, actorId);
    }

    public async Task<AreaComunDto?> ActualizarAreaAsync(Guid id, UpdateAreaComunRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_id", id }
        };

        if (dto.Nombre != null) payload["p_nombre"] = dto.Nombre;
        if (dto.Descripcion != null) payload["p_descripcion"] = dto.Descripcion;
        if (dto.HoraApertura.HasValue) payload["p_hora_apertura"] = dto.HoraApertura.Value.ToString("HH:mm:ss");
        if (dto.HoraCierre.HasValue) payload["p_hora_cierre"] = dto.HoraCierre.Value.ToString("HH:mm:ss");

        return await SupabaseRpcClient.PostRpcAsync<AreaComunDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "cambio_area_comun", payload, actorId);
    }

    public async Task<bool> BajaAreaAsync(Guid id, Guid actorId)
    {
        var payload = new
        {
            p_actor_id = actorId,
            p_id = id
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "baja_area_comun", payload, actorId);
    }

    public async Task<bool> ReactivarAreaAsync(Guid id, Guid actorId)
    {
        var payload = new
        {
            p_actor_id = actorId,
            p_id = id
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "reactivar_area_comun", payload, actorId);
    }

    private string FormatDateForSupabase(DateTimeOffset date)
    {
        var formatted = date.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");
        return Uri.EscapeDataString(formatted);
    }

    public async Task<(List<CalendarioReservaDto>? Items, int? TotalCount)> GetCalendarioAsync(Guid condominioId, DateTimeOffset desde, DateTimeOffset hasta, Guid? areaId, bool limitado, PaginationParams paginacion)
    {
        var view = limitado ? "vw_calendario_reservas_limitado" : "vw_calendario_reservas";
        var desdeStr = FormatDateForSupabase(desde);
        var hastaStr = FormatDateForSupabase(hasta);
        
        var resourcePath = $"{view}?condominio_id=eq.{condominioId}&inicio=lt.{hastaStr}&fin=gt.{desdeStr}";
        if (areaId.HasValue)
        {
            resourcePath += $"&area_id=eq.{areaId.Value}";
        }
        resourcePath += "&order=inicio.asc";

        return await SupabaseQueryClient.GetPagedAsync<CalendarioReservaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    public async Task<(List<ReservaAdminDto>? Items, int? TotalCount)> GetCalendarioAdminAsync(Guid condominioId, DateTimeOffset desde, DateTimeOffset hasta, Guid? areaId, PaginationParams paginacion)
    {
        var desdeStr = FormatDateForSupabase(desde);
        var hastaStr = FormatDateForSupabase(hasta);
        
        var resourcePath = $"vw_reservas_admin?condominio_id=eq.{condominioId}&inicio=lt.{hastaStr}&fin=gt.{desdeStr}";
        if (areaId.HasValue)
        {
            resourcePath += $"&area_id=eq.{areaId.Value}";
        }
        resourcePath += "&order=inicio.asc";

        return await SupabaseQueryClient.GetPagedAsync<ReservaAdminDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    private string? BuildEstadoFilter(string? estado)
    {
        if (string.IsNullOrWhiteSpace(estado))
            return null;

        var normalized = estado.Trim().ToLowerInvariant().Replace("-", "_");

        return normalized switch
        {
            "finalizada" or "finalizadas" =>
                $"&fin=lt.{FormatDateForSupabase(DateTimeOffset.UtcNow)}&estado=in.(APROBADA,CONFIRMADA)",

            "pendiente" or "pendientes" or "por_aprobar" =>
                "&estado=in.(PENDIENTE_TITULAR,PENDIENTE_ADMIN)",

            "aprobada" or "aprobadas" =>
                "&estado=in.(APROBADA,CONFIRMADA)",

            "activa" or "activas" or "proxima" or "proximas" =>
                $"&fin=gte.{FormatDateForSupabase(DateTimeOffset.UtcNow)}&estado=in.(APROBADA,CONFIRMADA)",

            "confirmada" or "confirmadas" =>
                "&estado=eq.CONFIRMADA",

            "cancelada" or "canceladas" =>
                "&estado=eq.CANCELADA",

            "rechazada" or "rechazadas" =>
                "&estado=eq.RECHAZADA",

            "no_utilizada" or "no_utilizadas" =>
                "&estado=eq.NO_UTILIZADA",

            "pendiente_titular" =>
                "&estado=eq.PENDIENTE_TITULAR",

            "pendiente_admin" =>
                "&estado=eq.PENDIENTE_ADMIN",

            _ => $"&estado=eq.{Uri.EscapeDataString(normalized.ToUpperInvariant())}"
        };
    }

    public async Task<(List<ReservaUsuarioDto>? Items, int? TotalCount)> GetMisReservasAsync(Guid usuarioId, string? estado, PaginationParams paginacion)
    {
        var resourcePath = $"vw_reservas_usuario?or=(titular_id.eq.{usuarioId},solicitante_id.eq.{usuarioId})";
        var estadoFilter = BuildEstadoFilter(estado);
        if (!string.IsNullOrEmpty(estadoFilter))
        {
            resourcePath += estadoFilter;
        }
        resourcePath += "&order=inicio.desc";

        return await SupabaseQueryClient.GetPagedAsync<ReservaUsuarioDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    public async Task<(List<PendienteTitularDto>? Items, int? TotalCount)> GetPendientesTitularAsync(Guid titularId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_reservas_pendientes_titular?titular_id=eq.{titularId}&order=inicio.asc";

        return await SupabaseQueryClient.GetPagedAsync<PendienteTitularDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    public async Task<(List<ReservaAdminDto>? Items, int? TotalCount)> GetReservasAdminAsync(Guid condominioId, string? estado, Guid? areaId, DateTimeOffset? desde, DateTimeOffset? hasta, PaginationParams paginacion)
    {
        var resourcePath = $"vw_reservas_admin?condominio_id=eq.{condominioId}";
        var estadoFilter = BuildEstadoFilter(estado);
        if (!string.IsNullOrEmpty(estadoFilter))
        {
            resourcePath += estadoFilter;
        }
        if (areaId.HasValue)
        {
            resourcePath += $"&area_id=eq.{areaId.Value}";
        }
        if (desde.HasValue)
        {
            resourcePath += $"&inicio=gte.{FormatDateForSupabase(desde.Value)}";
        }
        if (hasta.HasValue)
        {
            resourcePath += $"&inicio=lte.{FormatDateForSupabase(hasta.Value)}";
        }
        resourcePath += "&order=inicio.asc";

        return await SupabaseQueryClient.GetPagedAsync<ReservaAdminDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    public async Task<ReservaAdminDto?> GetReservaAdminByIdAsync(Guid id, Guid condominioId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_reservas_admin?id=eq.{id}&condominio_id=eq.{condominioId}&select=*";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch reserva admin {Id}. Status: {StatusCode}", id, response.StatusCode);
            return null;
        }

        var reservas = await ParseJsonAsync<List<ReservaAdminDto>>(response.Content);
        return reservas?.FirstOrDefault();
    }

    public async Task<(List<NoShowDto>? Items, int? TotalCount)> GetNoShowsAsync(Guid condominioId, Guid? titularId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_no_shows?condominio_id=eq.{condominioId}";
        if (titularId.HasValue)
        {
            resourcePath += $"&titular_id=eq.{titularId.Value}";
        }
        resourcePath += "&order=inicio.desc";

        return await SupabaseQueryClient.GetPagedAsync<NoShowDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion);
    }

    public async Task<ReservaUsuarioDto?> SolicitarReservaAsync(Guid actorId, Guid areaId, DateTimeOffset inicio, DateTimeOffset fin)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_area_id", areaId },
            { "p_inicio", inicio.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") },
            { "p_fin", fin.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") }
        };

        return await SupabaseRpcClient.PostRpcAsync<ReservaUsuarioDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "solicitar_reserva", payload, actorId);
    }

    public async Task<bool> AprobarReservaTitularAsync(Guid actorId, Guid reservaId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "aprobar_reserva_titular", payload, actorId);
    }

    public async Task<bool> RechazarReservaTitularAsync(Guid actorId, Guid reservaId, string? motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        if (!string.IsNullOrWhiteSpace(motivo))
        {
            payload["p_motivo"] = motivo;
        }

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "rechazar_reserva_titular", payload, actorId);
    }

    public async Task<bool> ConfirmarReservaAsync(Guid actorId, Guid reservaId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "confirmar_reserva", payload, actorId);
    }

    public async Task<bool> CancelarReservaAsync(Guid actorId, Guid reservaId, string? motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        if (!string.IsNullOrWhiteSpace(motivo))
        {
            payload["p_motivo"] = motivo;
        }

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "cancelar_reserva", payload, actorId);
    }

    public async Task<bool> AprobarReservaAdminAsync(Guid actorId, Guid reservaId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "aprobar_reserva_admin", payload, actorId);
    }

    public async Task<bool> RechazarReservaAdminAsync(Guid actorId, Guid reservaId, string motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId },
            { "p_motivo", motivo }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "rechazar_reserva_admin", payload, actorId);
    }

    public async Task<bool> CancelarReservaAdminAsync(Guid actorId, Guid reservaId, string motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId },
            { "p_motivo", motivo }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "cancelar_reserva_admin", payload, actorId);
    }

    public async Task<bool> MarcarNoUtilizadaAsync(Guid actorId, Guid reservaId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_reserva_id", reservaId }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "marcar_reserva_no_utilizada", payload, actorId);
    }

    public async Task<BloqueoResultadoDto?> CrearBloqueoAsync(Guid actorId, Guid areaId, DateTimeOffset inicio, DateTimeOffset fin, string motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_area_id", areaId },
            { "p_inicio", inicio.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") },
            { "p_fin", fin.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") },
            { "p_motivo", motivo }
        };

        return await SupabaseRpcClient.PostRpcAsync<BloqueoResultadoDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "crear_bloqueo_area", payload, actorId);
    }

    public async Task<BloqueoResultadoDto?> ActualizarBloqueoAsync(Guid actorId, Guid bloqueoId, DateTimeOffset? inicio, DateTimeOffset? fin, string? motivo)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_bloqueo_id", bloqueoId }
        };

        if (inicio.HasValue) payload["p_inicio"] = inicio.Value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");
        if (fin.HasValue) payload["p_fin"] = fin.Value.ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ");
        if (!string.IsNullOrWhiteSpace(motivo)) payload["p_motivo"] = motivo.Trim();

        var list = await SupabaseRpcClient.PostRpcAsync<List<BloqueoResultadoDto>>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "actualizar_bloqueo_area", payload, actorId);

        return list?.FirstOrDefault();
    }

    public async Task<bool> EliminarBloqueoAsync(Guid actorId, Guid bloqueoId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_actor_id", actorId },
            { "p_bloqueo_id", bloqueoId }
        };

        return await SupabaseRpcClient.PostRpcAsync<bool>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "eliminar_bloqueo_area", payload, actorId);
    }
}
