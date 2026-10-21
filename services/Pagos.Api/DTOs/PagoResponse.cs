using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO completo de respuesta para representar un pago hacia los clientes de la API.
/// Excluye comprobante_ruta y comprobante_hash por seguridad y privacidad.
/// </summary>
public class PagoResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("cargo_id")]
    public Guid CargoId { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("cargo_tipo")]
    public TipoCargo CargoTipo { get; set; }

    [JsonPropertyName("cargo_concepto")]
    public string CargoConcepto { get; set; } = string.Empty;

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

    [JsonPropertyName("banco_origen")]
    public string? BancoOrigen { get; set; }

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

    [JsonPropertyName("motivo_rechazo")]
    public string? MotivoRechazo { get; set; }

    [JsonPropertyName("motivo_anulacion")]
    public string? MotivoAnulacion { get; set; }

    [JsonPropertyName("registrado_por")]
    public Guid RegistradoPor { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }

    [JsonPropertyName("confirmado_por")]
    public Guid? ConfirmadoPor { get; set; }

    [JsonPropertyName("confirmado_en")]
    public DateTimeOffset? ConfirmadoEn { get; set; }

    [JsonPropertyName("rechazado_por")]
    public Guid? RechazadoPor { get; set; }

    [JsonPropertyName("rechazado_en")]
    public DateTimeOffset? RechazadoEn { get; set; }

    [JsonPropertyName("anulado_por")]
    public Guid? AnuladoPor { get; set; }

    [JsonPropertyName("anulado_en")]
    public DateTimeOffset? AnuladoEn { get; set; }
}
