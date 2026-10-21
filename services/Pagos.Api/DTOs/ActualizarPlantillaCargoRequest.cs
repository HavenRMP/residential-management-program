using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;
using Pagos.Api.Enums;

namespace Pagos.Api.DTOs;

/// <summary>
/// Solicitud para actualizar los datos editables de una plantilla de cargo recurrente existente.
/// No permite modificar la vivienda asociada ni el tipo de cargo.
/// </summary>
public class ActualizarPlantillaCargoRequest
{
    /// <summary>
    /// Concepto del cargo recurrente (1 a 200 caracteres).
    /// </summary>
    [Required]
    [StringLength(200, MinimumLength = 1, ErrorMessage = "El concepto debe tener entre 1 y 200 caracteres.")]
    [JsonPropertyName("concepto")]
    public string Concepto { get; set; } = string.Empty;

    /// <summary>
    /// Monto del cargo recurrente (mayor a cero, máximo 2 decimales).
    /// </summary>
    [Required]
    [Range(0.01, double.MaxValue, ErrorMessage = "El monto debe ser mayor a cero.")]
    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    /// <summary>
    /// Día del mes para el vencimiento (entre 1 y 31).
    /// </summary>
    [Required]
    [Range(1, 31, ErrorMessage = "El día de vencimiento debe estar entre 1 y 31.")]
    [JsonPropertyName("dia_vencimiento")]
    public int DiaVencimiento { get; set; }

    /// <summary>
    /// Fecha de fin de vigencia opcional. Si se especifica, no puede ser anterior a la vigencia_inicio de la plantilla.
    /// </summary>
    [JsonPropertyName("vigencia_fin")]
    public DateOnly? VigenciaFin { get; set; }

    /// <summary>
    /// Responsable del pago opcional.
    /// </summary>
    [JsonPropertyName("responsable_pago")]
    public ResponsablePago? ResponsablePago { get; set; }
}
