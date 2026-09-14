using System.Text.Json.Serialization;

namespace Condominios.Api.DTOs;

public class GenerarCodigoRequestDto
{
    [JsonPropertyName("minutosVigencia")]
    public int? MinutosVigencia { get; set; }
}
