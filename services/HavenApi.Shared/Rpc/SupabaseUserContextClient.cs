using System;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using HavenApi.Shared.Exceptions;

namespace HavenApi.Shared.Rpc;

public static class SupabaseUserContextClient
{
    public static async Task<(string? RolNombre, Guid? CondominioId)> GetContextoUsuarioAsync(
        HttpClient httpClient, 
        string baseUrl, 
        string anonKey, 
        Guid userId, 
        string accessToken)
    {
        var requestUrl = $"{baseUrl}/rest/v1/vw_usuarios?id=eq.{userId}&select=rol_nombre,condominio_id";

        using var request = new HttpRequestMessage(HttpMethod.Get, requestUrl);
        request.Headers.Add("apikey", anonKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessToken);

        HttpResponseMessage response;
        try
        {
            response = await httpClient.SendAsync(request);
        }
        catch (HttpRequestException ex)
        {
            throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
        }
        catch (TaskCanceledException ex)
        {
            throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
        }

        if (!response.IsSuccessStatusCode)
        {
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
}
