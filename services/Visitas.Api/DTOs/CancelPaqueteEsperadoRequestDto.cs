using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class CancelPaqueteEsperadoRequestDto
{
    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }
}
