using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Solicitud para registrar manualmente un nuevo cargo residencial.
/// </summary>
public class CrearCargoRequest
{
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("tipo")]
    public TipoCargo Tipo { get; set; }

    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("periodo")]
    public string? Periodo { get; set; }

    [JsonPropertyName("fecha_vencimiento")]
    public DateOnly FechaVencimiento { get; set; }

    [JsonPropertyName("responsable_pago")]
    public ResponsablePago? ResponsablePago { get; set; }
}
