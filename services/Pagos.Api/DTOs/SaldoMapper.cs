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

    public static MovimientoSaldoResponse ToResponse(this VwMovimientoSaldoFavor m)
    {
        ArgumentNullException.ThrowIfNull(m);

        return new MovimientoSaldoResponse
        {
            Id = m.Id,
            CondominioId = m.CondominioId,
            ViviendaId = m.ViviendaId,
            Tipo = m.Tipo,
            Monto = m.Monto,
            MontoConSigno = m.MontoConSigno,
            PagoId = m.PagoId,
            CargoId = m.CargoId,
            MovimientoOrigenId = m.MovimientoOrigenId,
            Motivo = m.Motivo,
            CreadoPor = m.CreadoPor,
            CreadoEn = m.CreadoEn
        };
    }

    public static List<MovimientoSaldoResponse> ToResponseList(this IEnumerable<VwMovimientoSaldoFavor> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        return items.Select(ToResponse).ToList();
    }
}
