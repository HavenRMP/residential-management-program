using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Solicitud para cancelar un cargo residencial existente.
/// </summary>
public class CancelarCargoRequest
{
    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;
}
