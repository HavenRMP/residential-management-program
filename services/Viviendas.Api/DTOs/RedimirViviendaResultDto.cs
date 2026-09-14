using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class RedimirViviendaResultDto
{
    [JsonPropertyName("vivienda")]
    public ViviendaDto Vivienda { get; set; } = new();

    [JsonPropertyName("residente")]
    public ResidenteResumenDto Residente { get; set; } = new();
}
