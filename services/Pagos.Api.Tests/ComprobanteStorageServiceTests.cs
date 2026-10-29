using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging.Abstractions;
using Microsoft.Extensions.Options;
using Moq;
using Moq.Protected;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;
using Pagos.Api.Utils;
using Xunit;

namespace Pagos.Api.Tests;

public class ComprobanteStorageServiceTests
{
    private readonly StorageOptions _options;
    private readonly IConfiguration _configuration;
    private const string BaseUrl = "https://mock.supabase.co";
    private const string ServiceRoleKey = "secret-service-role-key-12345";

    public ComprobanteStorageServiceTests()
    {
        _options = new StorageOptions
        {
            BucketComprobantes = "comprobantes",
            UrlExpiracionSegundos = 300,
            MaxExpiracionSegundos = 3600
        };

        var configData = new Dictionary<string, string?>
        {
            { "Supabase:Url", BaseUrl },
            { "Supabase:ServiceRoleKey", ServiceRoleKey }
        };

        _configuration = new ConfigurationBuilder()
            .AddInMemoryCollection(configData)
            .Build();
    }

    private ComprobanteStorageService CreateService(HttpMessageHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var optionsWrapper = Options.Create(_options);
        return new ComprobanteStorageService(httpClient, _configuration, optionsWrapper, NullLogger<ComprobanteStorageService>.Instance);
    }

    #region Pruebas de ComprobanteRutaHelper

    /// <summary>
    /// Caso 9: La ruta generada sigue condominio/vivienda/año/mes/guid.extensión y dos llamadas dan rutas distintas.
    /// </summary>
    [Fact]
    public void ConstruirRuta_SigueFormatoCondominioViviendaAnioMesGuidExtension_YDosLlamadasDanRutasDistintas()
    {
        var condominioId = Guid.NewGuid();
        var viviendaId = 101;
        var anio = 2026;
        var mes = 10;
        var ext = "JPG";

        var ruta1 = ComprobanteRutaHelper.ConstruirRuta(condominioId, viviendaId, anio, mes, ext);
        var ruta2 = ComprobanteRutaHelper.ConstruirRuta(condominioId, viviendaId, anio, mes, ext);

        var regex = @"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/101/2026/10/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\.jpg$";
        Assert.Matches(regex, ruta1);
        Assert.Matches(regex, ruta2);
        Assert.NotEqual(ruta1, ruta2);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(13)]
    public void ConstruirRuta_MesInvalido_LanzaArgumentOutOfRangeException(int mes)
    {
        Assert.Throws<ArgumentOutOfRangeException>(() =>
            ComprobanteRutaHelper.ConstruirRuta(Guid.NewGuid(), 1, 2026, mes, "jpg"));
    }

    /// <summary>
    /// Caso 10: Una ruta con .. o barra inicial se rechaza.
    /// </summary>
    [Theory]
    [InlineData("/comprobantes/foto.jpg")]
    [InlineData("/")]
    [InlineData("comprobantes/../secreto.jpg")]
    [InlineData("../secreto.jpg")]
    [InlineData("\\comprobantes\\foto.jpg")]
    [InlineData("condominio\\vivienda\\foto.jpg")]
    [InlineData("")]
    public void ValidarRuta_ConPuntosOBarraInicial_Rechaza(string rutaInvalida)
    {
        Assert.Throws<ArgumentException>(() => ComprobanteRutaHelper.ValidarRuta(rutaInvalida));
    }

    [Fact]
    public void ValidarRuta_RutaValida_NoLanzaExcepcion()
    {
        var ruta = $"{Guid.NewGuid()}/5/2026/11/{Guid.NewGuid()}.jpg";
        ComprobanteRutaHelper.ValidarRuta(ruta);
    }

    #endregion

    #region Pruebas de SubirAsync

