using System.Security.Cryptography;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Pagos.Api.DTOs;
using SkiaSharp;

namespace Pagos.Api.Services;

/// <summary>
/// Servicio para validar y procesar archivos de comprobantes de pago en memoria, sin operaciones de red.
/// </summary>
public class ComprobanteProcessor : IComprobanteProcessor
{
    private readonly ComprobanteOptions _options;
    private readonly ILogger<ComprobanteProcessor> _logger;

    private enum TipoArchivoPermitido
    {
        Jpeg,
        Png,
        Pdf
    }

    public ComprobanteProcessor(
        IOptions<ComprobanteOptions> options,
        ILogger<ComprobanteProcessor> logger)
    {
        _options = options?.Value ?? new ComprobanteOptions();
        _logger = logger;
    }

    public async Task<ComprobanteProcesadoResult> ProcesarAsync(
        Stream stream,
        string? nombreOriginal,
        CancellationToken cancellationToken = default)
    {
        ArgumentNullException.ThrowIfNull(stream);

        using var memoryStream = new MemoryStream();
        await stream.CopyToAsync(memoryStream, cancellationToken);
        var bytesOriginales = memoryStream.ToArray();

        return Procesar(bytesOriginales, nombreOriginal);
    }

    public ComprobanteProcesadoResult Procesar(byte[] bytesOriginales, string? nombreOriginal)
    {
        if (bytesOriginales == null || bytesOriginales.Length == 0)
        {
            throw new ArgumentException("El archivo de comprobante está vacío o no fue proporcionado.", nameof(bytesOriginales));
        }

        // Regla 2: Tamaño máximo de entrada (5 MB configurable)
        if (bytesOriginales.Length > _options.MaxInputSizeBytes)
        {
            var limiteMb = _options.MaxInputSizeBytes / (1024 * 1024);
            throw new ArgumentException($"El archivo supera el tamaño máximo permitido de {limiteMb} MB.");
        }

        // Regla 3: Hash SHA-256 del contenido ORIGINAL recibido (antes de comprimir), hexadecimal minúsculas, 64 chars
        using var sha256 = SHA256.Create();
        var hashBytes = sha256.ComputeHash(bytesOriginales);
        var hashOriginal = Convert.ToHexString(hashBytes).ToLowerInvariant();

        // Regla 1: Validar tipos permitidos por CONTENIDO (magic bytes)
        var tipo = DetectarTipoPorContenido(bytesOriginales);

        // Regla 5: PDF no se modifica; si pesa más de 1 MB => rechazo con mensaje claro
        if (tipo == TipoArchivoPermitido.Pdf)
        {
            if (bytesOriginales.Length > _options.MaxPdfSizeBytes)
            {
                var limitePdfMb = (double)_options.MaxPdfSizeBytes / (1024 * 1024);
                throw new ArgumentException($"El archivo PDF supera el tamaño máximo permitido de {limitePdfMb:0.##} MB para comprobantes.");
            }

            return new ComprobanteProcesadoResult
            {
                BytesFinales = bytesOriginales,
                ContentTypeFinal = "application/pdf",
                ExtensionFinal = ".pdf",
                HashOriginal = hashOriginal,
                TamanoFinal = bytesOriginales.Length
            };
        }

        // Regla 4: Procesamiento de imágenes (JPEG o PNG)
        return ProcesarImagen(bytesOriginales, tipo, hashOriginal);
    }

    private static TipoArchivoPermitido DetectarTipoPorContenido(byte[] bytes)
    {
        if (bytes.Length < 4)
        {
            throw new ArgumentException("El archivo proporcionado está incompleto o corrupto.");
        }

        // JPEG: FF D8 FF
        if (bytes.Length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF)
        {
            return TipoArchivoPermitido.Jpeg;
        }

        // PNG: 89 50 4E 47 0D 0A 1A 0A
        if (bytes.Length >= 8 &&
            bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47 &&
            bytes[4] == 0x0D && bytes[5] == 0x0A && bytes[6] == 0x1A && bytes[7] == 0x0A)
        {
            return TipoArchivoPermitido.Png;
        }

        // PDF: %PDF (25 50 44 46)
        if (bytes.Length >= 4 &&
            bytes[0] == 0x25 && bytes[1] == 0x50 && bytes[2] == 0x44 && bytes[3] == 0x46)
        {
            return TipoArchivoPermitido.Pdf;
        }

        throw new ArgumentException("Formato de archivo no permitido. Solo se aceptan comprobantes en formato JPG, PNG o PDF.");
    }

