using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta para representar un cargo hacia los clientes de la API.
/// </summary>
public class CargoResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("plantilla_id")]
    public Guid? PlantillaId { get; set; }

    [JsonPropertyName("periodo")]
    public string? Periodo { get; set; }

    [JsonPropertyName("tipo")]
    public TipoCargo Tipo { get; set; }

    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("monto_pagado_confirmado")]
    public decimal MontoPagadoConfirmado { get; set; }

    [JsonPropertyName("saldo_pendiente")]
    public decimal SaldoPendiente { get; set; }

    [JsonPropertyName("estado")]
    public EstadoCargo Estado { get; set; }

    [JsonPropertyName("estado_efectivo")]
    public string EstadoEfectivo { get; set; } = string.Empty;

    [JsonPropertyName("fecha_vencimiento")]
    public DateOnly FechaVencimiento { get; set; }

    [JsonPropertyName("responsable_pago")]
    public ResponsablePago ResponsablePago { get; set; }

    [JsonPropertyName("motivo_cancelacion")]
    public string? MotivoCancelacion { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
