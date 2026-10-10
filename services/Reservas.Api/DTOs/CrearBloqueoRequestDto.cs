using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class CrearBloqueoRequestDto : IValidatableObject
{
    [Required(ErrorMessage = "El área es obligatoria")]
    [JsonPropertyName("areaId")]
    public Guid? AreaId { get; set; }

    [Required(ErrorMessage = "El inicio es obligatorio")]
    [JsonPropertyName("inicio")]
    public DateTimeOffset? Inicio { get; set; }

    [Required(ErrorMessage = "El fin es obligatorio")]
    [JsonPropertyName("fin")]
    public DateTimeOffset? Fin { get; set; }

    [Required(ErrorMessage = "El motivo es obligatorio")]
    [MaxLength(500, ErrorMessage = "El motivo no puede exceder 500 caracteres")]
    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (string.IsNullOrWhiteSpace(Motivo))
        {
            yield return new ValidationResult(
                "El motivo es obligatorio y no puede estar compuesto solo de espacios.",
                new[] { nameof(Motivo) }
            );
        }

        if (Inicio.HasValue && Fin.HasValue && Fin.Value <= Inicio.Value)
        {
            yield return new ValidationResult(
                "El fin del bloqueo debe ser posterior al inicio.",
                new[] { nameof(Inicio), nameof(Fin) }
            );
        }
    }
}
