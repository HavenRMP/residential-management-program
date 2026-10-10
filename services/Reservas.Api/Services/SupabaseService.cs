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
}
