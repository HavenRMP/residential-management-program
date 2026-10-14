using System;
using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class SubusuarioResidencialDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("usuario_id")]
    public Guid UsuarioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("email")]
    public string Email { get; set; } = string.Empty;

    [JsonPropertyName("telefono")]
    public string? Telefono { get; set; }

    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;

    [JsonPropertyName("activo")]
    public bool Activo { get; set; } = true;
}
