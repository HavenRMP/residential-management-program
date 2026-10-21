using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class CargosControllerTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public CargosControllerTests(PagosApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task PostCargo_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var request = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PostCargo_ConRolInquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task PostCargo_AdminViviendaNoPertenece_Retorna404NotFound()
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

        var request = new CrearCargoRequest
        {
            ViviendaId = 999,
            Monto = 1000m,
            Concepto = "Cuota de mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-10",
            FechaVencimiento = new DateOnly(2026, 10, 31)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Vivienda no encontrada.", err.Error);
    }

    [Fact]
    public async Task PostCargo_AdminValidacionFallida_Retorna400BadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = -50m, // Monto inválido
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("monto", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task PostCargo_AdminExitoso_Retorna201CreatedConCargoResponse()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(5, condominioId))
            .ReturnsAsync(true);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), adminId))
            .ReturnsAsync(new CargoIdResult { Id = cargoId });

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            CondominioNombre = "Haven Towers",
            ViviendaId = 5,
            NumeroCasa = "Depto 502",
            PlantillaId = null,
            Periodo = new DateOnly(2026, 10, 1),
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Mantenimiento Octubre",
            Monto = 1200m,
            MontoPagadoConfirmado = 0m,
            SaldoPendiente = 1200m,
            Estado = EstadoCargo.Pendiente,
            FechaVencimiento = new DateOnly(2026, 10, 25),
            EstaVencido = false,
            ResponsablePago = ResponsablePago.Propietario,
            CreadoPor = adminId,
            CreadoEn = DateTimeOffset.UtcNow
        };

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptorViviendas != null) services.Remove(descriptorViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearCargoRequest
        {
            ViviendaId = 5,
            Monto = 1200m,
            Concepto = "Mantenimiento Octubre",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-10",
            FechaVencimiento = new DateOnly(2026, 10, 25),
            ResponsablePago = ResponsablePago.Propietario
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var created = await response.Content.ReadFromJsonAsync<CargoResponse>();
        Assert.NotNull(created);
        Assert.Equal(cargoId, created.Id);
        Assert.Equal(5, created.ViviendaId);
        Assert.Equal("Depto 502", created.NumeroCasa);
        Assert.Equal(1200m, created.Monto);
        Assert.Equal(1200m, created.SaldoPendiente);
        Assert.Equal("2026-10", created.Periodo);
        Assert.Equal(TipoCargo.Mantenimiento, created.Tipo);
        Assert.Equal(EstadoCargo.Pendiente, created.Estado);
        Assert.Equal("Pendiente", created.EstadoEfectivo);
    }

    [Fact]
    public async Task GetCargos_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/cargos");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetCargos_ConRolSubusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetCargos_Admin_Retorna200OkConPaginacion()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        var items = new List<VwCargo>
        {
            new()
            {
                Id = Guid.NewGuid(),
                CondominioId = condominioId,
                ViviendaId = 1,
                NumeroCasa = "101",
                Concepto = "Cuota Octubre",
                Monto = 1000m,
                Estado = EstadoCargo.Pendiente,
                EstaVencido = true
            }
        };

        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .ReturnsAsync((items, 1));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos?pagina=1&tamanoPagina=10&vencido=true");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<CargoResponse>>();
        Assert.NotNull(page);
        Assert.Single(page.Items);
        Assert.Equal(1, page.Total);
        Assert.Equal("Vencido", page.Items[0].EstadoEfectivo);
    }

    [Fact]
    public async Task GetCargos_Inquilino_ConViviendaPropia_Retorna200Ok()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int> { 12 });

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .ReturnsAsync((new List<VwCargo>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    CondominioId = condominioId,
                    ViviendaId = 12,
                    NumeroCasa = "12",
                    Concepto = "Renta Octubre",
                    Monto = 5000m,
                    Estado = EstadoCargo.Pagado,
                    EstaVencido = false
                }
            }, 1));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptorViviendas != null) services.Remove(descriptorViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos?vivienda_id=12");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<CargoResponse>>();
        Assert.NotNull(page);
        Assert.Single(page.Items);
        Assert.Equal("Pagado", page.Items[0].EstadoEfectivo);
    }

    [Fact]
    public async Task GetCargos_Inquilino_ConViviendaAjena_Retorna403Forbidden()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int> { 12 });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptorViviendas != null) services.Remove(descriptorViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos?vivienda_id=99");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("no te pertenece", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GetCargos_Inquilino_ConUsuarioIdAjeno_Retorna403Forbidden()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos?usuario_id={Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("inquilinos", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GetCargos_FechasInvalidas_Retorna400BadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos?vencimiento_desde=2026-12-01&vencimiento_hasta=2026-11-01");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("vencimiento", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GetCargoPorId_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync($"/api/cargos/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetCargoPorId_ConRolSubusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetCargoPorId_Admin_Exito_Retorna200OkConDetalle()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "101",
            Concepto = "Cuota Octubre",
            Monto = 1500m,
            Estado = EstadoCargo.Parcial,
            EstaVencido = false
        };

        var vwPagos = new List<VwPago>
        {
            new()
            {
                Id = Guid.NewGuid(),
                CargoId = cargoId,
                Monto = 500m,
                Estado = EstadoPago.Confirmado,
                FechaPago = new DateOnly(2026, 10, 10)
            }
        };

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        mockRestClient
            .Setup(c => c.GetAsync<VwPago>("vw_pagos", $"cargo_id=eq.{cargoId}&order=fecha_pago.desc,creado_en.desc"))
            .ReturnsAsync(vwPagos);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos/{cargoId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detalle = await response.Content.ReadFromJsonAsync<CargoDetalleResponse>();
        Assert.NotNull(detalle);
        Assert.Equal(cargoId, detalle.Id);
        Assert.Equal("Parcial", detalle.EstadoEfectivo);
        Assert.Single(detalle.Pagos);
        Assert.Equal(500m, detalle.Pagos[0].Monto);
    }

    [Fact]
    public async Task GetCargoPorId_Inquilino_NoTitular_Retorna404NotFound()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(55, inquilinoId))
            .ReturnsAsync(false);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 55
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptorViviendas != null) services.Remove(descriptorViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos/{cargoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Cargo no encontrado.", err.Error);
    }

    [Fact]
    public async Task GetCargoPorId_Inquilino_Titular_Retorna200OkConDetalle()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(77, inquilinoId))
            .ReturnsAsync(true);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 77,
                NumeroCasa = "Casa 77",
                Estado = EstadoCargo.Pendiente,
                EstaVencido = true
            });

        mockRestClient
            .Setup(c => c.GetAsync<VwPago>("vw_pagos", $"cargo_id=eq.{cargoId}&order=fecha_pago.desc,creado_en.desc"))
            .ReturnsAsync(new List<VwPago>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    CargoId = cargoId,
                    Monto = 200m,
                    Estado = EstadoPago.PendienteConfirmacion,
                    FechaPago = new DateOnly(2026, 10, 1)
                }
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descriptorViviendas != null) services.Remove(descriptorViviendas);
                services.AddScoped(_ => mockViviendas.Object);

                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos/{cargoId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var detalle = await response.Content.ReadFromJsonAsync<CargoDetalleResponse>();
        Assert.NotNull(detalle);
        Assert.Equal(cargoId, detalle.Id);
        Assert.Equal("Vencido", detalle.EstadoEfectivo);
        Assert.Single(detalle.Pagos);
        Assert.Equal(EstadoPago.PendienteConfirmacion, detalle.Pagos[0].Estado);
    }

    [Fact]
    public async Task CancelarCargo_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.PostAsJsonAsync($"/api/cargos/{Guid.NewGuid()}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error" });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CancelarCargo_Inquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{Guid.NewGuid()}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error" });
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CancelarCargo_MotivoInvalido_Retorna400BadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{Guid.NewGuid()}/cancelar", new CancelarCargoRequest { Motivo = "abc" });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("motivo", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CancelarCargo_CargoNoExiste_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync((VwCargo?)null);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error de captura" });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Cargo no encontrado.", err.Error);
    }

    [Fact]
    public async Task CancelarCargo_RpcPG005_Retorna409Conflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId
            });

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), adminId))
            .ThrowsAsync(new PostgrestException(409, "PG005", "El cargo ya está cancelado"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error" });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("El cargo ya está cancelado", err.Error);
    }

    [Fact]
    public async Task CancelarCargo_RpcPG006_Retorna409Conflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId
            });

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), adminId))
            .ThrowsAsync(new PostgrestException(409, "PG006", "No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error" });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes", err.Error);
    }

    [Fact]
    public async Task CancelarCargo_AdminExito_Retorna200OkConCargoResponse()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        var vwCargoActivo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "101",
            Estado = EstadoCargo.Pendiente,
            EstaVencido = false
        };

        var vwCargoCancelado = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "101",
            Estado = EstadoCargo.Cancelado,
            EstaVencido = false,
            MotivoCancelacion = "Cancelación autorizada por asamblea"
        };

        using var jsonDoc = System.Text.Json.JsonDocument.Parse("{}");

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargoActivo);

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), adminId))
            .ReturnsAsync(jsonDoc.RootElement);

        mockRestClient
            .SetupSequence(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargoActivo)
            .ReturnsAsync(vwCargoCancelado);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptorRest = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptorRest != null) services.Remove(descriptorRest);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación autorizada por asamblea" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var res = await response.Content.ReadFromJsonAsync<CargoResponse>();
        Assert.NotNull(res);
        Assert.Equal(cargoId, res.Id);
        Assert.Equal(EstadoCargo.Cancelado, res.Estado);
        Assert.Equal("Cancelado", res.EstadoEfectivo);
        Assert.Equal("Cancelación autorizada por asamblea", res.MotivoCancelacion);
    }

    #region Casos 6 al 21 - Bloque Q Cargos

    // Caso 6: Admin crea cargo válido => 201, con x-actor-id y condominio_id tomados del token.
    [Fact]
    public async Task Caso6_CrearCargo_AdminCreaCargoValido_Retorna201ConActorIdYCondominioIdDelToken()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.ExisteViviendaEnCondominioAsync(10, condominioId))
            .ReturnsAsync(true);

        CargoInsert? insertCapturado = null;
        Guid? actorIdCapturado = null;

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, insert, actor) =>
            {
                insertCapturado = (CargoInsert)insert;
                actorIdCapturado = actor;
            })
            .ReturnsAsync(new CargoIdResult { Id = cargoId });

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                NumeroCasa = "Casa 10",
                Monto = 1500m,
                SaldoPendiente = 1500m,
                Estado = EstadoCargo.Pendiente,
                EstaVencido = false,
                Tipo = TipoCargo.Mantenimiento,
                Periodo = new DateOnly(2026, 11, 1),
                FechaVencimiento = new DateOnly(2026, 11, 15),
                CreadoPor = adminId
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearCargoRequest
        {
            ViviendaId = 10,
            Monto = 1500m,
            Concepto = "Mantenimiento noviembre",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-11",
            FechaVencimiento = new DateOnly(2026, 11, 15)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(insertCapturado);
        Assert.Equal(condominioId, insertCapturado.CondominioId);
        Assert.Equal(adminId, actorIdCapturado);

        var body = await response.Content.ReadFromJsonAsync<CargoResponse>();
        Assert.NotNull(body);
        Assert.Equal(cargoId, body.Id);
        Assert.Equal(condominioId, body.CondominioId);
    }

    // Caso 7: Inquilino intenta crear => 403. Subusuario => 403.
    [Fact]
    public async Task Caso7_CrearCargo_InquilinoOSubusuarioIntentanCrear_Retorna403Forbidden()
    {
        var clientInquilino = _factory.CreateClient();
        clientInquilino.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateInquilinoToken());

        var request = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var resInquilino = await clientInquilino.PostAsJsonAsync("/api/cargos", request);
        Assert.Equal(HttpStatusCode.Forbidden, resInquilino.StatusCode);

        var clientSubusuario = _factory.CreateClient();
        clientSubusuario.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateSubusuarioToken());

        var resSubusuario = await clientSubusuario.PostAsJsonAsync("/api/cargos", request);
        Assert.Equal(HttpStatusCode.Forbidden, resSubusuario.StatusCode);
    }

    // Caso 8: Monto cero, negativo o con 3 decimales => 400.
    [Theory]
    [InlineData(0)]
    [InlineData(-50)]
    [InlineData(100.123)]
    public async Task Caso8_CrearCargo_MontoCeroNegativoOConTresDecimales_Retorna400BadRequest(decimal monto)
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateAdminToken());

        var request = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = monto,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("monto", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    // Caso 9: Renta sin periodo => 400. Multa sin periodo => 201.
    [Fact]
    public async Task Caso9_CrearCargo_RentaSinPeriodoRetorna400_MultaSinPeriodoRetorna201()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas.Setup(v => v.ExisteViviendaEnCondominioAsync(It.IsAny<int>(), condominioId)).ReturnsAsync(true);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), adminId))
            .ReturnsAsync(new CargoIdResult { Id = cargoId });

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoCargo.Multa,
                Monto = 500m,
                Estado = EstadoCargo.Pendiente,
                FechaVencimiento = new DateOnly(2026, 12, 1)
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1. Renta sin periodo => 400
        var reqRenta = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 1000m,
            Concepto = "Renta sin periodo",
            Tipo = TipoCargo.Renta,
            Periodo = null,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };
        var resRenta = await client.PostAsJsonAsync("/api/cargos", reqRenta);
        Assert.Equal(HttpStatusCode.BadRequest, resRenta.StatusCode);

        // 2. Multa sin periodo => 201
        var reqMulta = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 500m,
            Concepto = "Multa por ruido",
            Tipo = TipoCargo.Multa,
            Periodo = null,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };
        var resMulta = await client.PostAsJsonAsync("/api/cargos", reqMulta);
        Assert.Equal(HttpStatusCode.Created, resMulta.StatusCode);
    }

    // Caso 10: Vivienda de otro condominio => 404.
    [Fact]
    public async Task Caso10_CrearCargo_ViviendaDeOtroCondominio_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas.Setup(v => v.ExisteViviendaEnCondominioAsync(888, condominioId)).ReturnsAsync(false);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearCargoRequest
        {
            ViviendaId = 888,
            Monto = 200m,
            Concepto = "Servicio agua",
            Tipo = TipoCargo.Servicio,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var response = await client.PostAsJsonAsync("/api/cargos", request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockRestClient.Verify(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), It.IsAny<Guid?>()), Times.Never());
    }

    // Caso 11: condominio_id o creado_por mandados en el body se ignoran.
    [Fact]
    public async Task Caso11_CrearCargo_CondominioIdOCreadoPorEnElBody_SeIgnoran()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas.Setup(v => v.ExisteViviendaEnCondominioAsync(3, condominioId)).ReturnsAsync(true);

        CargoInsert? insertCapturado = null;
        Guid? actorIdCapturado = null;

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, ins, actor) =>
            {
                insertCapturado = (CargoInsert)ins;
                actorIdCapturado = actor;
            })
            .ReturnsAsync(new CargoIdResult { Id = cargoId });

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 3,
                Estado = EstadoCargo.Pendiente,
                FechaVencimiento = new DateOnly(2026, 12, 1)
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Body con ids ficticios o de ataque
        var fakeCondominioId = Guid.NewGuid();
        var fakeCreadoPor = Guid.NewGuid();
        var rawJson = $@"{{
            ""vivienda_id"": 3,
            ""monto"": 450.00,
            ""concepto"": ""Prueba ignorar ids del body"",
            ""tipo"": ""Otro"",
            ""fecha_vencimiento"": ""2026-12-01"",
            ""condominio_id"": ""{fakeCondominioId}"",
            ""creado_por"": ""{fakeCreadoPor}""
        }}";

        var content = new StringContent(rawJson, System.Text.Encoding.UTF8, "application/json");
        var response = await client.PostAsync("/api/cargos", content);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(insertCapturado);
        Assert.Equal(condominioId, insertCapturado.CondominioId);
        Assert.NotEqual(fakeCondominioId, insertCapturado.CondominioId);
        Assert.Equal(adminId, actorIdCapturado);
        Assert.NotEqual(fakeCreadoPor, actorIdCapturado);
    }

    // Caso 12: Admin siempre consulta con su condominio_id.
    [Fact]
    public async Task Caso12_ListarCargos_AdminSiempreConsultaConSuCondominioId()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        string? queryCapturado = null;
        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => queryCapturado = q)
            .ReturnsAsync((new List<VwCargo>(), 0));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/cargos");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryCapturado);
        Assert.Contains($"condominio_id=eq.{condominioId}", queryCapturado);
    }

    // Caso 13: Admin con usuario_id => las viviendas se resuelven y se filtra con "in".
    [Fact]
    public async Task Caso13_ListarCargos_AdminConUsuarioId_ResuelveViviendasYFiltraConIn()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var targetUserId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(targetUserId))
            .ReturnsAsync(new List<int> { 101, 102 });

        string? queryCapturado = null;
        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => queryCapturado = q)
            .ReturnsAsync((new List<VwCargo>(), 0));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos?usuario_id={targetUserId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryCapturado);
        Assert.Contains("vivienda_id=in.(101,102)", queryCapturado);
        Assert.Contains($"condominio_id=eq.{condominioId}", queryCapturado);
    }

    // Caso 14: Inquilino solo recibe sus viviendas; con usuario_id ajeno => 403; con vivienda_id ajena => 403.
    [Fact]
    public async Task Caso14_ListarCargos_InquilinoSoloRecibeSusViviendas_UsuarioIdAjenoRetorna403_ViviendaAjenaRetorna403()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int> { 25, 26 });

        string? queryCapturado = null;
        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => queryCapturado = q)
            .ReturnsAsync((new List<VwCargo>(), 0));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 14.a Inquilino consulta sus cargos => filtro con sus viviendas
        var resPropio = await client.GetAsync("/api/cargos");
        Assert.Equal(HttpStatusCode.OK, resPropio.StatusCode);
        Assert.NotNull(queryCapturado);
        Assert.Contains("vivienda_id=in.(25,26)", queryCapturado);

        // 14.b Inquilino consulta con usuario_id ajeno => 403
        var resOtroUsuario = await client.GetAsync($"/api/cargos?usuario_id={Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, resOtroUsuario.StatusCode);

        // 14.c Inquilino consulta con vivienda_id ajena (ej. 999) => 403
        var resOtraVivienda = await client.GetAsync("/api/cargos?vivienda_id=999");
        Assert.Equal(HttpStatusCode.Forbidden, resOtraVivienda.StatusCode);
    }

    // Caso 15: Lista de viviendas vacía => página vacía sin consultar la vista.
    [Fact]
    public async Task Caso15_ListarCargos_ListaDeViviendasVacia_RetornaPaginaVaciaSinConsultarVista()
    {
        // 15.a Inquilino sin viviendas
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int>()); // Vacía

        var mockRestClient = new Mock<ISupabaseRestClient>();

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);

        var resInquilino = await client.GetAsync("/api/cargos");
        Assert.Equal(HttpStatusCode.OK, resInquilino.StatusCode);
        var pagInquilino = await resInquilino.Content.ReadFromJsonAsync<RespuestaPaginadaDto<CargoResponse>>();
        Assert.NotNull(pagInquilino);
        Assert.Empty(pagInquilino.Items);
        Assert.Equal(0, pagInquilino.Total);

        // 15.b Admin con usuario_id sin viviendas
        var adminId = Guid.NewGuid();
        var targetUserSinViviendas = Guid.NewGuid();
        var tokenAdmin = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(targetUserSinViviendas))
            .ReturnsAsync(new List<int>()); // Vacía

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);
        var resAdmin = await client.GetAsync($"/api/cargos?usuario_id={targetUserSinViviendas}");
        Assert.Equal(HttpStatusCode.OK, resAdmin.StatusCode);
        var pagAdmin = await resAdmin.Content.ReadFromJsonAsync<RespuestaPaginadaDto<CargoResponse>>();
        Assert.NotNull(pagAdmin);
        Assert.Empty(pagAdmin.Items);
        Assert.Equal(0, pagAdmin.Total);

        // Verificar que GetPagedAsync NUNCA fue llamado
        mockRestClient.Verify(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()), Times.Never());
    }

    // Caso 16: El filtro vencido llega al cliente como filtro esta_vencido.
    [Theory]
    [InlineData(true, "esta_vencido=eq.true")]
    [InlineData(false, "esta_vencido=eq.false")]
    public async Task Caso16_ListarCargos_FiltroVencido_LlegaAlClienteComoFiltroEstaVencido(bool vencido, string filtroEsperado)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        string? queryCapturado = null;
        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => queryCapturado = q)
            .ReturnsAsync((new List<VwCargo>(), 0));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos?vencido={vencido.ToString().ToLowerInvariant()}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryCapturado);
        Assert.Contains(filtroEsperado, queryCapturado);
    }

    // Caso 17: Cargo de otro condominio => 404. Inquilino con cargo de otra vivienda => 404.
    [Fact]
    public async Task Caso17_DetalleCargo_CargoDeOtroCondominioOInquilinoConOtraVivienda_Retorna404NotFound()
    {
        var cargoId = Guid.NewGuid();
        var adminCondominio = Guid.NewGuid();
        var otroCondominio = Guid.NewGuid();
        var adminId = Guid.NewGuid();
        var inquilinoId = Guid.NewGuid();

        // 17.a Admin intenta consultar cargo de otro condominio => 404
        var tokenAdmin = TestTokenGenerator.GenerateAdminToken(adminId, adminCondominio);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = otroCondominio,
                ViviendaId = 1
            });

        var mockViviendas = new Mock<IViviendasLookupService>();

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descV = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (descV != null) services.Remove(descV);
                services.AddScoped(_ => mockViviendas.Object);

                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);
        var resAdmin = await client.GetAsync($"/api/cargos/{cargoId}");
        Assert.Equal(HttpStatusCode.NotFound, resAdmin.StatusCode);

        // 17.b Inquilino intenta consultar cargo de otra vivienda => 404
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, adminCondominio);
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = adminCondominio,
                ViviendaId = 99
            });

        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(99, inquilinoId))
            .ReturnsAsync(false); // No es titular

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);
        var resInquilino = await client.GetAsync($"/api/cargos/{cargoId}");
        Assert.Equal(HttpStatusCode.NotFound, resInquilino.StatusCode);
    }

    // Caso 18: La respuesta nunca contiene comprobante_ruta ni comprobante_hash.
    [Fact]
    public async Task Caso18_DetalleCargo_RespuestaNuncaContieneComprobanteRutaNiComprobanteHash()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Monto = 1000m,
                Estado = EstadoCargo.Pendiente
            });

        mockRestClient
            .Setup(c => c.GetAsync<VwPago>("vw_pagos", $"cargo_id=eq.{cargoId}&order=fecha_pago.desc,creado_en.desc"))
            .ReturnsAsync(new List<VwPago>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    CargoId = cargoId,
                    CondominioId = condominioId,
                    ViviendaId = 1,
                    Monto = 500m,
                    Estado = EstadoPago.Confirmado,
                    TieneComprobante = true,
                    ComprobanteRuta = "condominios/top-secret/comprobante123.pdf",
                    ComprobanteHash = "hash-super-secreto-998877"
                }
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/cargos/{cargoId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var jsonString = await response.Content.ReadAsStringAsync();
        Assert.DoesNotContain("comprobante_ruta", jsonString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("comprobanteRuta", jsonString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("top-secret", jsonString, StringComparison.OrdinalIgnoreCase);

        Assert.DoesNotContain("comprobante_hash", jsonString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("comprobanteHash", jsonString, StringComparison.OrdinalIgnoreCase);
        Assert.DoesNotContain("hash-super-secreto", jsonString, StringComparison.OrdinalIgnoreCase);

        // Verificación estructural de DTOs
        Assert.Null(typeof(PagoResumenResponse).GetProperty("ComprobanteRuta"));
        Assert.Null(typeof(PagoResumenResponse).GetProperty("ComprobanteHash"));
        Assert.Null(typeof(CargoResponse).GetProperty("ComprobanteRuta"));
        Assert.Null(typeof(CargoResponse).GetProperty("ComprobanteHash"));
    }

    // Caso 19: Cancelar cargo válido => 200 y la RPC recibe p_actor_id del token.
    [Fact]
    public async Task Caso19_CancelarCargo_CargoValido_Retorna200YRpcRecibePActorIdDelToken()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        var vwCargoActivo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "Casa 1",
            Estado = EstadoCargo.Pendiente,
            EstaVencido = false
        };

        var vwCargoCancelado = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "Casa 1",
            Estado = EstadoCargo.Cancelado,
            EstaVencido = false,
            MotivoCancelacion = "Cancelación autorizada en sesión ordinaria"
        };

        object? rpcPayloadCapturado = null;
        Guid? actorRpcCapturado = null;

        using var jsonDoc = System.Text.Json.JsonDocument.Parse("{}");

        mockRestClient
            .SetupSequence(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargoActivo)
            .ReturnsAsync(vwCargoCancelado);

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actor) =>
            {
                rpcPayloadCapturado = payload;
                actorRpcCapturado = actor;
            })
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CancelarCargoRequest
        {
            Motivo = "Cancelación autorizada en sesión ordinaria"
        };

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, actorRpcCapturado);

        var dict = Assert.IsAssignableFrom<IDictionary<string, object>>(rpcPayloadCapturado);
        Assert.Equal(cargoId, dict["p_cargo_id"]);
        Assert.Equal("Cancelación autorizada en sesión ordinaria", dict["p_motivo"]);
        Assert.Equal(adminId, dict["p_actor_id"]);

        var cargoRes = await response.Content.ReadFromJsonAsync<CargoResponse>();
        Assert.NotNull(cargoRes);
        Assert.Equal(cargoId, cargoRes.Id);
        Assert.Equal(EstadoCargo.Cancelado, cargoRes.Estado);
        Assert.Equal("Cancelado", cargoRes.EstadoEfectivo);
    }

    // Caso 20: La RPC responde PG005 => 409. PG006 => 409. PG000 => 404.
    [Theory]
    [InlineData("PG005", 409, "El cargo ya está cancelado")]
    [InlineData("PG006", 409, "No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes")]
    [InlineData("PG000", 404, "El recurso solicitado no fue encontrado.")]
    public async Task Caso20_CancelarCargo_RpcRespondePG005oPG006oPG000_RetornaCodigoCorrespondiente(string dbCode, int expectedStatusCode, string expectedMessage)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId
            });

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), adminId))
            .ThrowsAsync(new PostgrestException(expectedStatusCode, dbCode, expectedMessage));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación por error administrativo" });
        Assert.Equal((HttpStatusCode)expectedStatusCode, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal(expectedMessage, err.Error);
    }

    // Caso 21: Sin motivo => 400. Inquilino => 403. Cargo de otro condominio => 404 sin llamar a la RPC.
    [Fact]
    public async Task Caso21_CancelarCargo_SinMotivoRetorna400_InquilinoRetorna403_CargoOtroCondominioRetorna404SinLlamarRpc()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var tokenAdmin = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        // 21.a Sin motivo o motivo inválido => 400
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);
        var resSinMotivo = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "" });
        Assert.Equal(HttpStatusCode.BadRequest, resSinMotivo.StatusCode);

        var resMotivoCorto = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "hola" });
        Assert.Equal(HttpStatusCode.BadRequest, resMotivoCorto.StatusCode);

        // 21.b Inquilino => 403
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);
        var resInquilino = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación válida de 10 caracteres" });
        Assert.Equal(HttpStatusCode.Forbidden, resInquilino.StatusCode);

        // 21.c Cargo de otro condominio => 404 sin llamar a la RPC
        var otroCondominioId = Guid.NewGuid();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = otroCondominioId // Pertenece a otro condominio
            });

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);
        var resOtroCondominio = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/cancelar", new CancelarCargoRequest { Motivo = "Cancelación de prueba válida" });
        Assert.Equal(HttpStatusCode.NotFound, resOtroCondominio.StatusCode);

        // Asegurarse de que NUNCA se llamó a la RPC
        mockRestClient.Verify(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_cancelar_cargo", It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never());
    }

    #endregion

    #region Aplicación manual de saldo a favor a cargos (Prompt U3)

    // Caso 22: Admin aplica saldo a favor válido => 200 con movimiento, cargo y saldo_a_favor
    [Fact]
    public async Task Caso22_AplicarSaldoFavor_AdminValido_Retorna200OkConMovimientoCargoYSaldo()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                NumeroCasa = "101",
                Monto = 1000m,
                MontoPagadoConfirmado = 200m,
                SaldoPendiente = 800m,
                Estado = EstadoCargo.Pendiente
            });

        object? rpcPayloadCapturado = null;
        Guid? actorRpcCapturado = null;

        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{movimientoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""tipo"": ""Aplicacion"",
                ""monto"": 300.50,
                ""monto_con_signo"": -300.50,
                ""cargo_id"": ""{cargoId}"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T18:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""numero_casa"": ""101"",
                ""monto"": 1000.0,
                ""monto_pagado"": 500.50,
                ""saldo_pendiente"": 499.50,
                ""estado"": ""Pendiente"",
                ""tipo"": ""Mantenimiento"",
                ""concepto"": ""Cuota octubre"",
                ""fecha_vencimiento"": ""2026-10-31""
            }},
            ""saldo_a_favor"": 199.50
        }}";

        using var jsonDoc = System.Text.Json.JsonDocument.Parse(jsonResponse);

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actor) =>
            {
                rpcPayloadCapturado = payload;
                actorRpcCapturado = actor;
            })
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new AplicarSaldoFavorRequest
        {
            Monto = 300.50m
        };

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, actorRpcCapturado);

        var dict = Assert.IsAssignableFrom<IDictionary<string, object?>>(rpcPayloadCapturado);
        Assert.Equal(cargoId, dict["p_cargo_id"]);
        Assert.Equal(300.50m, dict["p_monto"]);
        Assert.Equal(adminId, dict["p_actor_id"]);

        var resultado = await response.Content.ReadFromJsonAsync<AplicarSaldoFavorResponse>();
        Assert.NotNull(resultado);
        Assert.NotNull(resultado.Movimiento);
        Assert.Equal(movimientoId, resultado.Movimiento.Id);
        Assert.Equal(TipoMovimientoSaldo.Aplicacion, resultado.Movimiento.Tipo);
        Assert.Equal(300.50m, resultado.Movimiento.Monto);
        Assert.NotNull(resultado.Cargo);
        Assert.Equal(cargoId, resultado.Cargo.Id);
        Assert.Equal(499.50m, resultado.Cargo.SaldoPendiente);
        Assert.Equal(199.50m, resultado.SaldoAFavor);
    }

    // Caso 23: Sin token => 401. Inquilino => 403.
    [Fact]
    public async Task Caso23_AplicarSaldoFavor_SinTokenRetorna401_InquilinoRetorna403()
    {
        var cargoId = Guid.NewGuid();
        var client = _factory.CreateClient();

        // 23.a Sin token
        var resSinToken = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 100m });
        Assert.Equal(HttpStatusCode.Unauthorized, resSinToken.StatusCode);

        // 23.b Inquilino => 403
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);
        var resInquilino = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 100m });
        Assert.Equal(HttpStatusCode.Forbidden, resInquilino.StatusCode);
    }

    // Caso 24: Cargo de otro condominio => 404 sin llamar a la RPC
    [Fact]
    public async Task Caso24_AplicarSaldoFavor_CargoOtroCondominio_Retorna404SinLlamarRpc()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = otroCondominioId
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 100m });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        mockRestClient.Verify(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never());
    }

    // Caso 25: Monto inválido (cero, negativo o más de 2 decimales) => 400 sin llamar a la RPC
    [Theory]
    [InlineData(0)]
    [InlineData(-50)]
    [InlineData(100.125)]
    public async Task Caso25_AplicarSaldoFavor_MontoInvalido_Retorna400SinLlamarRpc(decimal montoInvalido)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId
            });

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = montoInvalido });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        mockRestClient.Verify(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never());
    }

    // Caso 26: La RPC responde errores de negocio (PG007, PG008, PG010, PG001, PG005) => 409
    [Theory]
    [InlineData("PG007", 409, "Saldo a favor insuficiente")]
    [InlineData("PG008", 409, "El monto es inválido o mayor al saldo pendiente del cargo")]
    [InlineData("PG010", 409, "El cargo ya está pagado")]
    [InlineData("PG001", 409, "El cargo está cancelado o el estado no permite la operación")]
    [InlineData("PG005", 409, "El cargo ya está cancelado")]
    public async Task Caso26_AplicarSaldoFavor_RpcRespondeErroresDeNegocio_Retorna409(string dbCode, int expectedStatusCode, string expectedMessage)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId
            });

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), adminId))
            .ThrowsAsync(new PostgrestException(expectedStatusCode, dbCode, expectedMessage));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 500m });
        Assert.Equal((HttpStatusCode)expectedStatusCode, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal(expectedMessage, err.Error);
    }

    // Caso 27: Nodo cargo sin campos calculados en respuesta de RPC => relee de vw_cargos
    [Fact]
    public async Task Caso27_AplicarSaldoFavor_CargoSinCamposCalculadosEnRpc_ReleeDeVwCargos()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var mockRestClient = new Mock<ISupabaseRestClient>();

        // Lectura previa para verificar condominio
        mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 20,
                NumeroCasa = "202",
                Monto = 1500m,
                SaldoPendiente = 1500m,
                Estado = EstadoCargo.Pendiente
            });

        // La RPC devuelve el nodo cargo pero sin campos calculados (numero_casa vacío)
        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{movimientoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 20,
                ""tipo"": ""Aplicacion"",
                ""monto"": 500.0,
                ""monto_con_signo"": -500.0,
                ""cargo_id"": ""{cargoId}"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T18:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""monto"": 1500.0,
                ""estado"": ""Pendiente""
            }},
            ""saldo_a_favor"": 0.0
        }}";

        using var jsonDoc = System.Text.Json.JsonDocument.Parse(jsonResponse);

        mockRestClient
            .Setup(c => c.RpcAsync<System.Text.Json.JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), adminId))
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descR = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descR != null) services.Remove(descR);
                services.AddScoped(_ => mockRestClient.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 500m });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<AplicarSaldoFavorResponse>();
        Assert.NotNull(resultado);
        Assert.Equal(cargoId, resultado.Cargo.Id);
        Assert.Equal("202", resultado.Cargo.NumeroCasa);

        // Se verificó que se consultó vw_cargos para releer
        mockRestClient.Verify(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"), Times.AtLeast(2));
    }

    #endregion
}

