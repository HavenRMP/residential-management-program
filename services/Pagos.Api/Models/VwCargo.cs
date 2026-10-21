using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo de lectura que mapea todas las columnas de la vista 'vw_cargos'.
/// </summary>
public class VwCargo
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("condominio_nombre")]
    public string CondominioNombre { get; set; } = string.Empty;

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("plantilla_id")]
    public Guid? PlantillaId { get; set; }

    [JsonPropertyName("periodo")]
    public DateOnly? Periodo { get; set; }

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

    [JsonPropertyName("fecha_vencimiento")]
    public DateOnly FechaVencimiento { get; set; }

    [JsonPropertyName("esta_vencido")]
    public bool EstaVencido { get; set; }

    [JsonPropertyName("responsable_pago")]
    public ResponsablePago ResponsablePago { get; set; }

    [JsonPropertyName("motivo_cancelacion")]
    public string? MotivoCancelacion { get; set; }

    [JsonPropertyName("cancelado_por")]
    public Guid? CanceladoPor { get; set; }

    [JsonPropertyName("cancelado_en")]
    public DateTimeOffset? CanceladoEn { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid CreadoPor { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
