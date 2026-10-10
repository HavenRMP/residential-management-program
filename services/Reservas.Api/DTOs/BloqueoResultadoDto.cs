using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class BloqueoResultadoDto
{
    [JsonPropertyName("bloqueo_id")]
    public Guid BloqueoId { get; set; }

    [JsonPropertyName("area_id")]
    public Guid AreaId { get; set; }

    [JsonPropertyName("inicio")]
    public DateTimeOffset Inicio { get; set; }

    [JsonPropertyName("fin")]
    public DateTimeOffset Fin { get; set; }

    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;

    [JsonPropertyName("reservas_afectadas")]
    public int ReservasAfectadas { get; set; }
}