    [Fact]
    public async Task SubirAsync_Exito_EnviaHeadersYNoSobrescribe()
    {
        var ruta = $"{Guid.NewGuid()}/1/2026/10/{Guid.NewGuid()}.jpg";
        var bytes = new byte[] { 0xFF, 0xD8, 0xFF, 0xE0 };

        HttpRequestMessage? requestCapturado = null;

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Callback<HttpRequestMessage, CancellationToken>((req, _) => requestCapturado = req)
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"Key\":\"comprobantes/" + ruta + "\"}")
            });

        var service = CreateService(mockHandler.Object);
        var resultado = await service.SubirAsync(bytes, "image/jpeg", ruta);

        Assert.Equal(ruta, resultado);
        Assert.NotNull(requestCapturado);
        Assert.Equal(HttpMethod.Post, requestCapturado.Method);
        Assert.Equal($"{BaseUrl}/storage/v1/object/comprobantes/{ruta}", requestCapturado.RequestUri?.ToString());

        // Verificar autenticación con Service Role Key
        Assert.Equal(ServiceRoleKey, requestCapturado.Headers.GetValues("apikey").FirstOrDefault());
        Assert.Equal($"Bearer {ServiceRoleKey}", requestCapturado.Headers.Authorization?.ToString());

        // Verificar que no sobrescribe
        Assert.Equal("false", requestCapturado.Headers.GetValues("x-upsert").FirstOrDefault());

        // Verificar Content-Type
        Assert.Equal("image/jpeg", requestCapturado.Content?.Headers.ContentType?.MediaType);
    }

    [Fact]
    public async Task SubirAsync_ConflictoSiYaExiste_LanzaPostgrestException409()
    {
        var ruta = $"{Guid.NewGuid()}/1/2026/10/{Guid.NewGuid()}.jpg";
        var bytes = new byte[] { 0xFF, 0xD8, 0xFF };

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.Conflict)
            {
                Content = new StringContent("{\"statusCode\":\"409\",\"error\":\"Duplicate\",\"message\":\"The resource already exists\"}")
            });

        var service = CreateService(mockHandler.Object);

        var ex = await Assert.ThrowsAsync<PostgrestException>(() =>
            service.SubirAsync(bytes, "image/jpeg", ruta));

        Assert.Equal(409, ex.StatusCode);
        Assert.Contains("ya existe", ex.MensajeUsuario, StringComparison.OrdinalIgnoreCase);
    }

    #endregion

    #region Pruebas de CrearUrlFirmadaAsync

    [Fact]
    public async Task CrearUrlFirmadaAsync_ObjetoExiste_DevuelveUrlFirmadaCompleta()
    {
        var ruta = $"{Guid.NewGuid()}/10/2026/10/{Guid.NewGuid()}.jpg";
        var signedRelativeUrl = $"/storage/v1/object/sign/comprobantes/{ruta}?token=expiring-temp-token-xyz";

        HttpRequestMessage? requestCapturado = null;

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Callback<HttpRequestMessage, CancellationToken>((req, _) => requestCapturado = req)
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { signedURL = signedRelativeUrl })
            });

        var service = CreateService(mockHandler.Object);
        var urlFirmada = await service.CrearUrlFirmadaAsync(ruta, 600);

        Assert.Equal($"{BaseUrl}{signedRelativeUrl}", urlFirmada);
        Assert.NotNull(requestCapturado);
        Assert.Equal(HttpMethod.Post, requestCapturado.Method);
        Assert.Equal($"{BaseUrl}/storage/v1/object/sign/comprobantes/{ruta}", requestCapturado.RequestUri?.ToString());

        // Verificar que la service role key NO se incluye en la URL final devuelta
        Assert.DoesNotContain(ServiceRoleKey, urlFirmada);
    }

    /// <summary>
    /// Formato real de Supabase: signedURL viene relativo a /storage/v1 ("/object/sign/...").
    /// La URL devuelta debe incluir el prefijo /storage/v1 para que funcione.
    /// </summary>
    [Fact]
    public async Task CrearUrlFirmadaAsync_SignedUrlSinPrefijoStorage_AgregaPrefijoStorageV1()
    {
        var ruta = $"{Guid.NewGuid()}/10/2026/10/{Guid.NewGuid()}.jpg";
        var signedRelativeUrl = $"/object/sign/comprobantes/{ruta}?token=expiring-temp-token-xyz";

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = JsonContent.Create(new { signedURL = signedRelativeUrl })
            });

        var service = CreateService(mockHandler.Object);
        var urlFirmada = await service.CrearUrlFirmadaAsync(ruta, 600);

        Assert.Equal($"{BaseUrl}/storage/v1{signedRelativeUrl}", urlFirmada);
    }

    [Fact]
    public async Task CrearUrlFirmadaAsync_ObjetoNoExiste_LanzaKeyNotFoundException()
    {
        var ruta = $"{Guid.NewGuid()}/10/2026/10/{Guid.NewGuid()}.jpg";

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.NotFound)
            {
                Content = new StringContent("{\"statusCode\":\"404\",\"error\":\"Not Found\",\"message\":\"Object not found\"}")
            });

        var service = CreateService(mockHandler.Object);

        var ex = await Assert.ThrowsAsync<KeyNotFoundException>(() =>
            service.CrearUrlFirmadaAsync(ruta));

        Assert.Contains("no fue encontrado", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    [InlineData(3601)]
    public async Task CrearUrlFirmadaAsync_ExpiracionInvalida_LanzaArgumentOutOfRangeException(int expiracion)
    {
        var ruta = $"{Guid.NewGuid()}/10/2026/10/{Guid.NewGuid()}.jpg";
        var mockHandler = new Mock<HttpMessageHandler>();
        var service = CreateService(mockHandler.Object);

        await Assert.ThrowsAsync<ArgumentOutOfRangeException>(() =>
            service.CrearUrlFirmadaAsync(ruta, expiracion));
    }

    #endregion

    #region Pruebas de EliminarAsync

    [Fact]
    public async Task EliminarAsync_Exito_EnviaDeleteConRutaCorrecta()
    {
        var ruta = $"{Guid.NewGuid()}/10/2026/10/{Guid.NewGuid()}.jpg";
        HttpRequestMessage? requestCapturado = null;

        var mockHandler = new Mock<HttpMessageHandler>();
        mockHandler.Protected()
            .Setup<Task<HttpResponseMessage>>(
                "SendAsync",
                ItExpr.IsAny<HttpRequestMessage>(),
                ItExpr.IsAny<CancellationToken>())
            .Callback<HttpRequestMessage, CancellationToken>((req, _) => requestCapturado = req)
            .ReturnsAsync(new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("{\"message\":\"Successfully deleted\"}")
            });

        var service = CreateService(mockHandler.Object);
        await service.EliminarAsync(ruta);

        Assert.NotNull(requestCapturado);
        Assert.Equal(HttpMethod.Delete, requestCapturado.Method);
        Assert.Equal($"{BaseUrl}/storage/v1/object/comprobantes/{ruta}", requestCapturado.RequestUri?.ToString());
    }

    #endregion
}
