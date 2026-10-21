using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo de lectura completo que mapea todas las columnas de la vista 'vw_plantillas_cargo'.
/// </summary>
public class VwPlantillaCargo
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
    public DateOnly? VigenciaFin { get; set; }

    [JsonPropertyName("responsable_pago")]
    public ResponsablePago ResponsablePago { get; set; }

    [JsonPropertyName("activa")]
    public bool Activa { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid CreadoPor { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }

    [JsonPropertyName("modificado_por")]
    public Guid? ModificadoPor { get; set; }

    [JsonPropertyName("modificado_en")]
    public DateTimeOffset? ModificadoEn { get; set; }
}
