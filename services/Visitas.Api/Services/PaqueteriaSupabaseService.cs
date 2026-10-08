using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
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

    public async Task<(IEnumerable<PaqueteCasetaDto> Items, int TotalCount)> GetPaquetesCasetaAsync(Guid condominioId, string estado, int? viviendaId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_paquetes_caseta?select=*&condominio_id=eq.{condominioId}&estado=eq.{estado}";
        
        if (viviendaId.HasValue)
        {
            resourcePath += $"&vivienda_id=eq.{viviendaId.Value}";
        }

        if (estado == PaqueteEstados.Esperado)
        {
            resourcePath += "&order=fecha_esperada_desde.asc.nullslast";
        }
        else if (estado == PaqueteEstados.Recibido)
        {
            resourcePath += "&order=recibido_en.desc.nullslast";
        }
        else
        {
            resourcePath += "&order=creado_en.desc.nullslast";
        }

        var result = await SupabaseQueryClient.GetPagedAsync<PaqueteCasetaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion
        );

        return (result.Items ?? new List<PaqueteCasetaDto>(), result.TotalCount ?? 0);
    }

    public async Task<PaqueteCasetaDto> RecibirPaqueteAsync(RecibirPaqueteRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_paquete_id", dto.PaqueteId },
            { "p_vivienda_id", dto.ViviendaId },
            { "p_destinatario_nombre", dto.DestinatarioNombre?.Trim() },
            { "p_servicio_id", dto.ServicioId },
            { "p_servicio_nombre", dto.ServicioNombre?.Trim() },
            { "p_numero_guia", dto.NumeroGuia?.Trim() },
            { "p_descripcion", dto.Descripcion?.Trim() },
            { "p_ubicacion_almacen", dto.UbicacionAlmacen?.Trim() },
            { "p_actor_id", actorId }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<PaqueteCasetaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "recibir_paquete_caseta", payload, actorId);

        if (result == null)
            throw new SupabaseResponseException("Error inesperado al recibir paquete.");

        return result;
    }

    public async Task<PaqueteCasetaDto> EntregarPaqueteAsync(Guid paqueteId, EntregarPaqueteRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_paquete_id", paqueteId },
            { "p_entregado_a_nombre", dto.EntregadoANombre.Trim() },
            { "p_foto_url", null },
            { "p_actor_id", actorId }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<PaqueteCasetaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "entregar_paquete_residente", payload, actorId);

        if (result == null)
            throw new SupabaseResponseException("Error inesperado al entregar paquete.");

        return result;
    }

    public async Task<(IEnumerable<PaqueteHistoricoDto> Items, int TotalCount)> GetPaquetesHistoricoAsync(
        Guid condominioId, DateTimeOffset? desde, DateTimeOffset? hasta, int? viviendaId, string? estado, PaginationParams paginacion)
    {
        var resourcePath = $"vw_paquetes_historico?select=*&condominio_id=eq.{condominioId}&order=creado_en.desc.nullslast";

        if (desde.HasValue)
        {
            // Postgres PostgREST URL encoding para + -> %2B si es necesario, pero ToString("O") debería jalar o HttpUtility
            var d = Uri.EscapeDataString(desde.Value.ToString("O"));
            resourcePath += $"&creado_en=gte.{d}";
        }
        if (hasta.HasValue)
        {
            var h = Uri.EscapeDataString(hasta.Value.ToString("O"));
            resourcePath += $"&creado_en=lte.{h}";
        }
        if (viviendaId.HasValue)
        {
            resourcePath += $"&vivienda_id=eq.{viviendaId.Value}";
        }
        if (!string.IsNullOrEmpty(estado))
        {
            resourcePath += $"&estado=eq.{estado.ToLowerInvariant()}";
        }

        var result = await SupabaseQueryClient.GetPagedAsync<PaqueteHistoricoDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion
        );

        return (result.Items ?? new List<PaqueteHistoricoDto>(), result.TotalCount ?? 0);
    }

    public async Task<ServicioPaqueteriaDto> CreateServicioPaqueteriaAsync(Guid condominioId, CreateServicioPaqueteriaRequestDto dto, Guid actorId)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_condominio_id", condominioId },
            { "p_nombre", dto.Nombre.Trim() },
            { "p_icono_url", dto.IconoUrl?.Trim() },
            { "p_actor_id", actorId }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<ServicioPaqueteriaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "alta_servicio_paqueteria", payload, actorId);

        if (result == null)
            throw new SupabaseResponseException("Error inesperado al crear servicio.");

        return result;
    }

    public async Task<bool> DeleteServicioPaqueteriaAsync(int servicioId, Guid actorId)
    {
        var payload = new Dictionary<string, object?>
        {
            { "p_id", servicioId },
            { "p_actor_id", actorId }
        };

        var result = await SupabaseRpcClient.PostRpcAsync<bool?>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "baja_servicio_paqueteria", payload, actorId);

        return result ?? false;
    }

    public async Task<IEnumerable<Guid>> GetDestinatariosPorViviendaAsync(int viviendaId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_vivienda_usuarios?vivienda_id=eq.{viviendaId}&select=usuario_id";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        try
        {
            var response = await _httpClient.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("GetDestinatariosPorViviendaAsync failed for vivienda {ViviendaId}. Status: {StatusCode}, Body: {Body}", viviendaId, response.StatusCode, errorBody);
                return Enumerable.Empty<Guid>();
            }

            var elements = await response.Content.ReadFromJsonAsync<List<Dictionary<string, JsonElement>>>();
            if (elements == null) return Enumerable.Empty<Guid>();

            var list = new List<Guid>();
            foreach (var dict in elements)
            {
                if (dict.TryGetValue("usuario_id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
                {
                    if (Guid.TryParse(idElement.GetString(), out var id))
                    {
                        list.Add(id);
                    }
                }
            }
            return list;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error no controlado al obtener destinatarios de la vivienda {ViviendaId}", viviendaId);
            return Enumerable.Empty<Guid>();
        }
    }

    public async Task<bool> CrearNotificacionPaqueteLlegadaAsync(Guid usuarioId, Guid paqueteId, string? destinatarioNombre, string? servicioNombre, bool esInesperado)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/alta_notificacion";
        
        var titulo = esInesperado ? "¡Paquete inesperado recibido!" : "¡Tu paquete ha llegado!";
        
        var dest = !string.IsNullOrWhiteSpace(destinatarioNombre) ? destinatarioNombre : "tu vivienda";
        var serv = !string.IsNullOrWhiteSpace(servicioNombre) ? $" por {servicioNombre}" : "";
        var mensaje = esInesperado 
            ? $"Se ha recibido un paquete no esperado para {dest}{serv} en caseta."
            : $"El paquete esperado para {dest}{serv} ya se encuentra en caseta.";
            
        var payload = new
        {
            p_usuario_id = usuarioId,
            p_tipo_evento = "paquete_llegada",
            p_titulo = titulo,
            p_mensaje = mensaje,
            p_url_redireccion = $"/paquetes/{paqueteId}"
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        try
        {
            var response = await _httpClient.SendAsync(request);
            if (!response.IsSuccessStatusCode)
            {
                var errorBody = await response.Content.ReadAsStringAsync();
                _logger.LogWarning("CrearNotificacionPaqueteLlegadaAsync failed for paquete {PaqueteId}. Status: {StatusCode}, Body: {Body}", paqueteId, response.StatusCode, errorBody);
                return false;
            }
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogWarning(ex, "Error no controlado al notificar llegada del paquete {PaqueteId}", paqueteId);
            return false;
        }
    }
}
