using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Elemento de vivienda para el alta masiva de plantillas de cargo.
/// </summary>
public class PlantillaViviendaItemDto
{
    /// <summary>
    /// Identificador único de la vivienda en el condominio.
    /// </summary>
    [Required]
    [Range(1, int.MaxValue, ErrorMessage = "El identificador de vivienda debe ser mayor a cero.")]
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    /// <summary>
    /// Monto específico opcional para esta vivienda que reemplaza al monto común.
    /// </summary>
    [Range(0.01, double.MaxValue, ErrorMessage = "El monto específico debe ser mayor a cero.")]
    [JsonPropertyName("monto")]
    public decimal? Monto { get; set; }
}
