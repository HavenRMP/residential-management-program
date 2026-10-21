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

    /// <summary>
    /// Convierte una entidad <see cref="VwPago"/> al DTO completo <see cref="PagoResponse"/>.
    /// </summary>
    public static PagoResponse ToResponse(this VwPago vw)
    {
        ArgumentNullException.ThrowIfNull(vw);

        return new PagoResponse
        {
            Id = vw.Id,
            CargoId = vw.CargoId,
            CondominioId = vw.CondominioId,
            ViviendaId = vw.ViviendaId,
            NumeroCasa = vw.NumeroCasa,
            CargoTipo = vw.CargoTipo,
            CargoConcepto = vw.CargoConcepto,
            Monto = vw.Monto,
            MontoCubierto = vw.MontoCubierto,
            MontoExcedente = vw.MontoExcedente,
            FechaPago = vw.FechaPago,
            Metodo = vw.Metodo,
            Referencia = vw.Referencia,
            BancoOrigen = vw.BancoOrigen,
            Estado = vw.Estado,
            Origen = vw.Origen,
            TieneComprobante = vw.TieneComprobante,
            EsReversa = vw.EsReversa,
            PagoOriginalId = vw.PagoOriginalId,
            MotivoRechazo = vw.MotivoRechazo,
            MotivoAnulacion = vw.MotivoAnulacion,
            RegistradoPor = vw.RegistradoPor,
            CreadoEn = vw.CreadoEn,
            ConfirmadoPor = vw.ConfirmadoPor,
            ConfirmadoEn = vw.ConfirmadoEn,
            RechazadoPor = vw.RechazadoPor,
            RechazadoEn = vw.RechazadoEn,
            AnuladoPor = vw.AnuladoPor,
            AnuladoEn = vw.AnuladoEn
        };
    }

    /// <summary>
    /// Convierte una colección de entidades <see cref="VwPago"/> a lista de <see cref="PagoResponse"/>.
    /// </summary>
    public static List<PagoResponse> ToResponseList(this IEnumerable<VwPago> items)
    {
        ArgumentNullException.ThrowIfNull(items);

        return items.Select(ToResponse).ToList();
    }
}
