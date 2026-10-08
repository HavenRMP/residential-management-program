using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class CreatePaqueteEsperadoRequestDto : IValidatableObject
{
    [Required(ErrorMessage = "La vivienda es obligatoria.")]
    [JsonPropertyName("viviendaId")]
    public int ViviendaId { get; set; }

    [Required(ErrorMessage = "El nombre del destinatario es obligatorio.")]
    [MaxLength(100, ErrorMessage = "El nombre del destinatario no puede exceder 100 caracteres.")]
    [JsonPropertyName("destinatarioNombre")]
    public string DestinatarioNombre { get; set; } = string.Empty;

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
        if (!ServicioId.HasValue && string.IsNullOrWhiteSpace(ServicioNombre))
        {
            yield return new ValidationResult("Debe proporcionar un servicio o un nombre de servicio.", new[] { nameof(ServicioId), nameof(ServicioNombre) });
        }

        if (FechaEsperadaDesde.HasValue && FechaEsperadaHasta.HasValue && FechaEsperadaHasta.Value <= FechaEsperadaDesde.Value)
        {
            yield return new ValidationResult("La fecha límite esperada debe ser posterior a la fecha inicial.", new[] { nameof(FechaEsperadaHasta) });
        }
    }
}
