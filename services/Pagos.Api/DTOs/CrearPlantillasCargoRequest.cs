using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Solicitud de alta masiva de plantillas de cargo recurrente por vivienda.
/// </summary>
public class CrearPlantillasCargoRequest
{
    /// <summary>
    /// Concepto del cargo recurrente (1 a 200 caracteres).
    /// </summary>
    [Required]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "El concepto debe tener entre 1 y 200 caracteres.")]
    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    /// <summary>
    /// Tipo de cargo a generar periódicamente.
    /// </summary>
    [Required]
    [JsonPropertyName("tipo")]
    public TipoCargo Tipo { get; set; }

    /// <summary>
    /// Monto común aplicable por defecto a todas las viviendas indicadas (mayor a 0, máximo 2 decimales).
    /// </summary>
    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "El monto debe ser mayor a cero.")]
    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    /// <summary>
    /// Día del mes para el vencimiento de los cargos generados (entre 1 y 31).
    /// </summary>
    [Required]
    [Range(1, 31, ErrorMessage = "El día de vencimiento debe estar entre 1 y 31.")]
    [JsonPropertyName("dia_vencimiento")]
    public int DiaVencimiento { get; set; }

    /// <summary>
    /// Fecha de inicio de vigencia de la plantilla.
    /// </summary>
    [Required]
    [JsonPropertyName("vigencia_inicio")]
    public DateOnly VigenciaInicio { get; set; }

    /// <summary>
    /// Fecha de fin de vigencia opcional. Si se especifica, no puede ser anterior a vigencia_inicio.
    /// </summary>
    [JsonPropertyName("vigencia_fin")]
    public DateOnly? VigenciaFin { get; set; }

    /// <summary>
    /// Responsable del pago opcional (Propietario o Inquilino).
    /// </summary>
    [JsonPropertyName("responsable_pago")]
    public ResponsablePago? ResponsablePago { get; set; }

    /// <summary>
    /// Lista de viviendas a las que se les creará una plantilla (1 a 200 elementos sin duplicados).
    /// </summary>
    [Required]
    [JsonPropertyName("viviendas")]
    public List<PlantillaViviendaItemDto> Viviendas { get; set; } = new();
}
