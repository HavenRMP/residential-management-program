using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Parámetros de filtrado y paginación para la consulta de cargos.
/// </summary>
public class ConsultaCargosFiltrosDto : ParametrosPaginacionDto
{
    /// <summary>
    /// ID de la vivienda a filtrar.
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
    /// ID del usuario titular a consultar (Solo permitido para administradores).
    /// </summary>
    [FromQuery(Name = "usuario_id")]
    public Guid? UsuarioId { get; set; }

    [FromQuery(Name = "usuarioId")]
    public Guid? UsuarioIdAlias
    {
        get => UsuarioId;
        set => UsuarioId ??= value;
    }

    /// <summary>
    /// Tipo de cargo (Renta, Mantenimiento, Servicio, Multa, Otro).
    /// </summary>
    [FromQuery(Name = "tipo")]
    public TipoCargo? Tipo { get; set; }

    /// <summary>
    /// Estado persistido del cargo (Pendiente, Parcial, Pagado, Cancelado).
    /// </summary>
    [FromQuery(Name = "estado")]
    public EstadoCargo? Estado { get; set; }

    /// <summary>
    /// Filtro para consultar cargos vencidos (true) o vigentes (false).
    /// </summary>
    [FromQuery(Name = "vencido")]
    public bool? Vencido { get; set; }

    /// <summary>
    /// Periodo en formato YYYY-MM.
    /// </summary>
    [FromQuery(Name = "periodo")]
    public string? Periodo { get; set; }

    /// <summary>
    /// Fecha de vencimiento inicial del rango (desde).
    /// </summary>
    [FromQuery(Name = "vencimiento_desde")]
    public DateOnly? VencimientoDesde { get; set; }

    [FromQuery(Name = "desde")]
    public DateOnly? DesdeAlias
    {
        get => VencimientoDesde;
        set => VencimientoDesde ??= value;
    }

    /// <summary>
    /// Fecha de vencimiento final del rango (hasta).
    /// </summary>
    [FromQuery(Name = "vencimiento_hasta")]
    public DateOnly? VencimientoHasta { get; set; }

    [FromQuery(Name = "hasta")]
    public DateOnly? HastaAlias
    {
        get => VencimientoHasta;
        set => VencimientoHasta ??= value;
    }
}
