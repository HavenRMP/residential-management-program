using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class GenerarCodigoRequestDto
{
    [JsonPropertyName("minutosVigencia")]
    public int? MinutosVigencia { get; set; }
}
