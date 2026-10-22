using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using HavenApi.Shared.Pagination;
using Xunit;

namespace Pagos.Api.Tests;

public class SaldosTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public SaldosTests(PagosApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseRestClient.Reset();
    }

    // =========================================================================
    // 1. GET api/saldos/viviendas/{viviendaId}
    // =========================================================================

    [Fact]
    public async Task GetSaldoPorVivienda_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/saldos/viviendas/1");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_Subusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/saldos/viviendas/1");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_Admin_ViviendaDeSuCondominio_Retorna200Ok()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup confirma pertenencia al condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.Is<string>(q => q.Contains("id=eq.10") && q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        // Vista v_saldo_vivienda devuelve registro
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                "vivienda_id=eq.10"))
            .ReturnsAsync(new VSaldoVivienda
            {
                ViviendaId = 10,
                CondominioId = condominioId,
                NumeroCasa = "Casa 10",
                TotalPendiente = 2500.50m,
                TotalVencido = 1000m,
                TotalCargosAbiertos = 2,
                SaldoAFavor = 300m
            });

        var response = await client.GetAsync("/api/saldos/viviendas/10");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoViviendaResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(10, saldo.ViviendaId);
        Assert.Equal("Casa 10", saldo.NumeroCasa);
        Assert.Equal(2500.50m, saldo.TotalPendiente);
        Assert.Equal(1000m, saldo.TotalVencido);
        Assert.Equal(2, saldo.TotalCargosAbiertos);
        Assert.Equal(300m, saldo.SaldoAFavor);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_Admin_ViviendaDeOtroCondominio_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup no encuentra la vivienda en su condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync((ViviendaItemDto?)null);

        var response = await client.GetAsync("/api/saldos/viviendas/99");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        // No se consulta la vista de saldos
        _factory.MockSupabaseRestClient.Verify(
            c => c.GetSingleOrDefaultAsync<VSaldoVivienda>("v_saldo_vivienda", It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_Inquilino_ResidenteTitular_Retorna200Ok()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup confirma que es titular
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.Is<string>(q => q.Contains("vivienda_id=eq.5") && q.Contains($"usuario_id=eq.{inquilinoId}"))))
            .ReturnsAsync(new ViviendaResidenteItemDto { ViviendaId = 5 });

        // Vista devuelve saldo
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                "vivienda_id=eq.5"))
            .ReturnsAsync(new VSaldoVivienda
            {
                ViviendaId = 5,
                CondominioId = condominioId,
                NumeroCasa = "Depto 5",
                TotalPendiente = 0m,
                TotalVencido = 0m,
                TotalCargosAbiertos = 0,
                SaldoAFavor = 500m
            });

        var response = await client.GetAsync("/api/saldos/viviendas/5");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoViviendaResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(5, saldo.ViviendaId);
        Assert.Equal(500m, saldo.SaldoAFavor);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_Inquilino_NoEsResidenteTitular_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // No es titular
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.IsAny<string>()))
            .ReturnsAsync((ViviendaResidenteItemDto?)null);

        var response = await client.GetAsync("/api/saldos/viviendas/8");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetSingleOrDefaultAsync<VSaldoVivienda>("v_saldo_vivienda", It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetSaldoPorVivienda_ViviendaSinCargos_RetornaTotalesEnCero()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 20 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                "vivienda_id=eq.20"))
            .ReturnsAsync(new VSaldoVivienda
            {
                ViviendaId = 20,
                CondominioId = condominioId,
                NumeroCasa = "Casa 20",
                TotalPendiente = 0m,
                TotalVencido = 0m,
                TotalCargosAbiertos = 0,
                SaldoAFavor = 0m
            });

        var response = await client.GetAsync("/api/saldos/viviendas/20");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoViviendaResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(20, saldo.ViviendaId);
        Assert.Equal("Casa 20", saldo.NumeroCasa);
        Assert.Equal(0m, saldo.TotalPendiente);
        Assert.Equal(0m, saldo.TotalVencido);
        Assert.Equal(0, saldo.TotalCargosAbiertos);
        Assert.Equal(0m, saldo.SaldoAFavor);
    }

    // =========================================================================
    // 2. GET api/saldos/mi-saldo (Inquilino)
    // =========================================================================

    [Fact]
    public async Task GetMiSaldo_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/saldos/mi-saldo");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetMiSaldo_Admin_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/saldos/mi-saldo");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetMiSaldo_UsuarioSinViviendas_Retorna200ConCerosSinConsultarVista()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup devuelve lista vacía de viviendas
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.IsAny<string>()))
            .ReturnsAsync(new List<ViviendaResidenteItemDto>());

        var response = await client.GetAsync("/api/saldos/mi-saldo");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoUsuarioResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(0m, saldo.TotalPendiente);
        Assert.Equal(0m, saldo.TotalVencido);
        Assert.Equal(0, saldo.TotalCargosAbiertos);
        Assert.Equal(0m, saldo.SaldoAFavor);
        Assert.Empty(saldo.Viviendas);

        // Regla 3: Verifica que NUNCA se consultó la vista v_saldo_vivienda
        _factory.MockSupabaseRestClient.Verify(
            c => c.GetAsync<VSaldoVivienda>("v_saldo_vivienda", It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetMiSaldo_UsuarioConViviendas_SumaTotalesYDesglosa()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup devuelve dos viviendas: 1 y 2
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.Is<string>(q => q.Contains($"usuario_id=eq.{inquilinoId}"))))
            .ReturnsAsync(new List<ViviendaResidenteItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 }
            });

        // Vista devuelve registros para ambas viviendas
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                It.Is<string>(q => q.Contains("vivienda_id=in.(1,2)"))))
            .ReturnsAsync(new List<VSaldoVivienda>
            {
                new()
                {
                    ViviendaId = 1,
                    CondominioId = condominioId,
                    NumeroCasa = "Casa 1",
                    TotalPendiente = 1500m,
                    TotalVencido = 500m,
                    TotalCargosAbiertos = 1,
                    SaldoAFavor = 200m
                },
                new()
                {
                    ViviendaId = 2,
                    CondominioId = condominioId,
                    NumeroCasa = "Casa 2",
                    TotalPendiente = 2000m,
                    TotalVencido = 1000m,
                    TotalCargosAbiertos = 2,
                    SaldoAFavor = 100m
                }
            });

        var response = await client.GetAsync("/api/saldos/mi-saldo");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoUsuarioResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(3500m, saldo.TotalPendiente); // 1500 + 2000
        Assert.Equal(1500m, saldo.TotalVencido);   // 500 + 1000
        Assert.Equal(3, saldo.TotalCargosAbiertos); // 1 + 2
        Assert.Equal(300m, saldo.SaldoAFavor);     // 200 + 100
        Assert.Equal(2, saldo.Viviendas.Count);
    }

    // =========================================================================
    // 3. GET api/saldos/usuarios/{usuarioId} (Admin)
    // =========================================================================

    [Fact]
    public async Task GetSaldoPorUsuario_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync($"/api/saldos/usuarios/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetSaldoPorUsuario_Inquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/saldos/usuarios/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetSaldoPorUsuario_Subusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/saldos/usuarios/{Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetSaldoPorUsuario_Admin_UsuarioSinViviendas_Retorna200ConCerosSinConsultarVista()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var targetUserId = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.IsAny<string>()))
            .ReturnsAsync(new List<ViviendaResidenteItemDto>());

        var response = await client.GetAsync($"/api/saldos/usuarios/{targetUserId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoUsuarioResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(0m, saldo.TotalPendiente);
        Assert.Empty(saldo.Viviendas);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetAsync<VSaldoVivienda>("v_saldo_vivienda", It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetSaldoPorUsuario_Admin_FiltraPorCondominioDelAdminAdemasDelIn()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var targetUserId = Guid.NewGuid();

        // El usuario tiene 3 viviendas en el sistema: 1, 2, y 99 (99 es de otro condominio)
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.Is<string>(q => q.Contains($"usuario_id=eq.{targetUserId}"))))
            .ReturnsAsync(new List<ViviendaResidenteItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 },
                new() { ViviendaId = 99 }
            });

        // La vista filtra por condominio_id=eq.{condominioId}&vivienda_id=in.(1,2,99)
        // por lo que PostgREST solo devuelve las del condominio del admin (1 y 2)
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}") && q.Contains("vivienda_id=in.(1,2,99)"))))
            .ReturnsAsync(new List<VSaldoVivienda>
            {
                new()
                {
                    ViviendaId = 1,
                    CondominioId = condominioId,
                    NumeroCasa = "101",
                    TotalPendiente = 800m,
                    TotalVencido = 0m,
                    TotalCargosAbiertos = 1,
                    SaldoAFavor = 0m
                },
                new()
                {
                    ViviendaId = 2,
                    CondominioId = condominioId,
                    NumeroCasa = "102",
                    TotalPendiente = 1200m,
                    TotalVencido = 400m,
                    TotalCargosAbiertos = 1,
                    SaldoAFavor = 50m
                }
            });

        var response = await client.GetAsync($"/api/saldos/usuarios/{targetUserId}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var saldo = await response.Content.ReadFromJsonAsync<SaldoUsuarioResponse>();
        Assert.NotNull(saldo);
        Assert.Equal(2000m, saldo.TotalPendiente); // 800 + 1200
        Assert.Equal(400m, saldo.TotalVencido);
        Assert.Equal(2, saldo.TotalCargosAbiertos);
        Assert.Equal(50m, saldo.SaldoAFavor);
        Assert.Equal(2, saldo.Viviendas.Count);

        // Verifica que se incluyó el filtro de condominio en la consulta
        _factory.MockSupabaseRestClient.Verify(
            c => c.GetAsync<VSaldoVivienda>(
                "v_saldo_vivienda",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))),
            Times.Once);
    }

    // =========================================================================
    // 4. GET api/saldos/viviendas/{viviendaId}/movimientos (U2)
    // =========================================================================

    [Fact]
    public async Task GetMovimientosSaldo_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Subusuario_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Admin_ViviendaDeOtroCondominio_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup indica que NO existe en el condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync((ViviendaItemDto?)null);

        var response = await client.GetAsync("/api/saldos/viviendas/99/movimientos");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        // Verifica que no se llamó a la vista
        _factory.MockSupabaseRestClient.Verify(
            c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Inquilino_NoEsResidenteTitular_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lookup indica que no es residente titular
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.IsAny<string>()))
            .ReturnsAsync((ViviendaResidenteItemDto?)null);

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.IsAny<string>()),
            Times.Never);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Admin_ViviendaDeSuCondominio_Retorna200OkPaginado()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Pertenencia confirmada
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.Is<string>(q => q.Contains("id=eq.10") && q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        var movId1 = Guid.NewGuid();
        var movId2 = Guid.NewGuid();
        var pagoId = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("vivienda_id=eq.10") && q.Contains("order=creado_en.desc"))))
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>
            {
                new()
                {
                    Id = movId1,
                    CondominioId = condominioId,
                    ViviendaId = 10,
                    Tipo = TipoMovimientoSaldo.Abono,
                    Monto = 500m,
                    MontoConSigno = 500m,
                    PagoId = pagoId,
                    CargoId = null,
                    MovimientoOrigenId = null,
                    Motivo = "Excedente de pago",
                    CreadoPor = adminId,
                    CreadoEn = DateTimeOffset.UtcNow
                },
                new()
                {
                    Id = movId2,
                    CondominioId = condominioId,
                    ViviendaId = 10,
                    Tipo = TipoMovimientoSaldo.Aplicacion,
                    Monto = 200m,
                    MontoConSigno = -200m,
                    PagoId = null,
                    CargoId = Guid.NewGuid(),
                    MovimientoOrigenId = null,
                    Motivo = "Aplicación a cuota de mantenimiento",
                    CreadoPor = adminId,
                    CreadoEn = DateTimeOffset.UtcNow.AddMinutes(-10)
                }
            }, 2));

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos?pagina=1&tamanoPagina=20");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<MovimientoSaldoResponse>>();
        Assert.NotNull(resultado);
        Assert.Equal(2, resultado.Total);
        Assert.Equal(2, resultado.Items.Count);
        Assert.Equal(TipoMovimientoSaldo.Abono, resultado.Items[0].Tipo);
        Assert.Equal(500m, resultado.Items[0].Monto);
        Assert.Equal(500m, resultado.Items[0].MontoConSigno);
        Assert.Equal(TipoMovimientoSaldo.Aplicacion, resultado.Items[1].Tipo);
        Assert.Equal(200m, resultado.Items[1].Monto);
        Assert.Equal(-200m, resultado.Items[1].MontoConSigno);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Inquilino_ResidenteTitular_Retorna200Ok()
    {
        _factory.MockSupabaseRestClient.Reset();
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Titularidad confirmada
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>(
                "vivienda_residente",
                It.Is<string>(q => q.Contains("vivienda_id=eq.15") && q.Contains($"usuario_id=eq.{inquilinoId}"))))
            .ReturnsAsync(new ViviendaResidenteItemDto { ViviendaId = 15 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("vivienda_id=eq.15"))))
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>(), 0));

        var response = await client.GetAsync("/api/saldos/viviendas/15/movimientos");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<MovimientoSaldoResponse>>();
        Assert.NotNull(resultado);
        Assert.Equal(0, resultado.Total);
        Assert.Empty(resultado.Items);
    }

    [Fact]
    public async Task GetMovimientosSaldo_ConFiltroTipo_AplicaFiltroEnBase()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("vivienda_id=eq.10") && q.Contains("tipo=eq.Abono"))))
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>(), 0));

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos?tipo=Abono");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("tipo=eq.Abono"))),
            Times.Once);
    }

    [Fact]
    public async Task GetMovimientosSaldo_ConFiltroFechas_AplicaFiltroEnBase()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("creado_en=gte.") && q.Contains("creado_en=lte."))))
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>(), 0));

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos?desde=2026-01-01T00:00:00Z&hasta=2026-01-31T23:59:59Z");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains("creado_en=gte.") && q.Contains("creado_en=lte."))),
            Times.Once);
    }

    [Fact]
    public async Task GetMovimientosSaldo_DesdeMayorQueHasta_Retorna400BadRequest()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos?desde=2026-02-01T00:00:00Z&hasta=2026-01-01T00:00:00Z");
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Reversos_IdentificadosPorTipoYMovimientoOrigenId()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        var movimientoOrigenId = Guid.NewGuid();
        var reversoId = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.IsAny<string>()))
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>
            {
                new()
                {
                    Id = reversoId,
                    CondominioId = condominioId,
                    ViviendaId = 10,
                    Tipo = TipoMovimientoSaldo.ReversoAbono,
                    Monto = 500m,
                    MontoConSigno = -500m,
                    PagoId = null,
                    CargoId = null,
                    MovimientoOrigenId = movimientoOrigenId,
                    Motivo = "Anulación de pago",
                    CreadoPor = adminId,
                    CreadoEn = DateTimeOffset.UtcNow
                }
            }, 1));

        var response = await client.GetAsync("/api/saldos/viviendas/10/movimientos");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<MovimientoSaldoResponse>>();
        Assert.NotNull(resultado);
        Assert.Single(resultado.Items);

        var mov = resultado.Items[0];
        Assert.Equal(TipoMovimientoSaldo.ReversoAbono, mov.Tipo);
        Assert.Equal(movimientoOrigenId, mov.MovimientoOrigenId);
        Assert.Equal(-500m, mov.MontoConSigno);
        Assert.Equal(500m, mov.Monto);
    }

    [Fact]
    public async Task GetMovimientosSaldo_Paginacion_RespetaDefault20YMaximo100()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 10 });

        PaginationParams? paramsCapturadosDefault = null;
        PaginationParams? paramsCapturadosMax = null;

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwMovimientoSaldoFavor>(
                "vw_movimientos_saldo_favor",
                It.IsAny<PaginationParams>(),
                It.IsAny<string>()))
            .Callback<string, PaginationParams, string>((_, p, _) =>
            {
                if (paramsCapturadosDefault == null)
                {
                    paramsCapturadosDefault = p;
                }
                else
                {
                    paramsCapturadosMax = p;
                }
            })
            .ReturnsAsync((new List<VwMovimientoSaldoFavor>(), 0));

        // 1. Petición sin parámetros => default Page 1, PageSize 20
        var responseDefault = await client.GetAsync("/api/saldos/viviendas/10/movimientos");
        Assert.Equal(HttpStatusCode.OK, responseDefault.StatusCode);
        Assert.NotNull(paramsCapturadosDefault);
        Assert.Equal(1, paramsCapturadosDefault.Page);
        Assert.Equal(20, paramsCapturadosDefault.PageSize);

        // 2. Petición con tamanoPagina=150 => topa a PageSize 100
        var responseMax = await client.GetAsync("/api/saldos/viviendas/10/movimientos?tamanoPagina=150");
        Assert.Equal(HttpStatusCode.OK, responseMax.StatusCode);
        Assert.NotNull(paramsCapturadosMax);
        Assert.Equal(100, paramsCapturadosMax.PageSize);
    }

    // =========================================================================
    // 5. POST api/saldos/movimientos/{id}/revertir
    // =========================================================================

    [Fact]
    public async Task RevertirAplicacionSaldo_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var movimientoId = Guid.NewGuid();
        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Error en aplicación"
        });
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_InquilinoOSubusuario_Retorna403Forbidden()
    {
        var movimientoId = Guid.NewGuid();
        var request = new RevertirAplicacionSaldoRequest { Motivo = "Error en aplicación" };

        // Inquilino => 403
        var clientInquilino = _factory.CreateClient();
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken();
        clientInquilino.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);
        var responseInquilino = await clientInquilino.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", request);
        Assert.Equal(HttpStatusCode.Forbidden, responseInquilino.StatusCode);

        // Subusuario => 403
        var clientSub = _factory.CreateClient();
        var tokenSub = TestTokenGenerator.GenerateSubusuarioToken();
        clientSub.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenSub);
        var responseSub = await clientSub.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", request);
        Assert.Equal(HttpStatusCode.Forbidden, responseSub.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("1234")] // 4 caracteres (mínimo 5)
    public async Task RevertirAplicacionSaldo_MotivoInvalido_Retorna400BadRequest(string motivoInvalido)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = motivoInvalido
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_MotivoMayorA300Caracteres_Retorna400BadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = new string('x', 301)
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_MovimientoNoExiste_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync((VwMovimientoSaldoFavor?)null);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión por error"
        });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        _factory.MockSupabaseRestClient.Verify(c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_MovimientoDeOtroCondominio_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = otroCondominioId,
                ViviendaId = 1,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 100m
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión por error"
        });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        _factory.MockSupabaseRestClient.Verify(c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Theory]
    [InlineData(TipoMovimientoSaldo.Abono)]
    [InlineData(TipoMovimientoSaldo.ReversoAbono)]
    [InlineData(TipoMovimientoSaldo.ReversoAplicacion)]
    public async Task RevertirAplicacionSaldo_TipoNoAplicacion_Retorna409ConflictSinLlamarRpc(TipoMovimientoSaldo tipoInvalido)
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = tipoInvalido,
                Monto = 200m
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión por cobro indebido"
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        _factory.MockSupabaseRestClient.Verify(c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_RpcRespondePG009_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 200m,
                CargoId = cargoId
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_revertir_aplicacion_saldo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG009", "El movimiento no se puede revertir"));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión de prueba"
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_AdminValido_Retorna200OkConMovimientoCargoYSaldo()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var reversoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 300m,
                CargoId = cargoId
            });

        object? rpcPayloadCapturado = null;
        Guid? actorRpcCapturado = null;

        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{reversoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""tipo"": ""ReversoAplicacion"",
                ""monto"": 300.0,
                ""monto_con_signo"": 300.0,
                ""cargo_id"": ""{cargoId}"",
                ""movimiento_origen_id"": ""{movimientoId}"",
                ""motivo"": ""Aplicación indebida de saldo"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T19:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""condominio_nombre"": ""Condominio Las Palmas"",
                ""vivienda_id"": 10,
                ""numero_casa"": ""101"",
                ""tipo"": ""Mantenimiento"",
                ""concepto"": ""Cuota octubre"",
                ""monto"": 1000.0,
                ""monto_pagado_confirmado"": 0.0,
                ""saldo_pendiente"": 1000.0,
                ""estado"": ""Pendiente"",
                ""fecha_vencimiento"": ""2026-10-31""
            }},
            ""saldo_a_favor"": 500.00
        }}";

        using var jsonDoc = JsonDocument.Parse(jsonResponse);

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_revertir_aplicacion_saldo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actor) =>
            {
                rpcPayloadCapturado = payload;
                actorRpcCapturado = actor;
            })
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RevertirAplicacionSaldoRequest
        {
            Motivo = "Aplicación indebida de saldo"
        };

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, actorRpcCapturado);

        var dict = Assert.IsAssignableFrom<IDictionary<string, object?>>(rpcPayloadCapturado);
        Assert.Equal(movimientoId, dict["p_movimiento_id"]);
        Assert.Equal("Aplicación indebida de saldo", dict["p_motivo"]);
        Assert.Equal(adminId, dict["p_actor_id"]);

        var resultado = await response.Content.ReadFromJsonAsync<RevertirAplicacionSaldoResponse>();
        Assert.NotNull(resultado);
        Assert.NotNull(resultado.Movimiento);
        Assert.Equal(reversoId, resultado.Movimiento.Id);
        Assert.Equal(TipoMovimientoSaldo.ReversoAplicacion, resultado.Movimiento.Tipo);
        Assert.Equal(movimientoId, resultado.Movimiento.MovimientoOrigenId);

        Assert.NotNull(resultado.Cargo);
        Assert.Equal(cargoId, resultado.Cargo.Id);
        Assert.Equal(1000.0m, resultado.Cargo.SaldoPendiente);
        Assert.Equal("101", resultado.Cargo.NumeroCasa);

        Assert.Equal(500.00m, resultado.SaldoAFavor);
    }

    [Fact]
    public async Task RevertirAplicacionSaldo_CargoSinCamposCalculadosEnRpc_ReleeDeVwCargos()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var reversoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 300m,
                CargoId = cargoId
            });

        // La RPC devuelve el nodo cargo crudo (sin numero_casa ni condominio_nombre)
        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{reversoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""tipo"": ""ReversoAplicacion"",
                ""monto"": 300.0,
                ""monto_con_signo"": 300.0,
                ""cargo_id"": ""{cargoId}"",
                ""movimiento_origen_id"": ""{movimientoId}"",
                ""motivo"": ""Reversión requerida"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T19:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""monto"": 1000.0
            }},
            ""saldo_a_favor"": 600.00
        }}";

        using var jsonDoc = JsonDocument.Parse(jsonResponse);

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_revertir_aplicacion_saldo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ReturnsAsync(jsonDoc.RootElement);

        // Relectura de vw_cargos por falta de campos calculados
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                CondominioNombre = "Condominio Las Palmas",
                ViviendaId = 10,
                NumeroCasa = "Casa 10-A",
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota octubre",
                Monto = 1000m,
                MontoPagadoConfirmado = 0m,
                SaldoPendiente = 1000m,
                Estado = EstadoCargo.Pendiente,
                FechaVencimiento = DateOnly.FromDateTime(DateTime.UtcNow.AddDays(10))
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión requerida"
        };

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var resultado = await response.Content.ReadFromJsonAsync<RevertirAplicacionSaldoResponse>();
        Assert.NotNull(resultado);
        Assert.NotNull(resultado.Cargo);
        Assert.Equal("Casa 10-A", resultado.Cargo.NumeroCasa);
        Assert.Equal(EstadoCargo.Pendiente, resultado.Cargo.Estado);
        Assert.Equal(1000m, resultado.Cargo.SaldoPendiente);

        _factory.MockSupabaseRestClient.Verify(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"), Times.Once);
    }
}
