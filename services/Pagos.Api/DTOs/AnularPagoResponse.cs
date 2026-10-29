using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta resultante de la anulación de un pago confirmado.
/// Contiene { pago_anulado, pago_reversa (o null), cargo, movimiento_saldo (o null), saldo_a_favor }.
/// </summary>
public class AnularPagoResponse
{
    [JsonPropertyName("pago_anulado")]
    public PagoResponse PagoAnulado { get; set; } = null!;

    /// <summary>
    /// Solo se llena si la RPC devuelve un pago de reversa; la BD actual no lo crea.
    /// </summary>
    [JsonPropertyName("pago_reversa")]
    public PagoResponse? PagoReversa { get; set; }

    [JsonPropertyName("cargo")]
    public CargoResponse Cargo { get; set; } = null!;

    [JsonPropertyName("movimiento_saldo")]
    public MovimientoSaldoResponse? MovimientoSaldo { get; set; }

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }
}
