using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class UpdatePaqueteEsperadoRequestDto : IValidatableObject
{
    [MaxLength(100, ErrorMessage = "El nombre del destinatario no puede exceder 100 caracteres.")]
    [JsonPropertyName("destinatarioNombre")]
    public string? DestinatarioNombre { get; set; }

    [JsonPropertyName("servicioId")]
    public int? ServicioId { get; set; }

    [MaxLength(50, ErrorMessage = "El nombre del servicio no puede exceder 50 caracteres.")]
    [JsonPropertyName("servicioNombre")]
    public string? ServicioNombre { get; set; }

    [MaxLength(100, ErrorMessage = "El número de guía no puede exceder 100 caracteres.")]
    [JsonPropertyName("numeroGuia")]
    public string? NumeroGuia { get; set; }

    [MaxLength(250, ErrorMessage = "La descripción no puede exceder 250 caracteres.")]
    [JsonPropertyName("descripcion")]
    public string? Descripcion { get; set; }

    [JsonPropertyName("notas")]
    public string? Notas { get; set; }

    [JsonPropertyName("fechaEsperadaDesde")]
    public DateTimeOffset? FechaEsperadaDesde { get; set; }

    [JsonPropertyName("fechaEsperadaHasta")]
    public DateTimeOffset? FechaEsperadaHasta { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (DestinatarioNombre == null && ServicioId == null && ServicioNombre == null &&
            NumeroGuia == null && Descripcion == null && Notas == null &&
            FechaEsperadaDesde == null && FechaEsperadaHasta == null)
        {
            yield return new ValidationResult("Debe indicar al menos un campo a modificar.");
        }

        if (FechaEsperadaDesde.HasValue && FechaEsperadaHasta.HasValue && FechaEsperadaHasta.Value <= FechaEsperadaDesde.Value)
        {
            yield return new ValidationResult("La fecha límite esperada debe ser posterior a la fecha inicial.", new[] { nameof(FechaEsperadaHasta) });
        }
    }
}
