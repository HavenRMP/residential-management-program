using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class RedimirCodigoRequestDto
{
    [Required]
    [JsonPropertyName("codigo")]
    public string Codigo { get; set; } = string.Empty;
}
