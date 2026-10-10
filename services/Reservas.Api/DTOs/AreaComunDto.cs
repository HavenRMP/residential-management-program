using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class AreaComunDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("condominio_nombre")]
    public string CondominioNombre { get; set; } = string.Empty;

    [JsonPropertyName("zona_horaria")]
    public string ZonaHoraria { get; set; } = string.Empty;

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("descripcion")]
    public string? Descripcion { get; set; }

    [JsonPropertyName("hora_apertura")]
    public TimeOnly HoraApertura { get; set; }

    [JsonPropertyName("hora_cierre")]
    public TimeOnly HoraCierre { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
