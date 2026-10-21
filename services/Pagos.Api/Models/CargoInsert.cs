using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo de escritura para insertar registros en la tabla 'cargos'.
/// Contiene exclusivamente las columnas persistibles de la tabla, sin campos calculados.
/// </summary>
public class CargoInsert
{
    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("plantilla_id")]
    public Guid? PlantillaId { get; set; }

    [JsonPropertyName("tipo")]
    public TipoCargo Tipo { get; set; }

    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("periodo")]
    public DateOnly? Periodo { get; set; }

    [JsonPropertyName("fecha_vencimiento")]
    public DateOnly FechaVencimiento { get; set; }

    [JsonPropertyName("responsable_pago")]
    public ResponsablePago ResponsablePago { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid CreadoPor { get; set; }
}
