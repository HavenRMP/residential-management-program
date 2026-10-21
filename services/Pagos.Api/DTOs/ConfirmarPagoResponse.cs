namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta resultante de la confirmación de un pago reportado.
/// Contiene { pago, cargo, movimiento_saldo (o null), saldo_a_favor }.
/// </summary>
public class ConfirmarPagoResponse : RegistrarPagoResponse
{
}
