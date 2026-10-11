using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using System.Threading.Tasks;
using Moq;
using Xunit;
using HavenApi.Shared.Pagination;
using Reservas.Api.DTOs;
using Reservas.Api.Services;

namespace Reservas.Api.Tests;

public class ReservasLecturaControllerTests : IClassFixture<ReservasApiFactory>
{
    private readonly ReservasApiFactory _factory;

    public ReservasLecturaControllerTests(ReservasApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseService.Invocations.Clear();
    }

    private void SetupUserContext(Guid userId, string? rol, Guid? condominioId)
    {
        _factory.MockSupabaseService
            .Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((rol, condominioId));
    }

    private System.Net.Http.HttpClient CreateAuthenticatedClient(Guid userId)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateFakeToken(userId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    #region 1. Validaciones de Fechas y Token en Calendario

    [Fact]
    public async Task GetCalendario_SinToken_Retorna401()
    {
        var client = _factory.CreateClient();
        var from = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var to = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={from}&to={to}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetCalendario_SinFrom_Retorna400()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var to = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));
        var response = await client.GetAsync($"/api/reservas/calendario?to={to}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetCalendario_SinTo_Retorna400()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var from = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var response = await client.GetAsync($"/api/reservas/calendario?from={from}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]   // to == from
    [InlineData(-1)]  // to < from
    public async Task GetCalendario_ToMenorOIgualAFrom_Retorna400(int diasDiferencia)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var inicio = DateTimeOffset.UtcNow;
        var fin = inicio.AddDays(diasDiferencia);

        var fromStr = Uri.EscapeDataString(inicio.ToString("o"));
        var toStr = Uri.EscapeDataString(fin.ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetCalendario_RangoDe63Dias_Retorna400()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var inicio = new DateTimeOffset(2026, 10, 1, 0, 0, 0, TimeSpan.Zero);
        var fin = inicio.AddDays(63);

        var fromStr = Uri.EscapeDataString(inicio.ToString("o"));
        var toStr = Uri.EscapeDataString(fin.ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetCalendario_RangoDeExactamente62Dias_Retorna200()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var inicio = new DateTimeOffset(2026, 10, 1, 0, 0, 0, TimeSpan.Zero);
        var fin = inicio.AddDays(62);

        var fromStr = Uri.EscapeDataString(inicio.ToString("o"));
        var toStr = Uri.EscapeDataString(fin.ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    #endregion

    #region 2. Roles y Autorización en Calendario

    [Fact]
    public async Task GetCalendario_ConResidente_InvocaCalendarioGeneralConLimitadoFalso()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(
            s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), false, It.IsAny<PaginationParams>()),
            Times.Once);
    }

    [Theory]
    [InlineData("Vigilancia")]
    [InlineData("Mantenimiento")]
    public async Task GetCalendario_ConRolSoloLectura_InvocaCalendarioGeneralConLimitadoVerdadero(string rol)
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, rol, condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), true, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(
            s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), true, It.IsAny<PaginationParams>()),
            Times.Once);
    }

    [Fact]
    public async Task GetCalendario_ConAdministrador_InvocaCalendarioAdmin()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAdminAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<ReservaAdminDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(
            s => s.GetCalendarioAdminAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), It.IsAny<PaginationParams>()),
            Times.Once);
    }

    [Fact]
    public async Task GetCalendario_ConRolDesconocido_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "RolDesconocido", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetCalendario_UsuarioSinCondominio_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", null);
        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    #region 3. Filtro por AreaId

    [Fact]
    public async Task GetCalendario_ConAreaId_MockRecibeAreaId()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), areaId, false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}&areaId={areaId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(
            s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), areaId, false, It.IsAny<PaginationParams>()),
            Times.Once);
    }

    #endregion

    #region 4. Contenido Seguro en Respuesta de Calendario de Residente

    [Fact]
    public async Task GetCalendario_RespuestaResidente_NoContieneDatosSensiblesNiNoShows()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        var reserva = new CalendarioReservaDto
        {
            Id = Guid.NewGuid(),
            AreaId = Guid.NewGuid(),
            AreaNombre = "Palapa Principal",
            Tipo = "reserva",
            Estado = "aprobada",
            Inicio = DateTimeOffset.UtcNow,
            Fin = DateTimeOffset.UtcNow.AddHours(3),
            TitularNombre = "Juan",
            TitularApellidos = "Pérez",
            NumeroCasa = "15-A",
            Motivo = "Reunión familiar"
        };

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto> { reserva }, 1));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.ToString("o"));
        var toStr = Uri.EscapeDataString(DateTimeOffset.UtcNow.AddDays(7).ToString("o"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var root = doc.RootElement;
        var items = root.GetProperty("items");
        Assert.Equal(1, items.GetArrayLength());

        var primerItem = items[0];

        // Debe contener motivo
        Assert.True(primerItem.TryGetProperty("motivo", out var motivoProp));
        Assert.Equal("Reunión familiar", motivoProp.GetString());

        // NO debe contener datos personales del solicitante, teléfonos, correos ni conteo de no-shows
        Assert.False(primerItem.TryGetProperty("solicitanteNombre", out _));
        Assert.False(primerItem.TryGetProperty("telefono", out _));
        Assert.False(primerItem.TryGetProperty("email", out _));
        Assert.False(primerItem.TryGetProperty("noShowsTitular", out _));
        Assert.False(primerItem.TryGetProperty("noShowsSolicitante", out _));
    }

    #endregion

    #region 5. Endpoints Mias y Por-Aprobar-Titular

    [Fact]
    public async Task GetMisReservas_RolResidente_Retorna200()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetMisReservasAsync(userId, It.IsAny<string?>(), It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<ReservaUsuarioDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/reservas/mias");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetMisReservasAsync(userId, null, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetMisReservas_RolAdministrador_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/reservas/mias");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetPendientesTitular_RolResidente_Retorna200()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetPendientesTitularAsync(userId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<PendienteTitularDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/reservas/por-aprobar-titular");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetPendientesTitularAsync(userId, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetPendientesTitular_RolVigilancia_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Vigilancia", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/reservas/por-aprobar-titular");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    #region 6. Parámetros de Fecha Llegan al Servicio en UTC

    [Fact]
    public async Task GetCalendario_ParametrosDeFecha_LleganAlServicioEnUtc()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetCalendarioAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), It.IsAny<Guid?>(), false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<CalendarioReservaDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        // Enviamos fechas con offset explícito no-cero (ej. UTC-5)
        var fromOffset = DateTimeOffset.Parse("2026-10-01T10:00:00-05:00");
        var toOffset = DateTimeOffset.Parse("2026-10-05T10:00:00-05:00");

        var fromStr = Uri.EscapeDataString(fromOffset.ToString("yyyy-MM-ddTHH:mm:sszzz"));
        var toStr = Uri.EscapeDataString(toOffset.ToString("yyyy-MM-ddTHH:mm:sszzz"));

        var response = await client.GetAsync($"/api/reservas/calendario?from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        // Verificamos que las fechas que recibió el mock de servicio tengan Offset cero (UTC)
        _factory.MockSupabaseService.Verify(
            s => s.GetCalendarioAsync(
                condominioId,
                It.Is<DateTimeOffset>(d => d.Offset == TimeSpan.Zero && d.UtcDateTime == fromOffset.UtcDateTime),
                It.Is<DateTimeOffset>(d => d.Offset == TimeSpan.Zero && d.UtcDateTime == toOffset.UtcDateTime),
                null,
                false,
                It.IsAny<PaginationParams>()),
            Times.Once);
    }

    #endregion
}
