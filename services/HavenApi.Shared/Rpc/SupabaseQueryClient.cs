using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;

namespace HavenApi.Shared.Rpc;

public static class SupabaseQueryClient
{
    private class QueryErrorResponse
    {
        public string? Code { get; set; }
        public string? Message { get; set; }
    }

    public static async Task<(List<T>? Items, int? TotalCount)> GetPagedAsync<T>(
        HttpClient httpClient,
        string supabaseUrl,
        string apiKey,
        string accessTokenOrServiceRoleKey,
        string resourcePath,
        PaginationParams paginacion,
        bool actorHeader = false,
        Guid? actorId = null)
    {
        var url = $"{supabaseUrl}/rest/v1/{resourcePath}";
        
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        request.Headers.Add("apikey", apiKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", accessTokenOrServiceRoleKey);
        
        var (desde, hasta) = paginacion.ToRange();
        request.Headers.Add("Range", $"{desde}-{hasta}");
        request.Headers.Add("Prefer", "count=exact");

        if (actorHeader && actorId.HasValue)
        {
            request.Headers.Add("x-actor-id", actorId.Value.ToString());
        }

        var response = await httpClient.SendAsync(request);

        if (response.StatusCode == HttpStatusCode.OK || response.StatusCode == HttpStatusCode.PartialContent)
        {
            var items = await response.Content.ReadFromJsonAsync<List<T>>();
            int? totalCount = null;

            if (response.Headers.TryGetValues("Content-Range", out var contentRangeValues))
            {
                var contentRange = contentRangeValues.FirstOrDefault();
                if (!string.IsNullOrEmpty(contentRange))
                {
                    var parts = contentRange.Split('/');
                    if (parts.Length == 2 && parts[1] != "*")
                    {
                        if (int.TryParse(parts[1], out var parsedTotal))
                        {
                            totalCount = parsedTotal;
                        }
                    }
                }
            }

            return (items, totalCount);
        }

        var errorBody = await response.Content.ReadAsStringAsync();
        
        try
        {
            var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
            var errorData = JsonSerializer.Deserialize<QueryErrorResponse>(errorBody, options);

            if (errorData != null && !string.IsNullOrEmpty(errorData.Message))
            {
                throw new SupabaseResponseException(errorData.Message);
            }
        }
        catch (JsonException)
        {
            // Ignore JSON exception and fall back to the unknown error
        }

        throw new SupabaseResponseException($"Error inesperado del servidor: {errorBody}");
    }
}
