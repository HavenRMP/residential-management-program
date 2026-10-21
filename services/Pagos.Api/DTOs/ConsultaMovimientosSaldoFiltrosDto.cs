using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Parámetros de consulta y filtrado para el listado de movimientos de saldo a favor de una vivienda.
/// Hereda la paginación estándar (page/pageSize o pagina/tamanoPagina).
/// </summary>
public class ConsultaMovimientosSaldoFiltrosDto : ParametrosPaginacionDto
{
    /// <summary>
    /// Tipo opcional de movimiento de saldo a favor (Abono, Aplicacion, ReversoAbono, ReversoAplicacion).
    /// </summary>
    [FromQuery(Name = "tipo")]
    public TipoMovimientoSaldo? Tipo { get; set; }

    /// <summary>
    /// Fecha y hora inicial del rango de consulta sobre 'creado_en'.
    /// </summary>
    [FromQuery(Name = "desde")]
    public DateTimeOffset? Desde { get; set; }

    [FromQuery(Name = "fecha_desde")]
    public DateTimeOffset? FechaDesdeAlias
    {
        get => Desde;
        set => Desde ??= value;
    }

    [FromQuery(Name = "fechaDesde")]
    public DateTimeOffset? FechaDesdeCamelAlias
    {
        get => Desde;
        set => Desde ??= value;
    }

    /// <summary>
    /// Fecha y hora final del rango de consulta sobre 'creado_en'.
    /// </summary>
    [FromQuery(Name = "hasta")]
    public DateTimeOffset? Hasta { get; set; }

    [FromQuery(Name = "fecha_hasta")]
    public DateTimeOffset? FechaHastaAlias
    {
        get => Hasta;
        set => Hasta ??= value;
    }

    [FromQuery(Name = "fechaHasta")]
    public DateTimeOffset? FechaHastaCamelAlias
    {
        get => Hasta;
        set => Hasta ??= value;
    }
}
