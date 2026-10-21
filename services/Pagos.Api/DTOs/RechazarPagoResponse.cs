using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta resultante del rechazo de un pago reportado.
/// </summary>
public class RechazarPagoResponse
{
    [JsonPropertyName("pago")]
    public PagoResponse Pago { get; set; } = null!;
}
