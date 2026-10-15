using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class ActualizarBloqueoRequestDto : IValidatableObject
{
    [JsonPropertyName("inicio")]
    public DateTimeOffset? Inicio { get; set; }

    [JsonPropertyName("fin")]
    public DateTimeOffset? Fin { get; set; }

    [MaxLength(500, ErrorMessage = "El motivo no puede exceder 500 caracteres")]
    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Motivo != null && string.IsNullOrWhiteSpace(Motivo))
        {
            yield return new ValidationResult(
                "El motivo no puede estar compuesto solo de espacios.",
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
