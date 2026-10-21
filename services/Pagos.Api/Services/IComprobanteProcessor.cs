using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

/// <summary>
/// Contrato para la validación y procesamiento de archivos de comprobantes de pago.
/// </summary>
public interface IComprobanteProcessor
{
    /// <summary>
    /// Procesa de forma asíncrona un flujo de datos de comprobante de pago.
    /// </summary>
    /// <param name="stream">Flujo con el contenido del archivo recibido.</param>
    /// <param name="nombreOriginal">Nombre original del archivo proporcionado por el cliente.</param>
    /// <param name="cancellationToken">Token de cancelación.</param>
    /// <returns>Resultado con los bytes finales procesados, tipo MIME, extensión y hash SHA-256 original.</returns>
    Task<ComprobanteProcesadoResult> ProcesarAsync(Stream stream, string? nombreOriginal, CancellationToken cancellationToken = default);

    /// <summary>
    /// Procesa de forma síncrona un arreglo de bytes de comprobante de pago.
    /// </summary>
    /// <param name="bytesOriginales">Arreglo de bytes con el contenido original recibido.</param>
    /// <param name="nombreOriginal">Nombre original del archivo proporcionado por el cliente.</param>
    /// <returns>Resultado con los bytes finales procesados, tipo MIME, extensión y hash SHA-256 original.</returns>
    ComprobanteProcesadoResult Procesar(byte[] bytesOriginales, string? nombreOriginal);
}
