using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class NotificacionDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("usuario_id")]
    public Guid UsuarioId { get; set; }

    [JsonPropertyName("titulo")]
    public string Titulo { get; set; } = string.Empty;

    [JsonPropertyName("mensaje")]
    public string Mensaje { get; set; } = string.Empty;

    [JsonPropertyName("tipo")]
    public string Tipo { get; set; } = string.Empty;

    [JsonPropertyName("leida")]
    public bool Leida { get; set; }

    [JsonPropertyName("referencia_id")]
    public Guid? ReferenciaId { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
