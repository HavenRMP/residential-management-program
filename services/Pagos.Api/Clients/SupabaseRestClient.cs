using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;

namespace Pagos.Api.Clients;

public class SupabaseRestClient : ISupabaseRestClient
{
    private readonly HttpClient _httpClient;
    private readonly ILogger<SupabaseRestClient> _logger;
    private readonly string _supabaseUrl;
    private readonly string _serviceRoleKey;

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true
    };

    public SupabaseRestClient(HttpClient httpClient, IConfiguration configuration, ILogger<SupabaseRestClient> logger)
    {
        _httpClient = httpClient;
        _logger = logger;
        _supabaseUrl = (configuration["Supabase:Url"] ?? throw new InvalidOperationException("Supabase:Url is not configured.")).TrimEnd('/');
        _serviceRoleKey = configuration["Supabase:ServiceRoleKey"] ?? throw new InvalidOperationException("Supabase:ServiceRoleKey is not configured.");
    }

    private void AddAuthHeaders(HttpRequestMessage request, Guid? actorId = null)
    {
        request.Headers.Add("apikey", _serviceRoleKey);
        request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _serviceRoleKey);

        if (actorId.HasValue)
        {
            request.Headers.Add("x-actor-id", actorId.Value.ToString());
        }
    }

    private async Task<HttpResponseMessage> SendRequestAsync(HttpRequestMessage request)
    {
        try
        {
            return await _httpClient.SendAsync(request);
        }
        catch (HttpRequestException ex)
        {
            _logger.LogError(ex, "Network error when calling Supabase REST at {Url}", request.RequestUri);
            throw new SupabaseUnavailableException("A network error occurred while communicating with Supabase.", ex);
        }
        catch (TaskCanceledException ex)
        {
            _logger.LogError(ex, "Timeout when calling Supabase REST at {Url}", request.RequestUri);
            throw new SupabaseUnavailableException("The request to Supabase timed out.", ex);
        }
    }

    private async Task EnsureSuccessAsync(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode)
        {
            return;
        }

        var errorBody = await response.Content.ReadAsStringAsync();
        _logger.LogWarning("Supabase REST request failed with status {StatusCode}: {ErrorBody}", response.StatusCode, errorBody);

        throw PostgrestErrorTranslator.ParseAndTranslate(errorBody);
    }

    private async Task<T?> ParseJsonAsync<T>(HttpContent content)
    {
        try
        {
            return await content.ReadFromJsonAsync<T>(JsonOptions);
        }
        catch (JsonException ex)
        {
            _logger.LogError(ex, "Failed to parse JSON response from Supabase REST.");
            throw new SupabaseResponseException("Received an invalid JSON response from Supabase.", ex);
        }
    }

    private string BuildUrl(string tableOrView, string? queryString = null)
    {
        var baseEndpoint = tableOrView.TrimStart('/');
        if (string.IsNullOrWhiteSpace(queryString))
        {
            return $"{_supabaseUrl}/rest/v1/{baseEndpoint}";
        }

        var separator = baseEndpoint.Contains('?') ? "&" : "?";
        return $"{_supabaseUrl}/rest/v1/{baseEndpoint}{separator}{queryString.TrimStart('?', '&')}";
    }

    public async Task<List<T>> GetAsync<T>(string tableOrView, string? queryString = null)
    {
        var url = BuildUrl(tableOrView, queryString);
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        AddAuthHeaders(request);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var items = await ParseJsonAsync<List<T>>(response.Content);
        return items ?? new List<T>();
    }

    public async Task<T?> GetSingleOrDefaultAsync<T>(string tableOrView, string? queryString = null)
    {
        var items = await GetAsync<T>(tableOrView, queryString);
        return items.FirstOrDefault();
    }

    public async Task<(List<T> Items, int? TotalCount)> GetPagedAsync<T>(
        string tableOrView, 
        PaginationParams paginacion, 
        string? queryString = null)
    {
        var url = BuildUrl(tableOrView, queryString);
        using var request = new HttpRequestMessage(HttpMethod.Get, url);
        AddAuthHeaders(request);

        var (desde, hasta) = paginacion.ToRange();
        request.Headers.TryAddWithoutValidation("Range", $"{desde}-{hasta}");
        request.Headers.Add("Prefer", "count=exact");

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var items = await ParseJsonAsync<List<T>>(response.Content) ?? new List<T>();
        int? totalCount = null;

        if (response.Headers.TryGetValues("Content-Range", out var contentRangeValues) ||
            response.Content.Headers.TryGetValues("Content-Range", out contentRangeValues))
        {
            var contentRange = contentRangeValues.FirstOrDefault();
            if (!string.IsNullOrEmpty(contentRange))
            {
                var parts = contentRange.Split('/');
                if (parts.Length == 2 && parts[1] != "*" && int.TryParse(parts[1], out var parsedTotal))
                {
                    totalCount = parsedTotal;
                }
            }
        }

        return (items, totalCount);
    }

    public async Task<T?> RpcAsync<T>(string rpcName, object payload, Guid? actorId = null)
    {
        var url = $"{_supabaseUrl}/rest/v1/rpc/{rpcName.TrimStart('/')}";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request, actorId);
        request.Content = JsonContent.Create(payload, options: JsonOptions);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        if (response.StatusCode == HttpStatusCode.NoContent)
        {
            return default;
        }

        return await ParseJsonAsync<T>(response.Content);
    }

    public async Task<T> InsertSingleAsync<T>(string table, object data, Guid? actorId = null)
    {
        var url = $"{_supabaseUrl}/rest/v1/{table.TrimStart('/')}";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request, actorId);
        request.Headers.Add("Prefer", "return=representation");
        request.Content = JsonContent.Create(data, options: JsonOptions);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var contentString = await response.Content.ReadAsStringAsync();
        try
        {
            var list = JsonSerializer.Deserialize<List<T>>(contentString, JsonOptions);
            if (list != null && list.Count > 0)
            {
                return list[0];
            }
        }
        catch (JsonException)
        {
            var single = JsonSerializer.Deserialize<T>(contentString, JsonOptions);
            if (single != null)
            {
                return single;
            }
        }

        throw new SupabaseResponseException("PostgREST no devolvió la fila insertada.");
    }

    public async Task<List<T>> InsertManyAsync<T>(string table, IEnumerable<object> data, Guid? actorId = null)
    {
        var url = $"{_supabaseUrl}/rest/v1/{table.TrimStart('/')}";
        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request, actorId);
        request.Headers.Add("Prefer", "return=representation");
        request.Content = JsonContent.Create(data, options: JsonOptions);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var items = await ParseJsonAsync<List<T>>(response.Content);
        return items ?? new List<T>();
    }

    public async Task<List<T>> InsertManyIgnoreDuplicatesAsync<T>(
        string table, 
        IEnumerable<object> data, 
        string onConflictColumns, 
        Guid? actorId = null)
    {
        var baseTable = table.TrimStart('/');
        var separator = baseTable.Contains('?') ? "&" : "?";
        var url = $"{_supabaseUrl}/rest/v1/{baseTable}{separator}on_conflict={Uri.EscapeDataString(onConflictColumns)}";

        using var request = new HttpRequestMessage(HttpMethod.Post, url);
        AddAuthHeaders(request, actorId);
        request.Headers.Add("Prefer", "resolution=ignore-duplicates,return=representation");
        request.Content = JsonContent.Create(data, options: JsonOptions);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var items = await ParseJsonAsync<List<T>>(response.Content);
        return items ?? new List<T>();
    }

    public async Task<List<T>> PatchAsync<T>(string table, string queryString, object patchData, Guid? actorId = null)
    {
        var url = BuildUrl(table, queryString);
        using var request = new HttpRequestMessage(HttpMethod.Patch, url);
        AddAuthHeaders(request, actorId);
        request.Headers.Add("Prefer", "return=representation");
        request.Content = JsonContent.Create(patchData, options: JsonOptions);

        var response = await SendRequestAsync(request);
        await EnsureSuccessAsync(response);

        var items = await ParseJsonAsync<List<T>>(response.Content);
        return items ?? new List<T>();
    }
}
