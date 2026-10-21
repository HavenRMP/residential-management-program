using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de respuesta que contiene una URL firmada de acceso temporal al comprobante de un pago.
/// </summary>
public class ComprobanteUrlResponse
{
    /// <summary>
    /// URL firmada temporal para visualizar o descargar el comprobante.
    /// </summary>
    [JsonPropertyName("url")]
    public string Url { get; set; } = string.Empty;

    /// <summary>
    /// Fecha y hora UTC en la que expira la validez de la URL firmada.
    /// </summary>
    [JsonPropertyName("expira_en")]
    public DateTimeOffset ExpiraEn { get; set; }
}
