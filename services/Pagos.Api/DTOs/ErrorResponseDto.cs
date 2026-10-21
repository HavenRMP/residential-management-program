using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Modelo de respuesta de error estándar para la API de Pagos, compatible con las convenciones de Haven.
/// </summary>
public class ErrorResponseDto
{
    [JsonPropertyName("error")]
    public string Error { get; set; } = string.Empty;

    [JsonPropertyName("detalles")]
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? Detalles { get; set; }

    public ErrorResponseDto() { }

    public ErrorResponseDto(string error, string? detalles = null)
    {
        Error = error;
        Detalles = detalles;
    }
}
