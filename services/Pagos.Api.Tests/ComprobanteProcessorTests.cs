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
    public void Procesar_ArchivoSuperaTamanoMaximoEntrada_LanzaArgumentException()
    {
        // 5 MB + 1 byte
        var bytes = new byte[_options.MaxInputSizeBytes + 1];
        // Forzar magic bytes de JPEG
        bytes[0] = 0xFF;
        bytes[1] = 0xD8;
        bytes[2] = 0xFF;

        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "grande.jpg"));
        Assert.Contains("supera el tamaño máximo permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Procesar_ContenidoNoPermitido_LanzaArgumentException()
    {
        // Archivo de texto plano con extensión engañosa .jpg
        var bytes = Encoding.UTF8.GetBytes("Esto no es una imagen ni un pdf");
        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "fake.jpg"));
        Assert.Contains("no permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Procesar_PdfValidoMenorA1MB_RetornaPdfSinModificar()
    {
        // PDF válido simulado (comienza con %PDF)
        var contenidoPdf = "%PDF-1.4\n1 0 obj\n<<>>\nendobj\ntrailer\n<<>>\n%%EOF";
        var bytes = Encoding.UTF8.GetBytes(contenidoPdf);

        using var sha256 = SHA256.Create();
        var hashEsperado = Convert.ToHexString(sha256.ComputeHash(bytes)).ToLowerInvariant();

        var result = _processor.Procesar(bytes, "comprobante.pdf");

        Assert.NotNull(result);
        Assert.Equal("application/pdf", result.ContentTypeFinal);
        Assert.Equal(".pdf", result.ExtensionFinal);
        Assert.Equal(bytes.Length, result.TamanoFinal);
        Assert.Equal(hashEsperado, result.HashOriginal);
        Assert.Equal(bytes, result.BytesFinales);
    }

    [Fact]
    public void Procesar_PdfMayorA1MB_LanzaArgumentException()
    {
        // PDF de 1.1 MB
        var bytes = new byte[1153433];
        bytes[0] = 0x25; // %
        bytes[1] = 0x50; // P
        bytes[2] = 0x44; // D
        bytes[3] = 0x46; // F

        var ex = Assert.Throws<ArgumentException>(() => _processor.Procesar(bytes, "pesado.pdf"));
        Assert.Contains("PDF supera el tamaño máximo permitido", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public void Procesar_JpegValido_CalculaHashOriginalYProcesaAJpeg()
    {
        // Crear un JPEG real con SkiaSharp
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
        Assert.Equal(hashEsperado, result.HashOriginal);
        Assert.True(result.TamanoFinal > 0);
        Assert.Equal(result.BytesFinales.Length, result.TamanoFinal);

        // Validar que la salida sigue siendo un JPEG válido por magic bytes
        Assert.Equal(0xFF, result.BytesFinales[0]);
        Assert.Equal(0xD8, result.BytesFinales[1]);
        Assert.Equal(0xFF, result.BytesFinales[2]);
    }

    [Fact]
    public void Procesar_ImagenMayorA1600px_RedimensionaLadoMayorA1600()
    {
        // Imagen 2000 x 1000 px
        using var bitmap = new SKBitmap(2000, 1000);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.ForestGreen);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Jpeg, 80);
        var bytesGigante = data.ToArray();

        var result = _processor.Procesar(bytesGigante, "foto_gigante.jpg");

        // Decodificar el resultado para verificar dimensiones
        using var resultStream = new SKMemoryStream(result.BytesFinales);
        using var resultBitmap = SKBitmap.Decode(resultStream);

        Assert.NotNull(resultBitmap);
        Assert.Equal(1600, resultBitmap.Width);
        Assert.Equal(800, resultBitmap.Height);
    }

    [Fact]
    public void Procesar_PngSinTransparencia_ConvierteAJpeg()
    {
        // Crear un PNG completamente opaco
        using var bitmap = new SKBitmap(200, 200, SKColorType.Rgba8888, SKAlphaType.Opaque);
        using var canvas = new SKCanvas(bitmap);
        canvas.Clear(SKColors.DarkRed);

        using var image = SKImage.FromBitmap(bitmap);
        using var data = image.Encode(SKEncodedImageFormat.Png, 100);
        var bytesPng = data.ToArray();

        var result = _processor.Procesar(bytesPng, "opaco.png");

        Assert.NotNull(result);
        // Debe convertirse a JPG porque no requiere canal de transparencia
        Assert.Equal("image/jpeg", result.ContentTypeFinal);
        Assert.Equal(".jpg", result.ExtensionFinal);
        Assert.Equal(0xFF, result.BytesFinales[0]);
        Assert.Equal(0xD8, result.BytesFinales[1]);
        Assert.Equal(0xFF, result.BytesFinales[2]);
    }

    [Fact]
    public void Procesar_PngConTransparencia_ConservaFormatoPng()
    {
        // Crear un PNG con píxeles transparentes
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
        // Debe conservarse como PNG
        Assert.Equal("image/png", result.ContentTypeFinal);
        Assert.Equal(".png", result.ExtensionFinal);
        Assert.Equal(0x89, result.BytesFinales[0]);
        Assert.Equal(0x50, result.BytesFinales[1]); // P
        Assert.Equal(0x4E, result.BytesFinales[2]); // N
        Assert.Equal(0x47, result.BytesFinales[3]); // G
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
