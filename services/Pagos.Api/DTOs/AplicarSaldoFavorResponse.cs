using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta para la aplicación manual de saldo a favor a un cargo.
/// Contiene { movimiento, cargo, saldo_a_favor }.
/// </summary>
public class AplicarSaldoFavorResponse
{
    [JsonPropertyName("movimiento")]
    public MovimientoSaldoResponse Movimiento { get; set; } = null!;

    [JsonPropertyName("cargo")]
    public CargoResponse Cargo { get; set; } = null!;

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }
}
