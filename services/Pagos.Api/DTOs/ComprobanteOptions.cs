namespace Pagos.Api.DTOs;

/// <summary>
/// Opciones de configuración para la validación y procesamiento de comprobantes.
/// </summary>
public class ComprobanteOptions
{
    public const string SectionName = "Comprobantes";

    /// <summary>
    /// Tamaño máximo de entrada en bytes (default: 5 MB). Tope permitido por el bucket.
    /// </summary>
    public long MaxInputSizeBytes { get; set; } = 5 * 1024 * 1024;

    /// <summary>
    /// Tamaño máximo permitido para documentos PDF en bytes (default: 1 MB).
    /// </summary>
    public long MaxPdfSizeBytes { get; set; } = 1 * 1024 * 1024;

    /// <summary>
    /// Tamaño objetivo de la imagen comprimida en bytes (default: 200 KB).
    /// </summary>
    public long TargetImageSizeBytes { get; set; } = 200 * 1024;

    /// <summary>
    /// Dimensión máxima en píxeles para el lado mayor de la imagen (default: 1600 px).
    /// </summary>
    public int MaxDimensionPixels { get; set; } = 1600;
}
