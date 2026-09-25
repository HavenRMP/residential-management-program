using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class VwViviendaSubusuarioDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("usuario_id")]
    public Guid UsuarioId { get; set; }

    [JsonPropertyName("usuario_nombre")]
    public string UsuarioNombre { get; set; } = string.Empty;

    [JsonPropertyName("usuario_email")]
    public string UsuarioEmail { get; set; } = string.Empty;

    [JsonPropertyName("usuario_telefono")]
    public string UsuarioTelefono { get; set; } = string.Empty;

    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }
}
