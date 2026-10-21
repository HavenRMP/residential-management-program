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
}
