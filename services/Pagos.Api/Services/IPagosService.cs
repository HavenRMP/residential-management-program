using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

/// <summary>
/// Interfaz para el servicio de gestión de pagos residenciales.
/// </summary>
public interface IPagosService
{
    /// <summary>
    /// Registra un pago directo realizado por un administrador para un cargo del condominio.
    /// El pago nace en estado Confirmado.
    /// </summary>
    Task<RegistrarPagoResponse> RegistrarPagoAdminAsync(RegistrarPagoAdminRequest request);

    /// <summary>
    /// Reporta un pago realizado por un inquilino con su comprobante para un cargo de su vivienda.
    /// El pago nace en estado PendienteConfirmacion.
    /// </summary>
    Task<PagoResponse> ReportarPagoInquilinoAsync(ReportarPagoRequest request);

    /// <summary>
    /// Confirma un pago reportado (exclusivo para Administrador).
    /// </summary>
    Task<ConfirmarPagoResponse> ConfirmarPagoAdminAsync(Guid id);

    /// <summary>
    /// Rechaza un pago reportado especificando el motivo (exclusivo para Administrador).
    /// </summary>
    Task<RechazarPagoResponse> RechazarPagoAdminAsync(Guid id, RechazarPagoRequest request);

    /// <summary>
    /// Anula un pago confirmado mediante un movimiento de reversa (exclusivo para Administrador).
    /// </summary>
    Task<AnularPagoResponse> AnularPagoAdminAsync(Guid id, AnularPagoRequest request);
}
