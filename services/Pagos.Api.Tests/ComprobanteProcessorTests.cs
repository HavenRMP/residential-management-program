using System.Security.Cryptography;
using System.Text;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Pagos.Api.DTOs;
using Pagos.Api.Services;
using SkiaSharp;
using Xunit;

namespace Pagos.Api.Tests;

public class ComprobanteProcessorTests
{
    private readonly ComprobanteProcessor _processor;
    private readonly ComprobanteOptions _options;

    public ComprobanteProcessorTests()
    {
        _options = new ComprobanteOptions
        {
            MaxInputSizeBytes = 5 * 1024 * 1024,
            MaxPdfSizeBytes = 1 * 1024 * 1024,
            TargetImageSizeBytes = 200 * 1024,
            MaxDimensionPixels = 1600
        };

        var optionsWrapper = Options.Create(_options);
        _processor = new ComprobanteProcessor(optionsWrapper, NullLogger<ComprobanteProcessor>.Instance);
    }

    /// <summary>
    /// Caso 1: JPG válido => acepta, devuelve hash de 64 caracteres y tamaño final.
    /// </summary>
    [Fact]
    public void Procesar_JpgValido_AceptaYDevuelveHash64YTamanoFinal()
    {
        using var bitmap = new SKBitmap(400, 300);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.Blue);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, 90);
        var bytesJpeg = data.ToArray();

        using var sha256 = SHA256.Create();
        var hashEsperado = Convert.ToHexString(sha256.ComputeHash(bytesJpeg)).ToLowerInvariant();

        var result = _processor.Procesar(bytesJpeg, "pago.jpg");

        Assert.NotNull(result);
        Assert.Equal("image/jpeg", result.ContentTypeFinal);
        Assert.Equal(".jpg", result.ExtensionFinal);
        Assert.Equal(64, result.HashOriginal.Length);
        Assert.Matches("^[a-f0-9]{64}$", result.HashOriginal);
        Assert.Equal(hashEsperado, result.HashOriginal);
        Assert.True(result.TamanoFinal > 0);
        Assert.Equal(result.BytesFinales.Length, result.TamanoFinal);
        Assert.Equal(0xFF, result.BytesFinales[0]);
        Assert.Equal(0xD8, result.BytesFinales[1]);
        Assert.Equal(0xFF, result.BytesFinales[2]);
    }

    /// <summary>
    /// Caso 2: PNG válido => acepta.
    /// </summary>
    [Fact]
    public void Procesar_PngValido_Acepta()
    {
        using var bitmap = new SKBitmap(200, 200);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.IndianRed);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        var bytesPng = data.ToArray();

        var result = _processor.Procesar(bytesPng, "recibo.png");

        Assert.NotNull(result);
        Assert.Equal(64, result.HashOriginal.Length);
        Assert.Matches("^[a-f0-9]{64}$", result.HashOriginal);
        Assert.True(result.TamanoFinal > 0);
        Assert.True(result.ContentTypeFinal == "image/jpeg" || result.ContentTypeFinal == "image/png");
    }

    /// <summary>
    /// Caso 3: PDF válido de menos de 1 MB => acepta sin modificar bytes.
    /// </summary>
    [Fact]
    public void Procesar_PdfValidoMenorA1MB_AceptaSinModificarBytes()
    {
        var contenidoPdf = "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF";
        var bytes = Encoding.UTF8.GetBytes(contenidoPdf);

        using var sha256 = SHA256.Create();
        var hashEsperado = Convert.ToHexString(sha256.ComputeHash(bytes)).ToLowerInvariant();

        var result = _processor.Procesar(bytes, "comprobante.pdf");

        Assert.NotNull(result);
        Assert.Equal("application/pdf", result.ContentTypeFinal);
        Assert.Equal(".pdf", result.ExtensionFinal);
        Assert.Equal(bytes.Length, result.TamanoFinal);
        Assert.Equal(64, result.HashOriginal.Length);
        Assert.Equal(hashEsperado, result.HashOriginal);
        Assert.Equal(bytes, result.BytesFinales);
    }

    /// <summary>
    /// Caso 4: PDF de más de 1 MB => rechaza.
    /// </summary>
    [Fact]
    public void Procesar_PdfMayorA1MB_Rechaza()
    {
        // 1.1 MB con cabecera de PDF
        var bytes = new byte[1153433];
        bytes[0] = 0x25; // %
        bytes[1] = 0x50; // P
        bytes[2] = 0x44; // D
        bytes[3] = 0x46; // F

        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "pesado.pdf"));
        Assert.Contains("PDF supera el tamaño máximo permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 5: Archivo con extensión .jpg pero contenido de otro tipo => rechaza.
    /// </summary>
    [Fact]
    public void Procesar_ExtensionJpgContenidoDeOtroTipo_Rechaza()
    {
        var bytesTexto = Encoding.UTF8.GetBytes("Esto es un texto plano fingiendo ser JPG.");
        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytesTexto, "foto_falsa.jpg"));
        Assert.Contains("no permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 6: Archivo mayor al máximo de entrada => rechaza.
    /// </summary>
    [Fact]
    public void Procesar_ArchivoMayorAlMaximoDeEntrada_Rechaza()
    {
        // 5 MB + 1 byte
        var bytes = new byte[_options.MaxInputSizeBytes + 1];
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;

        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "enorme.jpg"));
        Assert.Contains("supera el tamaño máximo permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 7: Mismo contenido dos veces => mismo hash.
    /// </summary>
    [Fact]
    public void Procesar_MismoContenidoDosVeces_MismoHash()
    {
        using var bitmap = new SKBitmap(300, 200);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.Goldenrod);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, 85);
        var bytes = data.ToArray();

        var res1 = _processor.Procesar(bytes, "intento1.jpg");
        var res2 = _processor.Procesar(bytes, "intento2.jpg");

        Assert.NotNull(res1);
        Assert.NotNull(res2);
        Assert.Equal(64, res1.HashOriginal.Length);
        Assert.Equal(res1.HashOriginal, res2.HashOriginal);
    }

    /// <summary>
    /// Caso 8: Imagen grande => la salida es menor o igual a su entrada y el lado mayor no pasa de 1600 px.
    /// </summary>
    [Fact]
    public void Procesar_ImagenGrande_SalidaMenorOIgualAEntradaYLadoMayorNoPasaDe1600()
    {
        // Crear imagen 2200 x 1400 px con detalles para que tenga peso real
        using var bitmap = new SKBitmap(2200, 1400);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.DarkSlateBlue);
        using var paint = new SKPaint { Color = SKColors.Orange, StrokeWidth = 5 };
        for (int i = 0; i < 2200; i += 50)
        {
            canvas.DrawLine(i, 0, i, 1400, paint);
        }

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, 100);
        var bytesGigante = data.ToArray();

        var result = _processor.Procesar(bytesGigante, "foto_grande.jpg");

        Assert.NotNull(result);
        Assert.True(result.TamanoFinal <= bytesGigante.Length, "El tamaño procesado debe ser menor o igual al tamaño de entrada.");

        // Decodificar el resultado para verificar dimensiones
        using var resultStream = new SKMemoryStream(result.BytesFinales);
        using var resultBitmap = SKBitmap.Decode(resultStream);

        Assert.NotNull(resultBitmap);
        Assert.True(resultBitmap.Width <= 1600, $"El ancho ({resultBitmap.Width}) debe ser <= 1600 px");
        Assert.True(resultBitmap.Height <= 1600, $"El alto ({resultBitmap.Height}) debe ser <= 1600 px");
        Assert.Equal(1600, Math.Max(resultBitmap.Width, resultBitmap.Height));
    }

    [Fact]
    public void Procesar_ArchivoVacio_LanzaArgumentException()
    {
        var bytes = Array.Empty<byte>();
        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "vacio.jpg"));
        Assert.Contains("vacío", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ProcesarAsync_StreamNulo_LanzaArgumentNullException()
    {
        await Assert.ThrowsAsync<ArgumentNullException>(() => _processor.ProcesarAsync(null!, "test.jpg"));
    }

    [Fact]
    public void Procesar_PngConTransparencia_ConservaFormatoPng()
    {
        using var bitmap = new SKBitmap(200, 200, SKColorType.Rgba8888, SKAlphaType.Premul);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.Transparent);
        using var paint = new SKPaint { Color = SKColors.Green };
        canvas.DrawCircle(100, 100, 50, paint);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        var bytesPngTransparente = data.ToArray();

        var result = _processor.Procesar(bytesPngTransparente, "icono_transparente.png");

        Assert.NotNull(result);
        Assert.Equal("image/png", result.ContentTypeFinal);
        Assert.Equal(".png", result.ExtensionFinal);
        Assert.Equal(0x89, result.BytesFinales[0]);
        Assert.Equal(0x50, result.BytesFinales[1]);
        Assert.Equal(0x4E, result.BytesFinales[2]);
        Assert.Equal(0x47, result.BytesFinales[3]);
    }

    [Fact]
    public async Task ProcesarAsync_StreamValido_RetornaMismoResultadoQueSincrono()
    {
        using var bitmap = new SKBitmap(100, 100);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.Yellow);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, 80);
        var bytes = data.ToArray();

        using var stream = new MemoryStream(bytes);
        var resultAsync = await _processor.ProcesarAsync(stream, "test.jpg");

        Assert.NotNull(resultAsync);
        Assert.Equal("image/jpeg", resultAsync.ContentTypeFinal);
        Assert.Equal(".jpg", resultAsync.ExtensionFinal);
        Assert.True(resultAsync.TamanoFinal > 0);
    }
}
