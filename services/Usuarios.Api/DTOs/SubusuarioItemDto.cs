using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class SubusuarioItemDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; } // usuario_id for active, or codigo_id for invitation

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("telefono")]
    public string Telefono { get; set; } = string.Empty;

    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = string.Empty; // "Activo" or "Pendiente"

    [JsonPropertyName("creado_en")]
    public DateTime? CreadoEn { get; set; }
}
