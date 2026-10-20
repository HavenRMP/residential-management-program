using HavenApi.Shared.Pagination;

namespace Pagos.Api.Clients;

public interface ISupabaseRestClient
{
    Task<List<T>> GetAsync<T>(string tableOrView, string? queryString = null);
    Task<T?> GetSingleOrDefaultAsync<T>(string tableOrView, string? queryString = null);
    Task<(List<T> Items, int? TotalCount)> GetPagedAsync<T>(string tableOrView, PaginationParams paginacion, string? queryString = null);
    Task<T?> RpcAsync<T>(string rpcName, object payload, Guid? actorId = null);
    Task<T> InsertSingleAsync<T>(string table, object data, Guid? actorId = null);
    Task<List<T>> InsertManyAsync<T>(string table, IEnumerable<object> data, Guid? actorId = null);
    Task<List<T>> InsertManyIgnoreDuplicatesAsync<T>(string table, IEnumerable<object> data, string onConflictColumns, Guid? actorId = null);
    Task<List<T>> PatchAsync<T>(string table, string queryString, object patchData, Guid? actorId = null);
}
