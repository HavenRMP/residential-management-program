using Pagos.Api.Models;

namespace Pagos.Api.DTOs;

/// <summary>
/// Mapeador centralizado para convertir entidades de lectura de pagos a DTOs de respuesta.
/// </summary>
public static class PagoMapper
{
    /// <summary>
    /// Convierte una entidad <see cref="VwPago"/> al DTO de resumen <see cref="PagoResumenResponse"/>.
    /// </summary>
    public static PagoResumenResponse ToResumenResponse(this VwPago vw)
    {
        ArgumentNullException.ThrowIfNull(vw);

        return new PagoResumenResponse
        {
            Id = vw.Id,
            Monto = vw.Monto,
            MontoCubierto = vw.MontoCubierto,
            MontoExcedente = vw.MontoExcedente,
            FechaPago = vw.FechaPago,
            Metodo = vw.Metodo,
            Referencia = vw.Referencia,
            Estado = vw.Estado,
            Origen = vw.Origen,
            TieneComprobante = vw.TieneComprobante,
            EsReversa = vw.EsReversa,
            PagoOriginalId = vw.PagoOriginalId
        };
    }

    /// <summary>
    /// Convierte una lista de entidades <see cref="VwPago"/> a lista de <see cref="PagoResumenResponse"/>.
    /// </summary>
    public static List<PagoResumenResponse> ToResumenResponseList(this IEnumerable<VwPago> items)
    {
        ArgumentNullException.ThrowIfNull(items);

        return items.Select(ToResumenResponse).ToList();
    }
}
