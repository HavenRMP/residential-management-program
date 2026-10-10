using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class MotivoObligatorioRequestDto : IValidatableObject
{
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
    }
}
