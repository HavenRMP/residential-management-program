using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Condominios.Api.DTOs;

public class RedimirCodigoRequestDto
{
    [Required]
    [JsonPropertyName("codigo")]
    public string Codigo { get; set; } = string.Empty;
}
