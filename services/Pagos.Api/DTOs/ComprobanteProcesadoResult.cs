namespace Pagos.Api.DTOs;

/// <summary>
/// Resultado del procesamiento y validación de un archivo de comprobante de pago.
/// </summary>
public class ComprobanteProcesadoResult
{
    /// <summary>
    /// Flujo de bytes finales tras la validación o compresión.
    /// </summary>
    public byte[] BytesFinales { get; init; } = Array.Empty<byte>();

    /// <summary>
    /// Tipo MIME final resultante (image/jpeg, image/png o application/pdf).
    /// </summary>
    public string ContentTypeFinal { get; init; } = string.Empty;

    /// <summary>
    /// Extensión de archivo correspondiente (.jpg, .png o .pdf).
    /// </summary>
    public string ExtensionFinal { get; init; } = string.Empty;

    /// <summary>
    /// Hash SHA-256 del contenido ORIGINAL recibido (64 caracteres hexadecimales en minúsculas).
    /// </summary>
    public string HashOriginal { get; init; } = string.Empty;

    /// <summary>
    /// Tamaño final del archivo procesado en bytes.
    /// </summary>
    public long TamanoFinal { get; init; }
}
