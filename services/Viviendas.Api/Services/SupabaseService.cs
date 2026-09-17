using System.Net.Http.Headers;
using System.Text.Json;
using System.Text.Json.Serialization;
using Viviendas.Api.DTOs;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Rpc;

namespace Viviendas.Api.Services;

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

    public async Task<string?> GetUsuarioRolAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_usuarios?id=eq.{userId}&select=*";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch user rol. Status: {StatusCode}", response.StatusCode);
            return null;
        }

        var json = await response.Content.ReadAsStringAsync();
        JsonDocument doc;
        try
        {
            doc = JsonDocument.Parse(json);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse JSON when getting user rol.");
            throw new SupabaseResponseException("Invalid JSON response from Supabase.", ex);
        }

        using (doc)
        {
            if (doc.RootElement.GetArrayLength() == 0) return null;

            var el = doc.RootElement[0];
            
            if (el.TryGetProperty("rol_nombre", out var rn) && rn.ValueKind != JsonValueKind.Null)
                return rn.GetString();
                
            if (el.TryGetProperty("rol_id", out var ri) && ri.ValueKind != JsonValueKind.Null)
            {
                var rid = ri.ToString();
                if (rid == "1") return "Administrador";
                if (rid == "2") return "Residente";
            }
            
            return "Residente";
        }
    }

    public async Task<(string? rolNombre, Guid? condominioId)> GetContextoAdminAsync(Guid userId, string accessToken)
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

    public async Task<(List<ViviendaDto> Items, int? TotalCount)> GetViviendasAsync(Guid condominioId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_viviendas?select=*&condominio_id=eq.{condominioId}";

        try
        {
            var result = await SupabaseQueryClient.GetPagedAsync<ViviendaDto>(
                _httpClient,
                _supabaseUrl,
                _serviceRoleKey,
                _serviceRoleKey,
                resourcePath,
                paginacion
            );

            return (result.Items ?? new List<ViviendaDto>(), result.TotalCount);
        }
        catch (SupabaseResponseException ex)
        {
            _logger.LogWarning(ex, "Failed to fetch paginated viviendas.");
            return (new List<ViviendaDto>(), null);
        }
    }

    public async Task<ViviendaDto?> GetViviendaByIdAsync(int id)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_viviendas?id=eq.{id}&select=*";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch vivienda {Id}. Status: {StatusCode}", id, response.StatusCode);
            return null;
        }

        var viviendas = await ParseJsonAsync<List<ViviendaDto>>(response.Content);
        return viviendas?.FirstOrDefault();
    }

    public async Task<(ViviendaDto? vivienda, string? error)> CreateViviendaAsync(CreateViviendaRequestDto dto, Guid condominioId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/alta_vivienda";
        var payload = new
        {
            p_numero_casa = dto.NumeroCasa,
            p_condominio_id = condominioId,
            p_tipo = dto.Tipo
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            if (errorBody.Contains("23505") || errorBody.Contains("uq_viviendas_numero_casa") || errorBody.Contains("viviendas_numero_casa_key"))
            {
                _logger.LogWarning("CreateVivienda: Conflict, casa {NumeroCasa} already exists.", dto.NumeroCasa);
                return (null, "Ya existe una vivienda registrada con ese número de casa");
            }

            _logger.LogError("CreateVivienda failed. Status: {StatusCode}, Body: {Body}", response.StatusCode, errorBody);
            return (null, $"Error al crear vivienda: {errorBody}");
        }

        var result = await ParseJsonAsync<ViviendaDto>(response.Content);
        return (result, null);
    }

    public async Task<(ViviendaDto? vivienda, string? error)> UpdateViviendaAsync(int id, UpdateViviendaRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/cambio_vivienda";
        var payload = new Dictionary<string, object> { { "p_id", id } };
        if (dto.NumeroCasa != null) payload["p_numero_casa"] = dto.NumeroCasa;
        if (dto.Tipo != null) payload["p_tipo"] = dto.Tipo;

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            if (errorBody.Contains("23505") || errorBody.Contains("uq_viviendas_numero_casa") || errorBody.Contains("viviendas_numero_casa_key"))
            {
                _logger.LogWarning("UpdateVivienda: Conflict, casa {NumeroCasa} already exists.", dto.NumeroCasa);
                return (null, "Ya existe una vivienda registrada con ese número de casa");
            }

            _logger.LogError("UpdateVivienda {Id} failed. Status: {StatusCode}, Body: {Body}", id, response.StatusCode, errorBody);
            return (null, $"Error al actualizar vivienda: {errorBody}");
        }

        var updated = await ParseJsonAsync<ViviendaDto>(response.Content);
        if (updated == null)
            return (null, "Vivienda no encontrada o no se pudo actualizar");

        return (updated, null);
    }

    public async Task<bool> DeleteViviendaAsync(int id)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/baja_vivienda";
        var payload = new { p_id = id };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("DeleteVivienda {Id} failed. Status: {StatusCode}", id, response.StatusCode);
            return false;
        }

        return await ParseJsonAsync<bool>(response.Content);
    }

    public async Task<(JsonElement? data, string? error)> AssignResidenteAsync(int viviendaId, AsignarResidenteRequestDto dto)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/asignar_residente_vivienda";
        var payload = new
        {
            p_vivienda_id = viviendaId,
            p_usuario_id = dto.UsuarioId
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            if (errorBody.Contains("23505") || errorBody.Contains("vivienda_residente_pkey"))
            {
                _logger.LogWarning("AssignResidente: Conflict, resident {UserId} already assigned to {ViviendaId}.", dto.UsuarioId, viviendaId);
                return (null, "El residente ya está asignado a esta vivienda");
            }

            if (errorBody.Contains("P0001")) return (null, "Vivienda no encontrada");
            if (errorBody.Contains("P0002")) return (null, "Usuario no encontrado");
            if (errorBody.Contains("P0003")) return (null, "El usuario no tiene el rol de Residente");

            _logger.LogError("AssignResidente failed for vivienda {ViviendaId}. Status: {StatusCode}, Body: {Body}", viviendaId, response.StatusCode, errorBody);
            return (null, $"Error al asignar residente: {errorBody}");
        }

        var result = await ParseJsonAsync<JsonElement>(response.Content);
        return (result, null);
    }

    public async Task<bool> RemoveResidenteAsync(int viviendaId, Guid usuarioId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/quitar_residente_vivienda";
        var payload = new
        {
            p_vivienda_id = viviendaId,
            p_usuario_id = usuarioId
        };

        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        request.Content = JsonContent.Create(payload);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("RemoveResidente failed for vivienda {ViviendaId} and user {UserId}. Status: {StatusCode}", viviendaId, usuarioId, response.StatusCode);
            return false;
        }

        return await ParseJsonAsync<bool>(response.Content);
    }

    public async Task<(List<MiViviendaDto> Items, int? TotalCount)> GetMisViviendasAsync(string accessToken, PaginationParams paginacion)
    {
        var resourcePath = "vw_mis_viviendas?select=*";

        try
        {
            var result = await SupabaseQueryClient.GetPagedAsync<MiViviendaDto>(
                _httpClient,
                _supabaseUrl,
                _anonKey,
                accessToken,
                resourcePath,
                paginacion
            );

            return (result.Items ?? new List<MiViviendaDto>(), result.TotalCount);
        }
        catch (SupabaseResponseException ex)
        {
            _logger.LogWarning(ex, "Failed to fetch paginated mis-viviendas.");
            return (new List<MiViviendaDto>(), null);
        }
    }

    public async Task<JsonElement> GetResidentesByViviendaIdAsync(int viviendaId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_viviendas_residentes?vivienda_id=eq.{viviendaId}&select=residentes";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        
        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("GetResidentesByViviendaId failed for {ViviendaId}. Status: {StatusCode}, Body: {Body}", viviendaId, response.StatusCode, errorBody);
            throw new SupabaseResponseException($"Supabase Error: {response.StatusCode} - {errorBody}");
        }

        JsonDocument doc;
        try
        {
            var stream = await response.Content.ReadAsStreamAsync();
            doc = await JsonDocument.ParseAsync(stream);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse JSON for GetResidentesByViviendaId.");
            throw new SupabaseResponseException("Invalid JSON response when getting residentes.", ex);
        }

        using (doc)
        {
            if (doc.RootElement.ValueKind == JsonValueKind.Array && doc.RootElement.GetArrayLength() > 0)
            {
                var firstItem = doc.RootElement[0];
                if (firstItem.TryGetProperty("residentes", out var residentes))
                {
                    if (residentes.ValueKind == JsonValueKind.Null)
                        return JsonDocument.Parse("[]").RootElement;
                        
                    return residentes.Clone();
                }
            }

            return JsonDocument.Parse("[]").RootElement;
        }
    }

    public async Task<CodigoViviendaDto?> GenerarCodigoViviendaAsync(int viviendaId, int? minutosVigencia, Guid actorId)
    {
        var payload = new Dictionary<string, object>
        {
            { "p_vivienda_id", viviendaId }
        };

        if (minutosVigencia.HasValue)
        {
            payload.Add("p_minutos_vigencia", minutosVigencia.Value);
        }

        return await SupabaseRpcClient.PostRpcAsync<CodigoViviendaDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "generar_codigo_vivienda", payload, actorId);
    }

    public async Task<RedimirViviendaResultDto?> RedimirCodigoViviendaAsync(string codigo, Guid usuarioId, Guid actorId)
    {
        var payload = new
        {
            p_codigo = codigo.Trim().ToUpperInvariant(),
            p_usuario_id = usuarioId
        };

        return await SupabaseRpcClient.PostRpcAsync<RedimirViviendaResultDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, "redimir_codigo_vivienda", payload, actorId);
    }
}
