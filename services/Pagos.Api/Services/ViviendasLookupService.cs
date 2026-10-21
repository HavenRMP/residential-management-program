using Pagos.Api.Clients;
using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

public class ViviendasLookupService : IViviendasLookupService
{
    private readonly ISupabaseRestClient _supabaseRestClient;

    public ViviendasLookupService(ISupabaseRestClient supabaseRestClient)
    {
        _supabaseRestClient = supabaseRestClient;
    }

    /// <summary>
    /// Obtiene los IDs de las viviendas asignadas a un usuario titular consultando 'vivienda_residente'.
    /// Devuelve una lista vacía si no tiene viviendas asignadas.
    /// </summary>
    public async Task<List<int>> GetViviendaIdsPorUsuarioTitularAsync(Guid usuarioId)
    {
        var queryString = $"usuario_id=eq.{usuarioId}&select=vivienda_id";
        var items = await _supabaseRestClient.GetAsync<ViviendaResidenteItemDto>("vivienda_residente", queryString);

        if (items == null || items.Count == 0)
        {
            return new List<int>();
        }

        return items.Select(x => x.ViviendaId).Distinct().ToList();
    }

    /// <summary>
    /// Determina si una vivienda existe y pertenece al condominio especificado consultando 'viviendas'.
    /// </summary>
    public async Task<bool> ExisteViviendaEnCondominioAsync(int viviendaId, Guid condominioId)
    {
        var queryString = $"id=eq.{viviendaId}&condominio_id=eq.{condominioId}&select=id";
        var vivienda = await _supabaseRestClient.GetSingleOrDefaultAsync<ViviendaItemDto>("viviendas", queryString);

        return vivienda != null;
    }

    /// <summary>
    /// Verifica si un usuario es residente titular de una vivienda dada consultando 'vivienda_residente'.
    /// </summary>
    public async Task<bool> EsResidenteTitularAsync(int viviendaId, Guid usuarioId)
    {
        var queryString = $"vivienda_id=eq.{viviendaId}&usuario_id=eq.{usuarioId}&select=vivienda_id";
        var asignacion = await _supabaseRestClient.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>("vivienda_residente", queryString);

        return asignacion != null;
    }
}
