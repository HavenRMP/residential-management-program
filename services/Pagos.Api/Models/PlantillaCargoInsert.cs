using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo de escritura para insertar registros en la tabla 'plantillas_cargo'.
/// </summary>
public class PlantillaCargoInsert
{
    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("tipo")]
    public TipoCargo Tipo { get; set; }

    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("dia_vencimiento")]
    public int DiaVencimiento { get; set; }

    [JsonPropertyName("vigencia_inicio")]
    public DateOnly VigenciaInicio { get; set; }

    [JsonPropertyName("vigencia_fin")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public DateOnly? VigenciaFin { get; set; }

    [JsonPropertyName("responsable_pago")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public ResponsablePago? ResponsablePago { get; set; }

    [JsonPropertyName("activa")]
    public bool Activa { get; set; } = true;

    [JsonPropertyName("creado_por")]
    public Guid CreadoPor { get; set; }
}
