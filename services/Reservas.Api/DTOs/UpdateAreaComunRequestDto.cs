using System;
using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class UpdateAreaComunRequestDto : IValidatableObject
{
    [MaxLength(100, ErrorMessage = "El nombre no puede exceder 100 caracteres")]
    [JsonPropertyName("nombre")]
    public string? Nombre { get; set; }

    [MaxLength(500, ErrorMessage = "La descripción no puede exceder 500 caracteres")]
    [JsonPropertyName("descripcion")]
    public string? Descripcion { get; set; }

    [JsonPropertyName("horaApertura")]
    public TimeOnly? HoraApertura { get; set; }

    [JsonPropertyName("horaCierre")]
    public TimeOnly? HoraCierre { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (HoraApertura.HasValue && HoraCierre.HasValue)
        {
            if (HoraApertura.Value >= HoraCierre.Value)
            {
                yield return new ValidationResult(
                    "La hora de apertura debe ser menor a la hora de cierre.",
                    new[] { nameof(HoraApertura), nameof(HoraCierre) }
                );
            }
        }
    }
}
