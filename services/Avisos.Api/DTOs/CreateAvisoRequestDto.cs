using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Avisos.Api.DTOs;

public class CreateAvisoRequestDto : IValidatableObject
{
    [Required(ErrorMessage = "El título es obligatorio")]
    [MaxLength(150, ErrorMessage = "El título no puede exceder 150 caracteres")]
    [JsonPropertyName("titulo")]
    public string Titulo { get; set; } = string.Empty;

    [Required(ErrorMessage = "El contenido es obligatorio")]
    [JsonPropertyName("contenido")]
    public string Contenido { get; set; } = string.Empty;

    [Range(1, 365, ErrorMessage = "La duración en días debe estar entre 1 y 365")]
    [JsonPropertyName("duracion_dias")]
    public int? DuracionDias { get; set; }

    [JsonPropertyName("fecha_expiracion")]
    public DateTimeOffset? FechaExpiracion { get; set; }

    [JsonPropertyName("prioridad")]
    public string? Prioridad { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (DuracionDias.HasValue && FechaExpiracion.HasValue)
            yield return new ValidationResult("La duración en días y la fecha de expiración son mutuamente excluyentes, especifique solo uno.", new[] { nameof(DuracionDias), nameof(FechaExpiracion) });

        if (FechaExpiracion.HasValue && FechaExpiracion.Value <= DateTimeOffset.UtcNow)
            yield return new ValidationResult("La fecha de expiración debe ser una fecha futura.", new[] { nameof(FechaExpiracion) });
    }
}
