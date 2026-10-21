using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Parámetros de consulta y filtrado para el listado de plantillas de cargo recurrente.
/// </summary>
public class ConsultaPlantillasCargoFiltrosDto : ParametrosPaginacionDto
{
    /// <summary>
    /// Filtrar por identificador de vivienda específico.
    /// </summary>
    [FromQuery(Name = "vivienda_id")]
    public int? ViviendaId { get; set; }

    [FromQuery(Name = "viviendaId")]
    public int? ViviendaIdAlias
    {
        get => ViviendaId;
        set => ViviendaId ??= value;
    }

    /// <summary>
    /// Filtrar por tipo de cargo.
    /// </summary>
    [FromQuery(Name = "tipo")]
    public TipoCargo? Tipo { get; set; }

    /// <summary>
    /// Filtrar por estado de la plantilla (activa o inactiva).
    /// </summary>
    [FromQuery(Name = "activa")]
    public bool? Activa { get; set; }
}
