using Pagos.Api.Models;

namespace Pagos.Api.DTOs;

/// <summary>
/// Mapeador centralizado para transformar registros VSaldoVivienda a SaldoViviendaResponse.
/// </summary>
public static class SaldoMapper
{
    public static SaldoViviendaResponse ToResponse(this VSaldoVivienda v)
    {
        ArgumentNullException.ThrowIfNull(v);

        return new SaldoViviendaResponse
        {
            ViviendaId = v.ViviendaId,
            CondominioId = v.CondominioId,
            NumeroCasa = v.NumeroCasa,
            TotalPendiente = v.TotalPendiente,
            TotalVencido = v.TotalVencido,
            TotalCargosAbiertos = v.TotalCargosAbiertos,
            SaldoAFavor = v.SaldoAFavor
        };
    }

    public static List<SaldoViviendaResponse> ToResponseList(this IEnumerable<VSaldoVivienda> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        return items.Select(ToResponse).ToList();
    }
}
