using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class ResponderInvitacionDto
{
    [Required]
    [JsonPropertyName("respuesta")]
    public string Respuesta { get; set; } = string.Empty; // "ACEPTADA" o "RECHAZADA"
}