    private ComprobanteProcesadoResult ProcesarImagen(
        byte[] bytesOriginales,
        TipoArchivoPermitido tipo,
        string hashOriginal)
    {
        using var inputStream = new SKMemoryStream(bytesOriginales);
        using var codec = SKCodec.Create(inputStream);
        if (codec == null)
        {
            throw new ArgumentException("El contenido del archivo no corresponde a una imagen válida o está corrupto.");
        }

        var origin = codec.EncodedOrigin;
        using var originalBitmap = SKBitmap.Decode(codec);
        if (originalBitmap == null)
        {
            throw new ArgumentException("No fue posible decodificar la imagen del comprobante.");
        }

        // Aplicar rotación según EXIF
        var orientedBitmap = AutoOrient(originalBitmap, origin);
        bool orientedWasAllocated = !ReferenceEquals(orientedBitmap, originalBitmap);

        // Redimensionar para que el lado mayor no pase de 1600 px (configurable)
        var finalBitmap = orientedBitmap;
        bool resizedWasAllocated = false;

        int maxDimension = _options.MaxDimensionPixels;
        if (orientedBitmap.Width > maxDimension || orientedBitmap.Height > maxDimension)
        {
            float ratio = Math.Min(
                (float)maxDimension / orientedBitmap.Width,
                (float)maxDimension / orientedBitmap.Height);

            int newWidth = Math.Max(1, (int)Math.Round(orientedBitmap.Width * ratio));
            int newHeight = Math.Max(1, (int)Math.Round(orientedBitmap.Height * ratio));

            var info = new SKImageInfo(newWidth, newHeight, orientedBitmap.ColorType, orientedBitmap.AlphaType);
            var resized = orientedBitmap.Resize(info, SKSamplingOptions.Default);
            if (resized != null)
            {
                finalBitmap = resized;
                resizedWasAllocated = true;
            }
        }

        try
        {
            bool esPng = (tipo == TipoArchivoPermitido.Png);
            bool tieneTransparencia = esPng && TieneTransparencia(finalBitmap);

            byte[] bytesFinales;
            string contentTypeFinal;
            string extensionFinal;

            if (tieneTransparencia)
            {
                // Regla 4: png solo si hace falta transparencia (sin metadatos EXIF)
                using var image = SKImage.FromBitmap(finalBitmap);
                using var data = image.Encode(SKEncodedImageFormat.Png, 100);
                bytesFinales = data.ToArray();
                contentTypeFinal = "image/png";
                extensionFinal = ".png";
            }
            else
            {
                // Regla 4: Salida en jpg para fotos o PNGs sin transparencia
                // Recomprimir hasta quedar idealmente <= 200 KB (calidad decreciente con piso mínimo razonable)
                using var image = SKImage.FromBitmap(finalBitmap);

                int[] calidades = [85, 75, 65, 55, 45];
                byte[]? mejorBuffer = null;

                foreach (var calidad in calidades)
                {
                    using var data = image.Encode(SKEncodedImageFormat.Jpeg, calidad);
                    var candidate = data.ToArray();
                    mejorBuffer = candidate;

                    if (candidate.Length <= _options.TargetImageSizeBytes)
                    {
                        break;
                    }
                }

                bytesFinales = mejorBuffer ?? Array.Empty<byte>();
                contentTypeFinal = "image/jpeg";
                extensionFinal = ".jpg";
            }

            return new ComprobanteProcesadoResult
            {
                BytesFinales = bytesFinales,
                ContentTypeFinal = contentTypeFinal,
                ExtensionFinal = extensionFinal,
                HashOriginal = hashOriginal,
                TamanoFinal = bytesFinales.Length
            };
        }
        finally
        {
            if (resizedWasAllocated)
            {
                finalBitmap.Dispose();
            }
            if (orientedWasAllocated)
            {
                orientedBitmap.Dispose();
            }
        }
    }

    private static SKBitmap AutoOrient(SKBitmap bitmap, SKEncodedOrigin origin)
    {
        if (origin == SKEncodedOrigin.TopLeft || origin == SKEncodedOrigin.Default)
        {
            return bitmap;
        }

        SKBitmap rotated;
        switch (origin)
        {
            case SKEncodedOrigin.BottomRight: // 180 grados
                rotated = new SKBitmap(bitmap.Width, bitmap.Height, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.RotateDegrees(180, bitmap.Width / 2f, bitmap.Height / 2f);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.RightTop: // 90 grados CW (rotar a la derecha)
                rotated = new SKBitmap(bitmap.Height, bitmap.Width, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Translate(bitmap.Height, 0);
                    canvas.RotateDegrees(90);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.LeftBottom: // 270 grados CW (rotar a la izquierda)
                rotated = new SKBitmap(bitmap.Height, bitmap.Width, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Translate(0, bitmap.Width);
                    canvas.RotateDegrees(270);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.TopRight: // Reflejo horizontal
                rotated = new SKBitmap(bitmap.Width, bitmap.Height, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Scale(-1, 1, bitmap.Width / 2f, 0);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.BottomLeft: // Reflejo vertical
                rotated = new SKBitmap(bitmap.Width, bitmap.Height, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Scale(1, -1, 0, bitmap.Height / 2f);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.LeftTop: // Transponer
                rotated = new SKBitmap(bitmap.Height, bitmap.Width, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Translate(bitmap.Height, 0);
                    canvas.RotateDegrees(90);
                    canvas.Scale(1, -1, 0, bitmap.Height / 2f);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            case SKEncodedOrigin.RightBottom: // Transponer inversa
                rotated = new SKBitmap(bitmap.Height, bitmap.Width, bitmap.ColorType, bitmap.AlphaType);
                using (var canvas = new SKCanvas(rotated))
                {
                    canvas.Translate(0, bitmap.Width);
                    canvas.RotateDegrees(270);
                    canvas.Scale(1, -1, 0, bitmap.Width / 2f);
                    canvas.DrawBitmap(bitmap, 0, 0, SKSamplingOptions.Default);
                }
                return rotated;

            default:
                return bitmap;
        }
    }

    private static bool TieneTransparencia(SKBitmap bitmap)
    {
        if (bitmap.AlphaType == SKAlphaType.Opaque)
        {
            return false;
        }

        int width = bitmap.Width;
        int height = bitmap.Height;

        for (int y = 0; y < height; y++)
        {
            for (int x = 0; x < width; x++)
            {
                if (bitmap.GetPixel(x, y).Alpha < 255)
                {
                    return true;
                }
            }
        }

        return false;
    }
}
