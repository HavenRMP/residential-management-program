using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de solicitud para que el inquilino reporte un pago con comprobante.
/// </summary>
public class ReportarPagoRequest
{
    [Required]
    [JsonPropertyName("cargo_id")]
    public Guid CargoId { get; set; }

    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "El monto debe ser mayor a cero.")]
    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [Required]
    [JsonPropertyName("fecha_pago")]
    public DateOnly FechaPago { get; set; }

    [Required]
    [JsonPropertyName("metodo")]
    public MetodoPago Metodo { get; set; }

    [JsonPropertyName("referencia")]
    public string? Referencia { get; set; }

    [JsonPropertyName("banco_origen")]
    public string? BancoOrigen { get; set; }

    [JsonPropertyName("comprobante")]
    public ComprobantePagoDto? Comprobante { get; set; }

    [JsonPropertyName("comprobante_ruta")]
    public string? ComprobanteRuta { get; set; }

    [JsonPropertyName("comprobante_hash")]
    public string? ComprobanteHash { get; set; }

    public string? ObtenerComprobanteRuta() => Comprobante?.Ruta ?? ComprobanteRuta;
    public string? ObtenerComprobanteHash() => Comprobante?.Hash ?? ComprobanteHash;
}

/// <summary>
/// Alias tipado para ReportarPagoRequest.
/// </summary>
public class ReportarPagoInquilinoRequest : ReportarPagoRequest
{
}
