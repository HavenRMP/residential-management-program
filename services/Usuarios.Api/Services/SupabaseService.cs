using System.Net.Http.Headers;
using System.Text.Json;
using Usuarios.Api.DTOs;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Rpc;

namespace Usuarios.Api.Services;

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

    public async Task<UsuarioDto?> GetUsuarioByIdAsync(Guid userId, string accessToken, Guid actorId)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_usuarios?id=eq.{userId}&select=*";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch user {UserId}. Status: {StatusCode}", userId, response.StatusCode);
            return null;
        }

        var usuarios = await ParseJsonAsync<List<UsuarioDto>>(response.Content);
        return usuarios?.FirstOrDefault();
    }

    public async Task<string?> GetDbVersionAsync()
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/version?select=numero_version&order=numero_version.desc&limit=1";

        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _anonKey);

        var response = await SendRequestAsync(request);

        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch DB version. Status: {StatusCode}", response.StatusCode);
            return null;
        }

        var records = await ParseJsonAsync<List<Dictionary<string, object>>>(response.Content);
        var version = records?.FirstOrDefault()?["numero_version"]?.ToString();

        return version;
    }

    public async Task<(UsuarioDto? usuario, string? error)> RegisterAdminAsync(RegisterRequestDto datos, Guid? actorId = null)
    {
        var signupUrl = $"{_supabaseUrl}/auth/v1/admin/users";
        var signupPayload = new { email = datos.Email, password = datos.Password, email_confirm = true };

        var signupRequest = new HttpRequestMessage(HttpMethod.Post, signupUrl);
        signupRequest.Headers.Add("apikey", _serviceRoleKey);
        if (actorId.HasValue) signupRequest.Headers.Add("x-actor-id", actorId.Value.ToString());
        signupRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        signupRequest.Content = JsonContent.Create(signupPayload);

        var signupResponse = await SendRequestAsync(signupRequest);
        var signupBody = await signupResponse.Content.ReadAsStringAsync();

        if (!signupResponse.IsSuccessStatusCode)
        {
            if ((int)signupResponse.StatusCode == 422 || signupBody.Contains("already been registered"))
            {
                _logger.LogWarning("Registration failed: Email {Email} is already registered.", datos.Email);
                return (null, "El email ya esta registrado");
            }

            _logger.LogError("Auth signup failed. Status: {StatusCode}, Body: {Body}", signupResponse.StatusCode, signupBody);
            return (null, $"Error al crear cuenta en Auth: {signupBody}");
        }

        JsonDocument signupJson;
        try
        {
            signupJson = JsonDocument.Parse(signupBody);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse Auth signup JSON response.");
            throw new SupabaseResponseException("Received an invalid JSON response from Supabase Auth.", ex);
        }

        Guid userId;
        if (signupJson.RootElement.TryGetProperty("id", out var directId) && Guid.TryParse(directId.GetString(), out userId))
        {
            // Successfully parsed Guid
        }
        else
        {
            _logger.LogError("Could not extract or parse user ID from Auth response: {Body}", signupBody);
            return (null, "No se pudo obtener o parsear el ID del usuario creado");
        }

        var insertUrl = $"{_supabaseUrl}/rest/v1/rpc/alta_usuario";
        var insertPayload = new
        {
            p_id = userId,
            p_rol_id = 1,
            p_email = datos.Email,
            p_nombre = datos.Nombre,
            p_apellidos = datos.Apellidos,
            p_telefono = datos.Telefono
        };

        var insertRequest = new HttpRequestMessage(HttpMethod.Post, insertUrl);
        insertRequest.Headers.Add("apikey", _serviceRoleKey);
        if (actorId.HasValue) insertRequest.Headers.Add("x-actor-id", actorId.Value.ToString());
        insertRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        insertRequest.Content = JsonContent.Create(insertPayload);

        var insertResponse = await SendRequestAsync(insertRequest);

        if (!insertResponse.IsSuccessStatusCode)
        {
            var insertError = await insertResponse.Content.ReadAsStringAsync();

            if (insertError.Contains("23505"))
            {
                _logger.LogWarning("Registration failed at database insertion: Email {Email} already registered.", datos.Email);
                return (null, "El email ya esta registrado");
            }

            _logger.LogError("Database insertion failed for new user {UserId}. Status: {StatusCode}, Body: {Body}", userId, insertResponse.StatusCode, insertError);
            return (null, $"Usuario creado en Auth pero fallo al insertar en tabla: {insertError}");
        }

        var created = await ParseJsonAsync<UsuarioDto>(insertResponse.Content);
        return (created, null);
    }

    public async Task<(UsuarioDto? usuario, string? error)> CompletarPerfilAsync(Guid userId, CompletarPerfilRequestDto datos, string accessToken, Guid actorId)
    {
        var url = $"{_supabaseUrl}/rest/v1/rpc/cambio_usuario";
        
        var payload = new
        {
            p_id = userId,
            p_rol_id = (int?)null,
            p_nombre = datos.Nombre,
            p_apellidos = datos.Apellidos,
            p_telefono = datos.Telefono,
            p_debe_cambiar_password = (bool?)null
        };
        var request = new HttpRequestMessage(HttpMethod.Post, url);
        
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        
        var jsonString = JsonSerializer.Serialize(payload, new JsonSerializerOptions { DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.Never });
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");
        var response = await SendRequestAsync(request);
        
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("Failed to complete profile for user {UserId}. Status: {StatusCode}, Body: {Body}", userId, response.StatusCode, errorBody);
            return (null, $"Error al completar perfil: {errorBody}");
        }
        
        var updated = await ParseJsonAsync<UsuarioDto>(response.Content);
        return (updated, null);
    }

    public async Task<(List<UsuarioDto>? Items, int? TotalCount)> GetResidentesAsync(Guid condominioId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_usuarios?rol_id=eq.2&condominio_id=eq.{condominioId}&select=*";
        return await SupabaseQueryClient.GetPagedAsync<UsuarioDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion, true, condominioId);
    }

    public async Task<(List<UsuarioDto>? Items, int? TotalCount)> GetResidentesSinViviendaAsync(Guid condominioId, PaginationParams paginacion)
    {
        var resourcePath = $"vw_residentes_sin_vivienda?condominio_id=eq.{condominioId}&select=*";
        return await SupabaseQueryClient.GetPagedAsync<UsuarioDto>(
            _httpClient, _supabaseUrl, _serviceRoleKey, _serviceRoleKey, resourcePath, paginacion, true, condominioId);
    }

    public async Task<(UsuarioDto? usuario, string? error)> AsignarCondominioAdminAsync(Guid adminId, Guid condominioId)
    {
        // a) Validar que el usuario objetivo exista y tenga rol_id = 1
        var userRequestUrl = $"{_supabaseUrl}/rest/v1/vw_usuarios?id=eq.{adminId}&select=*";
        var userRequest = new HttpRequestMessage(HttpMethod.Get, userRequestUrl);
        userRequest.Headers.Add("apikey", _serviceRoleKey);
        userRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var userResponse = await SendRequestAsync(userRequest);
        if (!userResponse.IsSuccessStatusCode)
        {
            var err = await userResponse.Content.ReadAsStringAsync();
            _logger.LogError("Failed to fetch user {AdminId}. Status: {StatusCode}, Body: {Body}", adminId, userResponse.StatusCode, err);
            return (null, "Error al buscar el usuario");
        }

        var usuarios = await ParseJsonAsync<List<UsuarioDto>>(userResponse.Content);
        var targetUser = usuarios?.FirstOrDefault();

        if (targetUser == null)
        {
            return (null, "Usuario no encontrado");
        }

        if (targetUser.RolId?.ToString() != "1")
        {
            return (null, "El usuario debe tener rol de Administrador");
        }

        // b) Validar que no exista YA otro admin distinto asignado a ese condominio
        var adminRequestUrl = $"{_supabaseUrl}/rest/v1/vw_usuarios?rol_id=eq.1&condominio_id=eq.{condominioId}&select=id";
        var adminRequest = new HttpRequestMessage(HttpMethod.Get, adminRequestUrl);
        adminRequest.Headers.Add("apikey", _serviceRoleKey);
        adminRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        var adminResponse = await SendRequestAsync(adminRequest);
        if (!adminResponse.IsSuccessStatusCode)
        {
            var err = await adminResponse.Content.ReadAsStringAsync();
            _logger.LogError("Failed to check existing admins for condominio {CondominioId}. Status: {StatusCode}, Body: {Body}", condominioId, adminResponse.StatusCode, err);
            return (null, "Error al verificar administradores existentes");
        }

        var existingAdmins = await ParseJsonAsync<List<UsuarioDto>>(adminResponse.Content);
        if (existingAdmins != null && existingAdmins.Any(a => a.Id != adminId))
        {
            return (null, "Ya existe un administrador asignado a este condominio");
        }

        // c) Invocar RPC cambio_usuario
        var rpcUrl = $"{_supabaseUrl}/rest/v1/rpc/cambio_usuario";
        var rpcPayload = new
        {
            p_id = adminId,
            p_condominio_id = condominioId
        };

        var rpcRequest = new HttpRequestMessage(HttpMethod.Post, rpcUrl);
        rpcRequest.Headers.Add("apikey", _serviceRoleKey);
        rpcRequest.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
        
        var jsonString = JsonSerializer.Serialize(rpcPayload);
        rpcRequest.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var rpcResponse = await SendRequestAsync(rpcRequest);

        if (!rpcResponse.IsSuccessStatusCode)
        {
            var errorBody = await rpcResponse.Content.ReadAsStringAsync();
            _logger.LogError("Failed to link admin {AdminId} to condominio {CondominioId}. Status: {StatusCode}, Body: {Body}", adminId, condominioId, rpcResponse.StatusCode, errorBody);
            return (null, $"Error al vincular administrador: {errorBody}");
        }

        var updatedUsuario = await ParseJsonAsync<UsuarioDto>(rpcResponse.Content);
        return (updatedUsuario, null);
    }

    // Notificaciones
    public async Task<List<NotificacionDto>?> GetNotificacionesAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_notificaciones?usuario_id=eq.{userId}&order=creado_en.desc&limit=20";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch notificaciones for user {UserId}. Status: {StatusCode}", userId, response.StatusCode);
            return null;
        }

        return await ParseJsonAsync<List<NotificacionDto>>(response.Content) ?? new List<NotificacionDto>();
    }

    public async Task<int> GetContadorNoLeidasAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_notificaciones?usuario_id=eq.{userId}&leida=eq.false";
        var request = new HttpRequestMessage(HttpMethod.Head, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Add("Prefer", "count=exact");
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch count of unread notificaciones for user {UserId}. Status: {StatusCode}", userId, response.StatusCode);
            return 0;
        }

        if (response.Headers.TryGetValues("Content-Range", out var values))
        {
            var contentRange = values.FirstOrDefault();
            if (!string.IsNullOrEmpty(contentRange) && contentRange.Contains("/"))
            {
                var parts = contentRange.Split('/');
                if (parts.Length == 2 && int.TryParse(parts[1], out var total))
                {
                    return total;
                }
            }
        }

        return 0;
    }

    public async Task<bool> MarcarNotificacionComoLeidaAsync(Guid id, Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/marcar_notificacion_leida";
        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var payload = new { p_id = id, p_usuario_id = userId };
        var jsonString = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var response = await SendRequestAsync(request);
        return response.IsSuccessStatusCode;
    }

    public async Task<bool> MarcarTodasComoLeidasAsync(Guid userId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/rpc/marcar_todas_notificaciones_leidas";
        var request = new HttpRequestMessage(HttpMethod.Post, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var payload = new { p_usuario_id = userId };
        var jsonString = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var response = await SendRequestAsync(request);
        return response.IsSuccessStatusCode;
    }

    // Sub-usuarios
    public async Task<List<VwViviendaSubusuarioDto>?> GetSubusuariosActivosAsync(int viviendaId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_vivienda_subusuarios?vivienda_id=eq.{viviendaId}&activo=eq.true";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch active subusuarios for vivienda {ViviendaId}. Status: {StatusCode}", viviendaId, response.StatusCode);
            return null;
        }

        return await ParseJsonAsync<List<VwViviendaSubusuarioDto>>(response.Content);
    }

    public async Task<List<VwCodigoSubusuarioDto>?> GetInvitacionesSubusuarioAsync(int viviendaId, string accessToken)
    {
        var requestUrl = $"{_supabaseUrl}/rest/v1/vw_codigos_subusuario?vivienda_id=eq.{viviendaId}&es_vigente=eq.true";
        var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        var response = await SendRequestAsync(request);
        if (!response.IsSuccessStatusCode)
        {
            _logger.LogWarning("Failed to fetch pending invitations for vivienda {ViviendaId}. Status: {StatusCode}", viviendaId, response.StatusCode);
            return null;
        }

        return await ParseJsonAsync<List<VwCodigoSubusuarioDto>>(response.Content);
    }

    public async Task<(VwCodigoSubusuarioDto? invitacion, string? error)> InvitarSubusuarioAsync(int viviendaId, string parentesco, Guid creadoPor, string accessToken)
    {
        var url = $"{_supabaseUrl}/rest/v1/rpc/generar_codigo_subusuario";
        var payload = new
        {
            p_vivienda_id = viviendaId,
            p_parentesco = parentesco,
            p_creado_por = creadoPor
        };

        var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Add("x-actor-id", creadoPor.ToString());
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var jsonString = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var response = await SendRequestAsync(request);
        
        if (!response.IsSuccessStatusCode)
        {
            var errorBody = await response.Content.ReadAsStringAsync();
            _logger.LogError("Failed to generate subusuario code. Status: {StatusCode}, Body: {Body}", response.StatusCode, errorBody);
            
            if (response.StatusCode == System.Net.HttpStatusCode.Conflict)
            {
                return (null, "Límite máximo de 2 sub-usuarios alcanzado en la vivienda.");
            }
            
            return (null, $"Error al generar código: {errorBody}");
        }

        var invitacion = await ParseJsonAsync<VwCodigoSubusuarioDto>(response.Content);
        return (invitacion, null);
    }

    public async Task<bool> CancelarInvitacionAsync(Guid invitacionId, string accessToken)
    {
        var url = $"{_supabaseUrl}/rest/v1/rpc/cancelar_codigo_subusuario";
        var payload = new { p_id = invitacionId };

        var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var jsonString = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var response = await SendRequestAsync(request);
        return response.IsSuccessStatusCode;
    }

    public async Task<bool> RevocarSubusuarioAsync(int viviendaId, Guid usuarioId, string accessToken)
    {
        var url = $"{_supabaseUrl}/rest/v1/rpc/baja_subusuario";
        var payload = new { p_vivienda_id = viviendaId, p_usuario_id = usuarioId };

        var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Add("apikey", _anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);
        
        var jsonString = JsonSerializer.Serialize(payload);
        request.Content = new StringContent(jsonString, System.Text.Encoding.UTF8, "application/json");

        var response = await SendRequestAsync(request);
        return response.IsSuccessStatusCode;
    }
}