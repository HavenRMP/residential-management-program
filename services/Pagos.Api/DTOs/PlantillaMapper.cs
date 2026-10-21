using Pagos.Api.Models;

namespace Pagos.Api.DTOs;

/// <summary>
/// Mapeador centralizado para transformar entidades de lectura VwPlantillaCargo a PlantillaResponse.
/// </summary>
public static class PlantillaMapper
{
    public static PlantillaResponse ToResponse(this VwPlantillaCargo vw)
    {
        ArgumentNullException.ThrowIfNull(vw);

        return new PlantillaResponse
        {
            Id = vw.Id,
            CondominioId = vw.CondominioId,
            CondominioNombre = vw.CondominioNombre,
            ViviendaId = vw.ViviendaId,
            NumeroCasa = vw.NumeroCasa,
            Tipo = vw.Tipo,
            Concepto = vw.Concepto,
            Monto = vw.Monto,
            DiaVencimiento = vw.DiaVencimiento,
            VigenciaInicio = vw.VigenciaInicio,
            VigenciaFin = vw.VigenciaFin,
            ResponsablePago = vw.ResponsablePago,
            Activa = vw.Activa,
            CreadoPor = vw.CreadoPor,
            CreadoEn = vw.CreadoEn,
            ModificadoPor = vw.ModificadoPor,
            ModificadoEn = vw.ModificadoEn
        };
    }

    public static List<PlantillaResponse> ToResponseList(this IEnumerable<VwPlantillaCargo> items)
    {
        ArgumentNullException.ThrowIfNull(items);
        return items.Select(ToResponse).ToList();
    }
}
