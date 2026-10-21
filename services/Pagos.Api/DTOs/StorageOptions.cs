namespace Pagos.Api.DTOs;

/// <summary>
/// Opciones de configuración para el almacenamiento en Supabase Storage.
/// </summary>
public class StorageOptions
{
    public const string SectionName = "Storage";

    /// <summary>
    /// Nombre del bucket privado donde se almacenan los comprobantes (default: comprobantes).
    /// </summary>
    public string BucketComprobantes { get; set; } = "comprobantes";

    /// <summary>
    /// Tiempo de expiración por defecto en segundos para las URLs firmadas (default: 300 segundos).
    /// </summary>
    public int UrlExpiracionSegundos { get; set; } = 300;

    /// <summary>
    /// Tiempo máximo permitido de expiración en segundos para las URLs firmadas (default: 3600 segundos).
    /// </summary>
    public int MaxExpiracionSegundos { get; set; } = 3600;
}
