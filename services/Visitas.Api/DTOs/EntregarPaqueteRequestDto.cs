using System.ComponentModel.DataAnnotations;

namespace Visitas.Api.DTOs;

public class EntregarPaqueteRequestDto
{
    [Required]
    [StringLength(100)]
    public string EntregadoANombre { get; set; } = null!;
}
