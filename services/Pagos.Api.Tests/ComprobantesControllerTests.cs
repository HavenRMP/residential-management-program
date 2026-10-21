using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Pagos.Api.DTOs;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class ComprobantesControllerTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public ComprobantesControllerTests(PagosApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task SubirComprobante_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task SubirComprobante_ConRolSubusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task SubirComprobante_ArchivoFaltante_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("archivo", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task SubirComprobante_ArchivoVacio_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(Array.Empty<byte>()), "archivo", "vacio.jpg");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("archivo", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task SubirComprobante_ViviendaIdInvalido_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("0"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("vivienda", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task SubirComprobante_ArchivoMayorA5MB_Retorna413PayloadTooLarge()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        // 5 MB + 1 byte
        var largeBytes = new byte[5 * 1024 * 1024 + 1];
        content.Add(new ByteArrayContent(largeBytes), "archivo", "enorme.jpg");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("5 MB", err.Error);
    }

    [Fact]
    public async Task SubirComprobante_AdminViviendaNoPertenece_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(999, condominioId))
            .ReturnsAsync(false);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("999"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Vivienda no encontrada.", err.Error);
    }

    [Fact]
    public async Task SubirComprobante_InquilinoNoEsResidenteTitular_Retorna404NotFound()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(42, inquilinoId))
            .ReturnsAsync(false);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("42"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Vivienda no encontrada.", err.Error);
    }

    [Fact]
    public async Task SubirComprobante_ProcesadorRechazaArchivo_Retorna400BadRequestConMensaje()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(10, condominioId))
            .ReturnsAsync(true);

        var mockProcessor = new Mock<IComprobanteProcessor>();
        mockProcessor
            .Setup(p => p.ProcesarAsync(It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new ArgumentException("El archivo proporcionado no es un comprobante válido. Formatos soportados: JPG, PNG, PDF."));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descViviendas != null) services.Remove(descViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descProc = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteProcessor));
                if (descProc != null) services.Remove(descProc);
                services.AddSingleton(_ => mockProcessor.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "invalido.txt");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("El archivo proporcionado no es un comprobante válido. Formatos soportados: JPG, PNG, PDF.", err.Error);
    }

    [Fact]
    public async Task SubirComprobante_StorageFalla_Retorna502BadGatewayConMensajeGenerico()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(10, condominioId))
            .ReturnsAsync(true);

        var procesadoResult = new ComprobanteProcesadoResult
        {
            BytesFinales = new byte[] { 0xFF, 0xD8, 0xFF },
            ContentTypeFinal = "image/jpeg",
            ExtensionFinal = "jpg",
            HashOriginal = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
            TamanoFinal = 3
        };

        var mockProcessor = new Mock<IComprobanteProcessor>();
        mockProcessor
            .Setup(p => p.ProcesarAsync(It.IsAny<Stream>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(procesadoResult);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.SubirAsync(It.IsAny<byte[]>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new HttpRequestException("Connection refused to Supabase Storage endpoint. Sensitive key: 12345"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descViviendas != null) services.Remove(descViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descProc = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteProcessor));
                if (descProc != null) services.Remove(descProc);
                services.AddSingleton(_ => mockProcessor.Object);

                var descStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (descStorage != null) services.Remove(descStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("10"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Error al comunicar con el servicio de almacenamiento de comprobantes.", err.Error);
        Assert.DoesNotContain("Sensitive key", err.Error);
    }

    [Fact]
    public async Task SubirComprobante_AdminSubidaExitosa_Retorna201CreatedConDatos()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(15, condominioId))
            .ReturnsAsync(true);

        var expectedHash = "a591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146e";
        var procesadoResult = new ComprobanteProcesadoResult
        {
            BytesFinales = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 },
            ContentTypeFinal = "image/jpeg",
            ExtensionFinal = "jpg",
            HashOriginal = expectedHash,
            TamanoFinal = 4
        };

        var mockProcessor = new Mock<IComprobanteProcessor>();
        mockProcessor
            .Setup(p => p.ProcesarAsync(It.IsAny<Stream>(), "recibo.jpg", It.IsAny<CancellationToken>()))
            .ReturnsAsync(procesadoResult);

        string? rutaSubida = null;
        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.SubirAsync(It.IsAny<byte[]>(), "image/jpeg", It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .Callback<byte[], string, string, CancellationToken>((bytes, ct, ruta, token) => rutaSubida = ruta)
            .ReturnsAsync((byte[] _, string _, string ruta, CancellationToken _) => ruta);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descViviendas != null) services.Remove(descViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descProc = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteProcessor));
                if (descProc != null) services.Remove(descProc);
                services.AddSingleton(_ => mockProcessor.Object);

                var descStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (descStorage != null) services.Remove(descStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.jpg");
        content.Add(new StringContent("15"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<ComprobanteSubidoResponse>();
        Assert.NotNull(result);
        Assert.Equal(expectedHash, result.Hash);
        Assert.Equal(4, result.TamanoBytes);
        Assert.Equal("image/jpeg", result.ContentType);
        Assert.NotNull(rutaSubida);
        Assert.Equal(rutaSubida, result.Ruta);
        Assert.StartsWith($"{condominioId}/15/", result.Ruta);
        Assert.EndsWith(".jpg", result.Ruta);
    }

    [Fact]
    public async Task SubirComprobante_InquilinoSubidaExitosa_Retorna201CreatedConDatos()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(25, inquilinoId))
            .ReturnsAsync(true);

        var expectedHash = "b591a6d40bf420404a011733cfb7b190d62c65bf0bcda32b57b277d9ad9f146f";
        var procesadoResult = new ComprobanteProcesadoResult
        {
            BytesFinales = new byte[] { 0x25, 0x50, 0x44, 0x46 },
            ContentTypeFinal = "application/pdf",
            ExtensionFinal = "pdf",
            HashOriginal = expectedHash,
            TamanoFinal = 4
        };

        var mockProcessor = new Mock<IComprobanteProcessor>();
        mockProcessor
            .Setup(p => p.ProcesarAsync(It.IsAny<Stream>(), "recibo.pdf", It.IsAny<CancellationToken>()))
            .ReturnsAsync(procesadoResult);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.SubirAsync(It.IsAny<byte[]>(), "application/pdf", It.IsAny<string>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync((byte[] _, string _, string ruta, CancellationToken _) => ruta);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descViviendas != null) services.Remove(descViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descProc = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteProcessor));
                if (descProc != null) services.Remove(descProc);
                services.AddSingleton(_ => mockProcessor.Object);

                var descStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (descStorage != null) services.Remove(descStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        using var content = new MultipartFormDataContent();
        content.Add(new ByteArrayContent(new byte[] { 1, 2, 3 }), "archivo", "recibo.pdf");
        content.Add(new StringContent("25"), "vivienda_id");

        var response = await client.PostAsync("/api/comprobantes", content);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<ComprobanteSubidoResponse>();
        Assert.NotNull(result);
        Assert.Equal(expectedHash, result.Hash);
        Assert.Equal(4, result.TamanoBytes);
        Assert.Equal("application/pdf", result.ContentType);
        Assert.StartsWith($"{condominioId}/25/", result.Ruta);
        Assert.EndsWith(".pdf", result.Ruta);
    }
}
