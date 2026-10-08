using System.Net.Http.Headers;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Rpc;
using Visitas.Api.DTOs;

namespace Visitas.Api.Services;

public class PaqueteriaSupabaseService : IPaqueteriaSupabaseService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<PaqueteriaSupabaseService> _logger;
    private readonly string _supabaseUrl;
    private readonly string _anonKey;
    private readonly string _serviceRoleKey;

    public PaqueteriaSupabaseService(HttpClient httpClient, IConfiguration configuration, ILogger<PaqueteriaSupabaseService> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _supabaseUrl = configuration["Supabase:Url"] ?? throw new InvalidOperationException("Supabase:Url is not configured.");
        _anonKey = configuration["Supabase:AnonKey"] ?? throw new InvalidOperationException("Supabase:AnonKey is not configured.");
        _serviceRoleKey = configuration["Supabase:ServiceRoleKey"] ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
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

    public async Task<List<ServicioPaqueteriaDto>> GetServiciosPaqueteriaAsync(Guid? condominioId)
    {
        var resourcePath = "vw_servicios_paqueteria?select=*&activo=eq.true";
        if (condominioId.HasValue)
        {
            resourcePath += $"&or=(condominio_id.is.null,condominio_id.eq.{condominioId.Value})";
        }
        else
        {
            resourcePath += "&condominio_id=is.null";
        }

        var result = await SupabaseQueryClient.GetPagedAsync<ServicioPaqueteriaDto>(
            _httpClient,
            _supabaseUrl,
            _serviceRoleKey,
            _serviceRoleKey,
            resourcePath,
            new PaginationParams { PageSize = 100, Page = 1 }
        );

        return result.Items ?? new List<ServicioPaqueteriaDto>();
    }

    public async Task<PaqueteDto> CreatePaqueteEsperadoAsync(CreatePaqueteEsperadoRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_actor_id", actorId },
            { "p_vivienda_id", dto.ViviendaId },
            { "p_destinatario_nombre", dto.DestinatarioNombre.Trim() },
            { "p_servicio_id", dto.ServicioId },
            { "p_servicio_nombre", dto.ServicioNombre?.Trim() },
            { "p_numero_guia", dto.NumeroGuia?.Trim() },
            { "p_descripcion", dto.Descripcion?.Trim() },
            { "p_notas", dto.Notas?.Trim() },
            { "p_fecha_esperada_desde", dto.FechaEsperadaDesde },
            { "p_fecha_esperada_hasta", dto.FechaEsperadaHasta }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<PaqueteDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "alta_paquete_esperado", payload, actorId);

        if (result == null)
        {
            throw new SupabaseResponseException("Error inesperado: la base de datos no devolvió el paquete creado.");
        }

        return result;
    }

    public async Task<PaqueteDto> UpdatePaqueteEsperadoAsync(Guid id, Guid actorId, UpdatePaqueteEsperadoRequestDto dto)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_id", id },
            { "p_actor_id", actorId }
        };

        if (dto.DestinatarioNombre != null) payload["p_destinatario_nombre"] = dto.DestinatarioNombre.Trim();
        if (dto.ServicioId.HasValue) payload["p_servicio_id"] = dto.ServicioId.Value;
        if (dto.ServicioNombre != null) payload["p_servicio_nombre"] = dto.ServicioNombre.Trim();
        if (dto.NumeroGuia != null) payload["p_numero_guia"] = dto.NumeroGuia.Trim();
        if (dto.Descripcion != null) payload["p_descripcion"] = dto.Descripcion.Trim();
        if (dto.Notas != null) payload["p_notas"] = dto.Notas.Trim();
        if (dto.FechaEsperadaDesde.HasValue) payload["p_fecha_esperada_desde"] = dto.FechaEsperadaDesde.Value;
        if (dto.FechaEsperadaHasta.HasValue) payload["p_fecha_esperada_hasta"] = dto.FechaEsperadaHasta.Value;

        var result = await SupabaseRpcClient.PostRpcAsync<PaqueteDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "cambio_paquete_esperado", payload, actorId);

        if (result == null)
        {
            throw new SupabaseResponseException("Error inesperado: la base de datos no devolvió el paquete actualizado.");
        }

        return result;
    }

    public async Task<bool> CancelPaqueteEsperadoAsync(Guid id, Guid actorId, string? motivo)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_id", id },
            { "p_actor_id", actorId },
            { "p_motivo", motivo?.Trim() }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<bool?>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "cancelar_paquete_esperado", payload, actorId);

        return result ?? false;
    }

    public async Task<(List<PaqueteDto> Items, int? TotalCount)> GetMisPaquetesAsync(string accessToken, int? viviendaId, string? estado, PaginationParams paginacion)
    {
        var resourcePath = "vw_mis_paquetes?select=*&order=creado_en.desc";

        if (viviendaId.HasValue)
        {
            resourcePath += $"&vivienda_id=eq.{viviendaId.Value}";
        }

        if (!string.IsNullOrWhiteSpace(estado))
        {
            var estadoLower = estado.Trim().ToLowerInvariant();
            resourcePath += $"&estado=eq.{estadoLower}";
        }

        var result = await SupabaseQueryClient.GetPagedAsync<PaqueteDto>(
            _httpClient,
            _supabaseUrl,
            _anonKey,
            accessToken,
            resourcePath,
            paginacion
        );

        return (result.Items ?? new List<PaqueteDto>(), result.TotalCount);
    }
}
