using System.ComponentModel.DataAnnotations;

namespace Visitas.Api.DTOs;

public class CreateServicioPaqueteriaRequestDto
{
    [Required]
    [StringLength(50)]
    public string Nombre { get; set; } = null!;
    
    public string? IconoUrl { get; set; }
}
