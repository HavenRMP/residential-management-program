using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class VigilanteDto
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
    public string Telefono { get; set; } = string.Empty;

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid? CondominioId { get; set; }
}
