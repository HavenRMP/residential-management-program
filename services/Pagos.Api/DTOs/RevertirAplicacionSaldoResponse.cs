using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta resultante de revertir una aplicación de saldo a favor.
/// Contiene { movimiento, cargo, saldo_a_favor }.
/// </summary>
public class RevertirAplicacionSaldoResponse
{
    [JsonPropertyName("movimiento")]
    public MovimientoSaldoResponse Movimiento { get; set; } = null!;

    [JsonPropertyName("cargo")]
    public CargoResponse Cargo { get; set; } = null!;

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }
}
