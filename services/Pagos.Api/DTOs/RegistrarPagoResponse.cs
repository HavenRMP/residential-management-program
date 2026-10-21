using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta resultante del registro de un pago directo.
/// </summary>
public class RegistrarPagoResponse
{
    [JsonPropertyName("pago")]
    public PagoResponse Pago { get; set; } = null!;

    [JsonPropertyName("cargo")]
    public CargoResponse Cargo { get; set; } = null!;

    [JsonPropertyName("movimiento_saldo")]
    public MovimientoSaldoResponse? MovimientoSaldo { get; set; }

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }
}
