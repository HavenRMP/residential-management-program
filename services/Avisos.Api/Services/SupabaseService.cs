using System.Net.Http.Headers;
using System.Text.Json;
using Avisos.Api.DTOs;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Rpc;

namespace Avisos.Api.Services;

public class SupabaseService : ISupabaseService
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<SupabaseService> _logger;
    private readonly string _supabaseUrl;
    private readonly string _anonKey;
    private readonly string _serviceRoleKey;

    // --- Definición de constantes (Nombres de vistas, RPCs y parámetros provisionales) ---
    private const string VwUsuarios = "vw_usuarios";
    private const string VwAvisosVigentes = "vw_avisos_vigentes";
    private const string VwAvisosHistorico = "vw_avisos_historico";

    private const string RpcAltaAviso = "alta_aviso";
    private const string RpcCambioAviso = "cambio_aviso";
    private const string RpcBajaAviso = "baja_aviso";
    private const string RpcAltaNotificacion = "alta_notificacion";

    private const string ParamId = "p_id";
    private const string ParamActorId = "p_actor_id";
    private const string ParamCreadoPor = "p_creado_por";
    private const string ParamTitulo = "p_titulo";
    private const string ParamContenido = "p_contenido";
    private const string ParamDuracionDias = "p_duracion_dias";
    private const string ParamFechaExpiracion = "p_fecha_expiracion";
    private const string ParamPrioridad = "p_prioridad";
    // --------------------------------------------------------------------------------------

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

    public async Task<(string? rol, Guid? condominioId)> GetUsuarioContextoAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/{VwUsuarios}?id=eq.{userId}&select=rol_nombre,condominio_id";

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

    public async Task<(List<AvisoDto> Items, int? TotalCount)> GetAvisosVigentesAsync(Guid condominioId, PaginationParams paginacion)
    {
        var resourcePath = $"{VwAvisosVigentes}?condominio_id=eq.{condominioId}&select=*";

        try
        {
            var result = await SupabaseQueryClient.GetPagedAsync<AvisoDto>(
                _httpClient,
                _supabaseUrl,
                _serviceRoleKey,
                _serviceRoleKey,
                resourcePath,
                paginacion
            );

            return (result.Items ?? new List<AvisoDto>(), result.TotalCount);
        }
        catch (SupabaseResponseException ex)
        {
            _logger.LogWarning(ex, "Failed to fetch paginated avisos vigentes.");
            return (new List<AvisoDto>(), null);
        }
    }

    public async Task<(List<AvisoDto> Items, int? TotalCount)> GetAvisosHistoricoAsync(Guid condominioId, PaginationParams paginacion)
    {
        var resourcePath = $"{VwAvisosHistorico}?condominio_id=eq.{condominioId}&select=*";

        try
        {
            var result = await SupabaseQueryClient.GetPagedAsync<AvisoDto>(
                _httpClient,
                _supabaseUrl,
                _serviceRoleKey,
                _serviceRoleKey,
                resourcePath,
                paginacion
            );

            return (result.Items ?? new List<AvisoDto>(), result.TotalCount);
        }
        catch (SupabaseResponseException ex)
        {
            _logger.LogWarning(ex, "Failed to fetch paginated avisos historico.");
            return (new List<AvisoDto>(), null);
        }
    }

    public async Task<(AvisoDto? aviso, string? error)> CreateAvisoAsync(Guid actorId, CreateAvisoRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/{RpcAltaAviso}";
        var payload = new Dictionary<string, object>
        {
            { ParamCreadoPor, actorId },
            { ParamTitulo, dto.Titulo },
            { ParamContenido, dto.Contenido }
        };

        if (dto.DuracionDias.HasValue) payload[ParamDuracionDias] = dto.DuracionDias.Value;
        if (dto.FechaExpiracion.HasValue) payload[ParamFechaExpiracion] = dto.FechaExpiracion.Value;
        payload[ParamPrioridad] = string.IsNullOrWhiteSpace(dto.Prioridad) ? "informativo" : dto.Prioridad;

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Content = JsonContent.Create(payload);

        // TODO: requiere que las RPCs alta_aviso/cambio_aviso acepten p_prioridad (pendiente DBA)
        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("CreateAviso failed. Status: {StatusCode}, Body: {Body}", response.StatusCode, errorBody);
            
            try 
            {
                using var doc = JsonDocument.Parse(errorBody);
                if (doc.RootElement.TryGetProperty("message", out var msg))
                {
                    return (null, msg.GetString());
                }
            }
            catch { }
            
            return (null, $"Error al crear aviso: {errorBody}");
        }

        var result = await ParseJsonAsync<AvisoDto>(response.Content);
        return (result, null);
    }

    public async Task<(AvisoDto? aviso, string? error)> UpdateAvisoAsync(Guid id, Guid actorId, UpdateAvisoRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/{RpcCambioAviso}";
        var payload = new Dictionary<string, object>
        {
            { ParamId, id },
            { ParamActorId, actorId }
        };

        if (dto.Titulo != null) payload[ParamTitulo] = dto.Titulo;
        if (dto.Contenido != null) payload[ParamContenido] = dto.Contenido;
        if (dto.DuracionDias.HasValue) payload[ParamDuracionDias] = dto.DuracionDias.Value;
        if (dto.FechaExpiracion.HasValue) payload[ParamFechaExpiracion] = dto.FechaExpiracion.Value;
        if (dto.Prioridad != null) payload[ParamPrioridad] = dto.Prioridad;

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Content = JsonContent.Create(payload);

        // TODO: requiere que las RPCs alta_aviso/cambio_aviso acepten p_prioridad (pendiente DBA)
        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("UpdateAviso {Id} failed. Status: {StatusCode}, Body: {Body}", id, response.StatusCode, errorBody);
            
            try 
            {
                using var doc = JsonDocument.Parse(errorBody);
                if (doc.RootElement.TryGetProperty("message", out var msg))
                {
                    return (null, msg.GetString());
                }
            }
            catch { }

            return (null, $"Error al actualizar aviso: {errorBody}");
        }

        var updated = await ParseJsonAsync<AvisoDto>(response.Content);
        return (updated, null);
    }

    public async Task<(bool ok, string? error)> DeleteAvisoAsync(Guid id, Guid actorId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/{RpcBajaAviso}";
        var payload = new Dictionary<string, object>
        {
            { ParamId, id },
            { ParamActorId, actorId }
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("DeleteAviso {Id} failed. Status: {StatusCode}, Body: {Body}", id, response.StatusCode, errorBody);
            
            try 
            {
                using var doc = JsonDocument.Parse(errorBody);
                if (doc.RootElement.TryGetProperty("message", out var msg))
                {
                    return (false, msg.GetString());
                }
            }
            catch { }

            return (false, $"Error al eliminar aviso: {errorBody}");
        }

        var ok = await ParseJsonAsync<bool>(response.Content);
        return (ok, null);
    }

    public async Task<List<Guid>> GetResidentesUsuarioIdsPorCondominioAsync(Guid condominioId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/{VwUsuarios}?condominio_id=eq.{condominioId}&rol_id=eq.2&activo=eq.true&select=id";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("GetResidentesUsuarioIdsPorCondominioAsync failed. Status: {StatusCode}", response.StatusCode);
            return new List<Guid>();
        }

        var jsonElements = await ParseJsonAsync<List<Dictionary<string, JsonElement>>>(response.Content);
        if (jsonElements == null) return new List<Guid>();

        var list = new List<Guid>();
        foreach (var dict in jsonElements)
        {
            if (dict.TryGetValue("id", out var idElement) && idElement.ValueKind == JsonValueKind.String)
            {
                if (Guid.TryParse(idElement.GetString(), out var id))
                {
                    list.Add(id);
                }
            }
        }
        return list;
    }

    public async Task<bool> NotificarAvisoUrgenteAsync(Guid usuarioId, Guid avisoId, string tituloAviso)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/{RpcAltaNotificacion}";
        var payload = new
        {
            p_usuario_id = usuarioId,
            p_tipo_evento = "aviso_urgente",
            p_titulo = "Aviso urgente publicado",
            p_mensaje = tituloAviso,
            p_url_redireccion = $"/avisos/{avisoId}"
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = System.Net.Http.Json.JsonContent.Create(payload);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("NotificarAvisoUrgenteAsync failed. Status: {StatusCode}", response.StatusCode);
            return false;
        }

        return true;
    }
}
