using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Parámetros de filtrado y paginación para la consulta de pagos.
/// </summary>
public class ConsultaPagosFiltrosDto : ParametrosPaginacionDto
{
    /// <summary>
    /// ID del cargo asociado al pago.
    /// </summary>
    [FromQuery(Name = "cargo_id")]
    public Guid? CargoId { get; set; }

    [FromQuery(Name = "cargoId")]
    public Guid? CargoIdAlias
    {
        get => CargoId;
        set => CargoId ??= value;
    }

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
    /// Estado del pago (PendienteConfirmacion, Confirmado, Rechazado, Anulado).
    /// </summary>
    [FromQuery(Name = "estado")]
    public EstadoPago? Estado { get; set; }

    /// <summary>
    /// Método de pago utilizado (Transferencia, Deposito, Efectivo, SaldoAFavor, Cheque, Tarjeta, Otro).
    /// </summary>
    [FromQuery(Name = "metodo")]
    public MetodoPago? Metodo { get; set; }

    /// <summary>
    /// Origen del registro del pago (Admin, Inquilino).
    /// </summary>
    [FromQuery(Name = "origen")]
    public OrigenPago? Origen { get; set; }

    /// <summary>
    /// Indica si se filtran registros de reversa (true) o pagos normales (false).
    /// </summary>
    [FromQuery(Name = "es_reversa")]
    public bool? EsReversa { get; set; }

    [FromQuery(Name = "esReversa")]
    public bool? EsReversaAlias
    {
        get => EsReversa;
        set => EsReversa ??= value;
    }

    /// <summary>
    /// Fecha de pago inicial del rango (desde).
    /// </summary>
    [FromQuery(Name = "fecha_pago_desde")]
    public DateOnly? FechaPagoDesde { get; set; }

    [FromQuery(Name = "desde")]
    public DateOnly? DesdeAlias
    {
        get => FechaPagoDesde;
        set => FechaPagoDesde ??= value;
    }

    [FromQuery(Name = "fechaPagoDesde")]
    public DateOnly? FechaPagoDesdeCamelAlias
    {
        get => FechaPagoDesde;
        set => FechaPagoDesde ??= value;
    }

    /// <summary>
    /// Fecha de pago final del rango (hasta).
    /// </summary>
    [FromQuery(Name = "fecha_pago_hasta")]
    public DateOnly? FechaPagoHasta { get; set; }

    [FromQuery(Name = "hasta")]
    public DateOnly? HastaAlias
    {
        get => FechaPagoHasta;
        set => FechaPagoHasta ??= value;
    }

    [FromQuery(Name = "fechaPagoHasta")]
    public DateOnly? FechaPagoHastaCamelAlias
    {
        get => FechaPagoHasta;
        set => FechaPagoHasta ??= value;
    }
}
