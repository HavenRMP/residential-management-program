using System.Text.Json.Serialization;

namespace Avisos.Api.DTOs;

public class AvisoDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("condominio_nombre")]
    public string? CondominioNombre { get; set; }

    [JsonPropertyName("titulo")]
    public string Titulo { get; set; } = string.Empty;

    [JsonPropertyName("contenido")]
    public string Contenido { get; set; } = string.Empty;

    [JsonPropertyName("duracion_dias")]
    public int? DuracionDias { get; set; }

    [JsonPropertyName("fecha_expiracion_manual")]
    public DateTimeOffset? FechaExpiracionManual { get; set; }

    [JsonPropertyName("fecha_publicacion")]
    public DateTime FechaPublicacion { get; set; }

    [JsonPropertyName("fecha_expiracion")]
    public DateTime FechaExpiracion { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid CreadoPor { get; set; }

    [JsonPropertyName("creado_por_nombre")]
    public string? CreadoPorNombre { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }

    [JsonPropertyName("estado")]
    public string? Estado { get; set; }
}
