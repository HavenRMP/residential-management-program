using System.Text.Json.Serialization;

namespace Condominios.Api.DTOs;

public class UsuarioResumenDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("rol_id")]
    public int RolId { get; set; }

    [JsonPropertyName("rol_nombre")]
    public string RolNombre { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("apellidos")]
    public string Apellidos { get; set; } = string.Empty;

    [JsonPropertyName("telefono")]
    public string? Telefono { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid? CondominioId { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("debe_cambiar_password")]
    public bool DebeCambiarPassword { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
