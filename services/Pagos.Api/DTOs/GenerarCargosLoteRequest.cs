using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Solicitud de generación manual de cargos por lote a partir de plantillas recurrentes.
/// </summary>
public class GenerarCargosLoteRequest
{
    /// <summary>
    /// Periodo del cargo en formato año-mes (ej. '2026-11').
    /// </summary>
    [Required(ErrorMessage = "El periodo es obligatorio.")]
    [JsonPropertyName("periodo")]
    public string Periodo { get; set; } = string.Empty;

    /// <summary>
    /// Lista opcional de identificadores de plantilla para restringir la generación.
    /// Si es nula o vacía, aplica a todas las plantillas activas del condominio.
    /// </summary>
    [JsonPropertyName("plantilla_ids")]
    public List<Guid>? PlantillaIds { get; set; }
}
