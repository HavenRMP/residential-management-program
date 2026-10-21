using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta para representar un movimiento de saldo a favor.
/// </summary>
public class MovimientoSaldoResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid? CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int? ViviendaId { get; set; }

    [JsonPropertyName("tipo")]
    public TipoMovimientoSaldo Tipo { get; set; }

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("monto_con_signo")]
    public decimal? MontoConSigno { get; set; }

    [JsonPropertyName("pago_id")]
    public Guid? PagoId { get; set; }

    [JsonPropertyName("cargo_id")]
    public Guid? CargoId { get; set; }

    [JsonPropertyName("movimiento_origen_id")]
    public Guid? MovimientoOrigenId { get; set; }

    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid? CreadoPor { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset? CreadoEn { get; set; }
}
