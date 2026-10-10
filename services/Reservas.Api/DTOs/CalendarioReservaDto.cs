using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class CalendarioReservaDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("area_id")]
    public Guid AreaId { get; set; }

    [JsonPropertyName("area_nombre")]
    public string AreaNombre { get; set; } = string.Empty;

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("inicio")]
    public DateTimeOffset Inicio { get; set; }

    [JsonPropertyName("fin")]
    public DateTimeOffset Fin { get; set; }

    [JsonPropertyName("tipo")]
    public string Tipo { get; set; } = string.Empty;

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = string.Empty;

    [JsonPropertyName("titular_nombre")]
    public string? TitularNombre { get; set; }

    [JsonPropertyName("titular_apellidos")]
    public string? TitularApellidos { get; set; }

    [JsonPropertyName("numero_casa")]
    public string? NumeroCasa { get; set; }

    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }
}
