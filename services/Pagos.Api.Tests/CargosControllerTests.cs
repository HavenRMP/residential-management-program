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
}
