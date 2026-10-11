using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class NotificacionPushPendienteDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("usuario_id")]
    public Guid UsuarioId { get; set; }

    [JsonPropertyName("tipo_evento")]
    public string TipoEvento { get; set; } = string.Empty;

    [JsonPropertyName("titulo")]
    public string Titulo { get; set; } = string.Empty;

    [JsonPropertyName("mensaje")]
    public string Mensaje { get; set; } = string.Empty;

    [JsonPropertyName("url_redireccion")]
    public string? UrlRedireccion { get; set; }

    [JsonPropertyName("reserva_id")]
    public Guid? ReservaId { get; set; }
}
