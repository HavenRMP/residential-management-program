using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class ResidenteVigilanciaDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("nombre")]
    public string? Nombre { get; set; }

    [JsonPropertyName("apellidos")]
    public string? Apellidos { get; set; }

    [JsonPropertyName("telefono")]
    public string? Telefono { get; set; }
}
