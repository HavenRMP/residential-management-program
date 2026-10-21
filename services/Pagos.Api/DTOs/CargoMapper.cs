using Pagos.Api.Models;
using Pagos.Api.Utils;

namespace Pagos.Api.DTOs;

/// <summary>
/// Mapeador centralizado de modelos de lectura de cargos hacia DTOs de respuesta.
/// </summary>
public static class CargoMapper
{
    /// <summary>
    /// Convierte una entidad de lectura <see cref="VwCargo"/> a <see cref="CargoResponse"/>.
    /// </summary>
    public static CargoResponse ToResponse(this VwCargo vw)
    {
        ArgumentNullException.ThrowIfNull(vw);

        return new CargoResponse
        {
            Id = vw.Id,
            CondominioId = vw.CondominioId,
            ViviendaId = vw.ViviendaId,
            NumeroCasa = vw.NumeroCasa,
            PlantillaId = vw.PlantillaId,
            Periodo = PeriodoHelper.ATextoOpcional(vw.Periodo),
            Tipo = vw.Tipo,
            Concepto = vw.Concepto,
            Monto = vw.Monto,
            MontoPagadoConfirmado = vw.MontoPagadoConfirmado,
            SaldoPendiente = vw.SaldoPendiente,
            Estado = vw.Estado,
            EstadoEfectivo = vw.EstaVencido ? "Vencido" : vw.Estado.ToString(),
            FechaVencimiento = vw.FechaVencimiento,
            ResponsablePago = vw.ResponsablePago,
            MotivoCancelacion = vw.MotivoCancelacion,
            CreadoEn = vw.CreadoEn
        };
    }

    /// <summary>
    /// Convierte una colección de entidades de lectura <see cref="VwCargo"/> a una lista de <see cref="CargoResponse"/>.
    /// </summary>
    public static List<CargoResponse> ToResponseList(this IEnumerable<VwCargo> items)
    {
        ArgumentNullException.ThrowIfNull(items);

        return items.Select(ToResponse).ToList();
    }
}
