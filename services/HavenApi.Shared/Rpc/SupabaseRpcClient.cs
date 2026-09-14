using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Exceptions;

namespace HavenApi.Shared.Rpc;

public static class SupabaseRpcClient
{
    private class RpcErrorResponse
    {
        public string? Code { get; set; }
        public string? Message { get; set; }
    }

    public static async Task<T?> PostRpcAsync<T>(
        HttpClient httpClient,
        string supabaseUrl,
        string serviceRoleKey,
        string rpcName,
        object payload,
        Guid actorId)
    {
        var url = $"{supabaseUrl}/rest/v1/rpc/{rpcName}";
        
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        request.Headers.Add("apikey", serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", serviceRoleKey);
        request.Headers.Add("x-actor-id", actorId.ToString());
        request.Content = JsonContent.Create(payload);

        var response = await httpClient.SendAsync(request);

        if (response.IsSuccessStatusCode)
        {
            return await response.Content.ReadFromJsonAsync<T>();
        }

        var errorBody = await response.Content.ReadAsStringAsync();
        
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
            // Ignore JSON exception and fall back to the unknown error
        }

        throw new SupabaseRpcException("UNKNOWN", $"Error inesperado del servidor: {errorBody}");
    }
}
