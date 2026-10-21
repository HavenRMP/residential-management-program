using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class PagosDetalleYComprobanteUrlTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public PagosDetalleYComprobanteUrlTests(PagosApiFactory factory)
    {
        _factory = factory;
    }

    #region GET api/pagos/{id} - Detalle de Pago

    [Fact]
    public async Task ObtenerDetallePago_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var pagoId = Guid.NewGuid();

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerDetallePago_RolSubusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var pagoId = Guid.NewGuid();
        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerDetallePago_Admin_PagoSuCondominio_Retorna200OkConDetalleCompletoSinRutaNiHash()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CargoId = cargoId,
            CondominioId = condominioId,
            ViviendaId = 101,
            NumeroCasa = "Casa 101",
            CargoTipo = TipoCargo.Mantenimiento,
            CargoConcepto = "Mantenimiento Octubre",
            Monto = 1500m,
            MontoCubierto = 1500m,
            MontoExcedente = 0m,
            FechaPago = new DateOnly(2026, 10, 15),
            Metodo = MetodoPago.Transferencia,
            Referencia = "TR-987654",
            BancoOrigen = "BBVA",
            Estado = EstadoPago.Rechazado,
            Origen = OrigenPago.Inquilino,
            TieneComprobante = true,
            ComprobanteRuta = $"{condominioId}/101/2026/10/comprobante.jpg",
            ComprobanteHash = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789",
            EsReversa = false,
            MotivoRechazo = "Comprobante ilegible",
            MotivoAnulacion = null,
            RegistradoPor = Guid.NewGuid(),
            CreadoEn = DateTimeOffset.UtcNow.AddDays(-2),
            ConfirmadoPor = null,
            ConfirmadoEn = null,
            RechazadoPor = adminId,
            RechazadoEn = DateTimeOffset.UtcNow.AddDays(-1),
            AnuladoPor = null,
            AnuladoEn = null
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var rawJson = await response.Content.ReadAsStringAsync();
        using var jsonDoc = JsonDocument.Parse(rawJson);
        var root = jsonDoc.RootElement;

        // Verificar que no se expone ni ruta ni hash de comprobante
        Assert.False(root.TryGetProperty("comprobante_ruta", out _));
        Assert.False(root.TryGetProperty("comprobante_hash", out _));

        // Verificar datos completos
        Assert.Equal(pagoId.ToString(), root.GetProperty("id").GetString());
        Assert.Equal("Comprobante ilegible", root.GetProperty("motivo_rechazo").GetString());
        Assert.Equal(adminId.ToString(), root.GetProperty("rechazado_por").GetString());
        Assert.True(root.TryGetProperty("rechazado_en", out var rechazadoEnProp) && rechazadoEnProp.ValueKind != JsonValueKind.Null);
    }

    [Fact]
    public async Task ObtenerDetallePago_Admin_PagoOtroCondominio_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = otroCondominioId, // Pertenece a otro condominio
            ViviendaId = 101
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Pago no encontrado.", err.Error);
    }

    [Fact]
    public async Task ObtenerDetallePago_Inquilino_PagoSuVivienda_Retorna200OkConDetalle()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 42,
            NumeroCasa = "Casa 42",
            Monto = 1200m,
            Estado = EstadoPago.Confirmado,
            ConfirmadoPor = Guid.NewGuid(),
            ConfirmadoEn = DateTimeOffset.UtcNow
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(42, inquilinoId))
            .ReturnsAsync(true); // P6 método 3: es titular

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var pagoResp = await response.Content.ReadFromJsonAsync<PagoResponse>();
        Assert.NotNull(pagoResp);
        Assert.Equal(pagoId, pagoResp.Id);
        Assert.Equal(42, pagoResp.ViviendaId);
    }

    [Fact]
    public async Task ObtenerDetallePago_Inquilino_PagoViviendaAjena_Retorna404NotFound()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 99 // Vivienda ajena
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(99, inquilinoId))
            .ReturnsAsync(false); // P6 método 3: NO es titular

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Pago no encontrado.", err.Error);
    }

    [Fact]
    public async Task ObtenerDetallePago_PagoNoExiste_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync((VwPago?)null);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    #endregion

    #region GET api/pagos/{id}/comprobante-url - URL Firmada

    [Fact]
    public async Task ObtenerComprobanteUrl_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var pagoId = Guid.NewGuid();

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_RolSubusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var pagoId = Guid.NewGuid();
        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_Admin_Exito_Retorna200OkConUrlYExpiraEn()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var rutaComprobante = $"{condominioId}/10/2026/10/comprobante.jpg";
        var expectedSignedUrl = "https://mock.supabase.co/storage/v1/object/sign/comprobantes/test.jpg?token=abc";

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            TieneComprobante = true,
            ComprobanteRuta = rutaComprobante
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.CrearUrlFirmadaAsync(rutaComprobante, 300, It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedSignedUrl);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (dStorage != null) services.Remove(dStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<ComprobanteUrlResponse>();
        Assert.NotNull(resultado);
        Assert.Equal(expectedSignedUrl, resultado.Url);
        Assert.True(resultado.ExpiraEn > DateTimeOffset.UtcNow);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_PagoSinComprobante_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            TieneComprobante = false,
            ComprobanteRuta = null
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_ComprobanteDepuradoPorRetencion_Retorna404ConMensajeExacto()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var rutaComprobante = $"{condominioId}/10/2026/10/depurado.jpg";

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            TieneComprobante = true,
            ComprobanteRuta = rutaComprobante
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.CrearUrlFirmadaAsync(rutaComprobante, It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new KeyNotFoundException("Object not found"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (dStorage != null) services.Remove(dStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Comprobante depurado por política de retención", err.Error);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_Inquilino_PagoViviendaAjena_Retorna404NotFound()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 77,
            TieneComprobante = true,
            ComprobanteRuta = $"{condominioId}/77/2026/10/comprobante.jpg"
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(77, inquilinoId))
            .ReturnsAsync(false); // Inquilino no es titular

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ObtenerComprobanteUrl_NuncaLogueaUrlFirmada()
    {
        // Prueba unitaria directa sobre PagosService para validar la regla 3: Nunca loguear la URL firmada completa.
        var pagoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var ruta = $"{condominioId}/1/2026/10/foto.jpg";
        var urlSecreta = "https://mock.supabase.co/storage/v1/object/sign/comprobantes/foto.jpg?token=secret-token-123456789";

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(new VwPago
            {
                Id = pagoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                TieneComprobante = true,
                ComprobanteRuta = ruta
            });

        var mockUserContext = new Mock<IUserContextService>();
        mockUserContext.SetupGet(u => u.CondominioId).Returns(condominioId);
        mockUserContext.SetupGet(u => u.EsAdmin).Returns(true);
        mockUserContext.SetupGet(u => u.UserId).Returns(Guid.NewGuid());

        var mockViviendas = new Mock<IViviendasLookupService>();

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.CrearUrlFirmadaAsync(ruta, It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(urlSecreta);

        var mockLogger = new Mock<ILogger<PagosService>>();

        var storageOptions = Options.Create(new StorageOptions { UrlExpiracionSegundos = 300 });

        var service = new PagosService(
            mockSupabase.Object,
            mockUserContext.Object,
            mockViviendas.Object,
            mockLogger.Object,
            mockStorage.Object,
            storageOptions);

        var response = await service.ObtenerComprobanteUrlAsync(pagoId);

        Assert.Equal(urlSecreta, response.Url);

        // Verificar que ningún log contiene la URL firmada ni el token secreto
        mockLogger.Verify(
            l => l.Log(
                It.IsAny<LogLevel>(),
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v != null && (v.ToString()!.Contains(urlSecreta) || v.ToString()!.Contains("secret-token-123456789"))),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.Never);
    }

    #endregion
}
