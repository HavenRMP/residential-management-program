using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta detallada de un cargo residencial que incluye la lista de sus pagos asociados.
/// </summary>
public class CargoDetalleResponse : CargoResponse
{
    [JsonPropertyName("pagos")]
    public List<PagoResumenResponse> Pagos { get; set; } = new();
}
