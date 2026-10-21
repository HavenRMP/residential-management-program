using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Models;
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
}
