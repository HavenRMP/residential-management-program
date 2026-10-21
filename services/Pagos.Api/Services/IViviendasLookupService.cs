namespace Pagos.Api.Services;

public interface IViviendasLookupService
{
    Task<List<int>> GetViviendaIdsPorUsuarioTitularAsync(Guid usuarioId);
    Task<bool> ExisteViviendaEnCondominioAsync(int viviendaId, Guid condominioId);
    Task<bool> EsResidenteTitularAsync(int viviendaId, Guid usuarioId);
}
