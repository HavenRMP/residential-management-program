using System.Text.Json.Serialization;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo de lectura para la vista 'v_saldo_vivienda' de la base de datos.
/// Mapea el saldo pendiente, vencido, cargos abiertos y saldo a favor por vivienda.
/// </summary>
public class VSaldoVivienda
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
