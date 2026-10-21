using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de resumen de un pago asociado a un cargo.
/// Por seguridad y privacidad, NUNCA expone comprobante_ruta ni comprobante_hash.
/// </summary>
public class PagoResumenResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("monto_cubierto")]
    public decimal MontoCubierto { get; set; }

    [JsonPropertyName("monto_excedente")]
    public decimal MontoExcedente { get; set; }

    [JsonPropertyName("fecha_pago")]
    public DateOnly FechaPago { get; set; }

    [JsonPropertyName("metodo")]
    public MetodoPago Metodo { get; set; }

    [JsonPropertyName("referencia")]
    public string? Referencia { get; set; }

    [JsonPropertyName("estado")]
    public EstadoPago Estado { get; set; }

    [JsonPropertyName("origen")]
    public OrigenPago Origen { get; set; }

    [JsonPropertyName("tiene_comprobante")]
    public bool TieneComprobante { get; set; }

    [JsonPropertyName("es_reversa")]
    public bool EsReversa { get; set; }

    [JsonPropertyName("pago_original_id")]
    public Guid? PagoOriginalId { get; set; }
}
