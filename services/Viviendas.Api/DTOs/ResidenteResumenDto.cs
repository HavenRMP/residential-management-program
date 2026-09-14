using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class ResidenteResumenDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("apellidos")]
    public string Apellidos { get; set; } = string.Empty;

    [JsonPropertyName("telefono")]
    public string? Telefono { get; set; }
}
