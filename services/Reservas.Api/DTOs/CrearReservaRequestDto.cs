using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class CrearReservaRequestDto : IValidatableObject
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

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (Inicio.HasValue && Fin.HasValue && Fin.Value <= Inicio.Value)
        {
            yield return new ValidationResult(
                "El fin de la reserva debe ser posterior al inicio.",
                new[] { nameof(Inicio), nameof(Fin) }
            );
        }
    }
}
