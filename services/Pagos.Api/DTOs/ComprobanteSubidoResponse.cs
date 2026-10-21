using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Respuesta devuelta tras la subida y procesamiento exitoso de un comprobante de pago.
/// </summary>
public class ComprobanteSubidoResponse
{
    /// <summary>
    /// Ruta relativa del comprobante en el bucket de almacenamiento.
    /// </summary>
    [JsonPropertyName("ruta")]
    public string Ruta { get; init; } = string.Empty;

    /// <summary>
    /// Hash SHA-256 del archivo original en hexadecimal minúsculas.
    /// </summary>
    [JsonPropertyName("hash")]
    public string Hash { get; init; } = string.Empty;

    /// <summary>
    /// Tamaño final en bytes del archivo procesado.
    /// </summary>
    [JsonPropertyName("tamano_bytes")]
    public long TamanoBytes { get; init; }

    /// <summary>
    /// Tipo MIME final resultante (image/jpeg, image/png o application/pdf).
    /// </summary>
    [JsonPropertyName("content_type")]
    public string ContentType { get; init; } = string.Empty;
}
