using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class InvitarSubusuarioRequestDto
{
    [Required]
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [Required]
    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [Required]
    [JsonPropertyName("apellidos")]
    public string Apellidos { get; set; } = string.Empty;

    [Required]
    [JsonPropertyName("email")]
    [EmailAddress]
    public string Email { get; set; } = string.Empty;

    [Required]
    [JsonPropertyName("telefono")]
    public string Telefono { get; set; } = string.Empty;

    [Required]
    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;
}
