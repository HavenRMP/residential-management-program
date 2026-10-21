namespace Pagos.Api.Services;

/// <summary>
/// Contrato para el almacenamiento y gestión de comprobantes en Supabase Storage REST.
/// </summary>
public interface IComprobanteStorageService
{
    /// <summary>
    /// Sube un archivo de comprobante al bucket privado 'comprobantes' usando la service role key.
    /// NO sobrescribe si ya existe (genera error de conflicto).
    /// </summary>
    /// <param name="bytes">Contenido del archivo en bytes.</param>
    /// <param name="contentType">Tipo MIME del archivo (image/jpeg, image/png o application/pdf).</param>
    /// <param name="rutaObjeto">Ruta dentro del bucket.</param>
    /// <param name="cancellationToken">Token de cancelación.</param>
    /// <returns>La ruta relativa del objeto guardado en el bucket.</returns>
    Task<string> SubirAsync(byte[] bytes, string contentType, string rutaObjeto, CancellationToken cancellationToken = default);

    /// <summary>
    /// Genera una URL firmada de acceso temporal al comprobante.
    /// </summary>
    /// <param name="rutaObjeto">Ruta relativa del objeto en el bucket.</param>
    /// <param name="expiracionSegundos">Segundos de validez de la URL firmada (máximo 3600; por defecto 300 o configurable).</param>
    /// <param name="cancellationToken">Token de cancelación.</param>
    /// <returns>La URL firmada completa generada bajo demanda.</returns>
    Task<string> CrearUrlFirmadaAsync(string rutaObjeto, int? expiracionSegundos = null, CancellationToken cancellationToken = default);

    /// <summary>
    /// Elimina un archivo de comprobante del bucket (para uso interno o futuro).
    /// </summary>
    /// <param name="rutaObjeto">Ruta relativa del objeto en el bucket.</param>
    /// <param name="cancellationToken">Token de cancelación.</param>
    Task EliminarAsync(string rutaObjeto, CancellationToken cancellationToken = default);
}
