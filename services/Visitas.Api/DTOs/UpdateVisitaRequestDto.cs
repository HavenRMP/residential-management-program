using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class UpdateVisitaRequestDto : IValidatableObject
{
    [MaxLength(100, ErrorMessage = "El nombre del visitante no puede exceder 100 caracteres.")]
    [JsonPropertyName("nombreVisitante")]
    public string? NombreVisitante { get; set; }

    [MaxLength(100, ErrorMessage = "Los apellidos del visitante no pueden exceder 100 caracteres.")]
    [JsonPropertyName("apellidosVisitante")]
    public string? ApellidosVisitante { get; set; }

    [MaxLength(20, ErrorMessage = "El teléfono del visitante no puede exceder 20 caracteres.")]
    [JsonPropertyName("telefonoVisitante")]
    public string? TelefonoVisitante { get; set; }

    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }

    [Range(0, 20, ErrorMessage = "El número de acompañantes debe estar entre 0 y 20.")]
    [JsonPropertyName("numAcompanantes")]
    public int? NumAcompanantes { get; set; }

    [MaxLength(15, ErrorMessage = "Las placas del vehículo no pueden exceder 15 caracteres.")]
    [JsonPropertyName("vehiculoPlacas")]
    public string? VehiculoPlacas { get; set; }

    [MaxLength(500, ErrorMessage = "Las notas no pueden exceder 500 caracteres.")]
    [JsonPropertyName("notas")]
    public string? Notas { get; set; }

    [JsonPropertyName("fechaLlegadaEsperada")]
    public DateTimeOffset? FechaLlegadaEsperada { get; set; }

    [Range(1, 72, ErrorMessage = "Las horas de vigencia deben estar entre 1 y 72.")]
    [JsonPropertyName("horasVigencia")]
    public int? HorasVigencia { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (NombreVisitante == null && ApellidosVisitante == null && TelefonoVisitante == null &&
            Motivo == null && NumAcompanantes == null && VehiculoPlacas == null &&
            Notas == null && FechaLlegadaEsperada == null && HorasVigencia == null)
        {
            yield return new ValidationResult("Debe indicar al menos un campo a modificar.");
        }

        if (!string.IsNullOrWhiteSpace(Motivo))
        {
            var motivoLower = Motivo.Trim().ToLowerInvariant();
            if (motivoLower == "paqueteria")
            {
                yield return new ValidationResult("La recepción de paquetería ahora se gestiona desde su propio módulo. Por favor actualiza tu aplicación para registrar paquetes esperados.", new[] { nameof(Motivo) });
            }
            else
            {
                var motivosValidos = new[] { "personal", "familiar", "proveedor", "servicio" };
                if (!motivosValidos.Contains(motivoLower))
                {
                    yield return new ValidationResult("El motivo ingresado no es válido.", new[] { nameof(Motivo) });
                }
            }
        }
        
        if (FechaLlegadaEsperada.HasValue && FechaLlegadaEsperada.Value == default)
        {
            yield return new ValidationResult("La fecha esperada de llegada no es válida.", new[] { nameof(FechaLlegadaEsperada) });
        }
    }
}
