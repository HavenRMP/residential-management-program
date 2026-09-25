using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class NotificacionDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("usuario_id")]
    public Guid UsuarioId { get; set; }

    [JsonPropertyName("usuario_nombre")]
    public string UsuarioNombre { get; set; } = string.Empty;

    [JsonPropertyName("usuario_email")]
    public string UsuarioEmail { get; set; } = string.Empty;

    [JsonPropertyName("tipo_evento")]
    public string TipoEvento { get; set; } = string.Empty;

    [JsonPropertyName("titulo")]
    public string Titulo { get; set; } = string.Empty;

    [JsonPropertyName("mensaje")]
    public string Mensaje { get; set; } = string.Empty;

    [JsonPropertyName("url_redireccion")]
    public string? UrlRedireccion { get; set; }

    [JsonPropertyName("leida")]
    public bool Leida { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
