using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta con los saldos consolidados de una vivienda (en pesos mexicanos MXN).
/// </summary>
public class SaldoViviendaResponse
{
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("total_pendiente")]
    public decimal TotalPendiente { get; set; }

    [JsonPropertyName("total_vencido")]
    public decimal TotalVencido { get; set; }

    [JsonPropertyName("total_cargos_abiertos")]
    public int TotalCargosAbiertos { get; set; }

    [JsonPropertyName("saldo_a_favor")]
    public decimal SaldoAFavor { get; set; }
}
