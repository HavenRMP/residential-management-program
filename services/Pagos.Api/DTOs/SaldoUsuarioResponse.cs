using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta que consolida los saldos de todas las viviendas asociadas a un usuario e incluye el desglose individual.
/// </summary>
public class SaldoUsuarioResponse
{
    [JsonPropertyName("total_pendiente")]
    public decimal TotalPendiente { get; set; }

    [JsonPropertyName("total_vencido")]
    public decimal TotalVencido { get; set; }

    [JsonPropertyName("total_cargos_abiertos")]
    public int TotalCargosAbiertos { get; set; }

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }

    [JsonPropertyName("viviendas")]
    public List<SaldoViviendaResponse> Viviendas { get; set; } = new();

    public static SaldoUsuarioResponse CrearVacio() => new();
}
