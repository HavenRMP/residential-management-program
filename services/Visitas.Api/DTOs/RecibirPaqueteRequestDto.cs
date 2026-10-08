using System.ComponentModel.DataAnnotations;

namespace Visitas.Api.DTOs;

public class RecibirPaqueteRequestDto : IValidatableObject
{
    public Guid? PaqueteId { get; set; }
    public int? ViviendaId { get; set; }
    
    [StringLength(100)]
    public string? DestinatarioNombre { get; set; }
    
    public int? ServicioId { get; set; }
    
    [StringLength(50)]
    public string? ServicioNombre { get; set; }
    
    [StringLength(100)]
    public string? NumeroGuia { get; set; }
    
    [StringLength(250)]
    public string? Descripcion { get; set; }
    
    [StringLength(50)]
    public string? UbicacionAlmacen { get; set; }

    public IEnumerable<ValidationResult> Validate(ValidationContext validationContext)
    {
        if (!PaqueteId.HasValue)
        {
            if (!ViviendaId.HasValue)
            {
                yield return new ValidationResult("La vivienda es obligatoria si no se especifica el paquete esperado.", new[] { nameof(ViviendaId) });
            }
            if (string.IsNullOrWhiteSpace(DestinatarioNombre))
            {
                yield return new ValidationResult("El nombre del destinatario es obligatorio si no se especifica el paquete esperado.", new[] { nameof(DestinatarioNombre) });
            }
        }
    }
}
