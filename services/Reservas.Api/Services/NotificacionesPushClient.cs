using System;
using System.Collections.Generic;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using HavenApi.Shared.Exceptions;
using Reservas.Api.DTOs;

namespace Reservas.Api.Services;

public class NotificacionesPushClient : INotificacionesPushClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<NotificacionesPushClient> _logger;
    private readonly string _supabaseUrl;
    private readonly string _serviceRoleKey;

    private class RpcErrorResponse
    {
        [JsonPropertyName("code")]
        public string? Code { get; set; }

        [JsonPropertyName("message")]
        public string? Message { get; set; }
    }

    public NotificacionesPushClient(
        HttpClient httpClient,
        IConfiguration configuration,
        ILogger<NotificacionesPushClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _supabaseUrl = configuration["Supabase:Url"] ?? throw new InvalidOperationException("Supabase:Url is not configured.");
        _serviceRoleKey = configuration["Supabase:ServiceRoleKey"] ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
    }

    private async Task<T?> PostRpcAsync<T>(string rpcName, object payload, CancellationToken cancellationToken)
    {
        var url = $"{_supabaseUrl.TrimEnd('/')}/rest/v1/rpc/{rpcName}";

        HttpResponseMessage response;
        try
        {
            using var request = new HttpRequestMessage(HttpMethod.Post, url);
            request.Headers.Add("apikey", _serviceRoleKey);
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);
            request.Content = JsonContent.Create(payload);

            response = await _httpClient.SendAsync(request, cancellationToken);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Network error when calling Supabase RPC {RpcName} at {Url}", rpcName, url);
            throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
        }
        catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
        {
            _logger.LogError(ex, "Timeout when calling Supabase RPC {RpcName} at {Url}", rpcName, url);
            throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
        }

        using (response)
        {
            if (!response.IsSuccessStatusCode)
            {
                string errorBody;
                try
                {
                    errorBody = await response.Content.ReadAsStringAsync(cancellationToken);
                }
                catch (HttpRequestException ex)
                {
                    _logger.LogError(ex, "Network error when reading error response from Supabase RPC {RpcName}", rpcName);
                    throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
                }
                catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
                {
                    _logger.LogError(ex, "Timeout when reading error response from Supabase RPC {RpcName}", rpcName);
                    throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
                }

                try
                {
                    var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                    var errorData = JsonSerializer.Deserialize<RpcErrorResponse>(errorBody, options);

                    if (errorData != null && !string.IsNullOrEmpty(errorData.Code))
                    {
                        throw new SupabaseRpcException(errorData.Code, errorData.Message ?? string.Empty);
                    }
                }
                catch (JsonException)
                {
                    // Fall back to UNKNOWN
                }

                throw new SupabaseRpcException("UNKNOWN", $"Error inesperado del servidor: {errorBody}");
            }

            try
            {
                return await response.Content.ReadFromJsonAsync<T>(cancellationToken: cancellationToken);
            }
            catch (JsonException ex)
            {
                _logger.LogError(ex, "Failed to parse JSON response from Supabase RPC {RpcName}.", rpcName);
                throw new SupabaseResponseException("Received an invalid JSON response from Supabase.", ex);
            }
            catch (HttpRequestException ex)
            {
                _logger.LogError(ex, "Network error when reading response from Supabase RPC {RpcName}", rpcName);
                throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
            }
            catch (TaskCanceledException ex) when (!cancellationToken.IsCancellationRequested)
            {
                _logger.LogError(ex, "Timeout when reading response from Supabase RPC {RpcName}", rpcName);
                throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
            }
        }
    }

    public async Task<List<NotificacionPushPendienteDto>> ReclamarPendientesAsync(int limite, CancellationToken cancellationToken = default)
    {
        var payload = new { p_limite = limite };
        var resultado = await PostRpcAsync<List<NotificacionPushPendienteDto>>(
            "reclamar_notificaciones_push_reservas",
            payload,
            cancellationToken);

        return resultado ?? new List<NotificacionPushPendienteDto>();
    }

    public async Task<bool> MarcarEnviadaAsync(Guid notificacionId, CancellationToken cancellationToken = default)
    {
        var payload = new { p_id = notificacionId };
        var resultado = await PostRpcAsync<bool>(
            "marcar_notificacion_push_enviada",
            payload,
            cancellationToken);

        return resultado;
    }

    public async Task<bool> LiberarAsync(Guid notificacionId, CancellationToken cancellationToken = default)
    {
        var payload = new { p_id = notificacionId };
        var resultado = await PostRpcAsync<bool>(
            "liberar_notificacion_push",
            payload,
            cancellationToken);

        return resultado;
    }
}
