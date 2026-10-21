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

    /// <summary>
    /// Consulta el listado de pagos con filtros opcionales y paginación (Admin e Inquilino).
    /// </summary>
    Task<RespuestaPaginadaDto<PagoResponse>> ListarPagosAsync(ConsultaPagosFiltrosDto filtros);

    /// <summary>
    /// Obtiene el detalle completo de un pago por su identificador único.
    /// Admin: solo pagos de su condominio. Inquilino: solo pagos de sus viviendas (P6, método 3).
    /// </summary>
    Task<PagoResponse> ObtenerPagoPorIdAsync(Guid id);

    /// <summary>
    /// Genera una URL firmada de acceso temporal al comprobante de un pago.
    /// Admin: solo pagos de su condominio. Inquilino: solo pagos de sus viviendas (P6, método 3).
    /// </summary>
    Task<ComprobanteUrlResponse> ObtenerComprobanteUrlAsync(Guid id, CancellationToken cancellationToken = default);
}
