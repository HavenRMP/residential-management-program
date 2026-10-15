using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Moq;
using Xunit;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using Reservas.Api.DTOs;
using Reservas.Api.Services;

namespace Reservas.Api.Tests;

public class AdminReservasYBloqueosControllerTests : IClassFixture<ReservasApiFactory>
{
    private readonly ReservasApiFactory _factory;

    public AdminReservasYBloqueosControllerTests(ReservasApiFactory factory)
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

    private HttpClient CreateAuthenticatedClient(Guid userId)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateFakeToken(userId);
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return client;
    }

    private static async Task AssertErrorResponseAsync(HttpResponseMessage response, HttpStatusCode expectedStatus, string expectedErrorMessage)
    {
        Assert.Equal(expectedStatus, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.True(doc.RootElement.TryGetProperty("error", out var errorProp));
        Assert.Equal(expectedErrorMessage, errorProp.GetString());
    }

    #region 1. Control de Acceso y Autenticación en Endpoints Admin

    [Theory]
    [InlineData("/api/admin/reservas", "GET")]
    [InlineData("/api/admin/reservas/no-shows", "GET")]
    [InlineData("/api/admin/reservas/00000000-0000-0000-0000-000000000001/aprobar", "POST")]
    [InlineData("/api/admin/reservas/00000000-0000-0000-0000-000000000001/rechazar", "POST")]
    [InlineData("/api/admin/reservas/00000000-0000-0000-0000-000000000001/cancelar", "POST")]
    [InlineData("/api/admin/reservas/00000000-0000-0000-0000-000000000001/no-utilizada", "POST")]
    [InlineData("/api/admin/bloqueos", "POST")]
    public async Task EndpointsAdmin_SinToken_Retorna401(string url, string method)
    {
        var client = _factory.CreateClient();
        HttpResponseMessage response;

        if (method == "GET")
        {
            response = await client.GetAsync(url);
        }
        else
        {
            response = await client.PostAsJsonAsync(url, new { });
        }

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("Residente")]
    [InlineData("Vigilancia")]
    [InlineData("Mantenimiento")]
    public async Task EndpointsAdmin_RolesNoAdmin_Retorna403(string rol)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, rol, Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var getResponse = await client.GetAsync("/api/admin/reservas");
        var postResponse = await client.PostAsJsonAsync(
            $"/api/admin/reservas/{Guid.NewGuid()}/aprobar",
            new { });
        var bloqueoResponse = await client.PostAsJsonAsync(
            "/api/admin/bloqueos",
            new { areaId = Guid.NewGuid(), inicio = DateTimeOffset.UtcNow, fin = DateTimeOffset.UtcNow.AddHours(2), motivo = "Mantenimiento" });

        Assert.Equal(HttpStatusCode.Forbidden, getResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, postResponse.StatusCode);
        Assert.Equal(HttpStatusCode.Forbidden, bloqueoResponse.StatusCode);
    }

    [Fact]
    public async Task EndpointsAdmin_AdminSinCondominio_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", null);
        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/admin/reservas");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    #region 2. GET api/admin/reservas

    [Fact]
    public async Task GetReservasAdmin_Admin_Retorna200EIncluyeNoShows()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        var reserva = new ReservaAdminDto
        {
            Id = Guid.NewGuid(),
            AreaId = Guid.NewGuid(),
            AreaNombre = "Cancha de Tenis",
            CondominioId = condominioId,
            Tipo = "reserva",
            Estado = "aprobada",
            Inicio = DateTimeOffset.UtcNow,
            Fin = DateTimeOffset.UtcNow.AddHours(2),
            TitularNombre = "Carlos",
            TitularApellidos = "Mendoza",
            NoShowsTitular = 3,
            NoShowsSolicitante = 1
        };

        _factory.MockSupabaseService
            .Setup(s => s.GetReservasAdminAsync(condominioId, null, null, null, null, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<ReservaAdminDto> { reserva }, 1));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/admin/reservas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        var items = doc.RootElement.GetProperty("items");
        Assert.Equal(1, items.GetArrayLength());

        var primerItem = items[0];
        Assert.True(primerItem.TryGetProperty("noShowsTitular", out var noShowsTitularProp));
        Assert.Equal(3, noShowsTitularProp.GetInt32());

        Assert.True(primerItem.TryGetProperty("noShowsSolicitante", out var noShowsSolicitanteProp));
        Assert.Equal(1, noShowsSolicitanteProp.GetInt32());
    }

    [Fact]
    public async Task GetReservasAdmin_ConFiltros_LleganAlServicio()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        var from = DateTimeOffset.UtcNow.Date;
        var to = from.AddDays(15);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservasAdminAsync(condominioId, "pendiente_admin", areaId, from, to, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<ReservaAdminDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var fromStr = Uri.EscapeDataString(from.ToString("o"));
        var toStr = Uri.EscapeDataString(to.ToString("o"));

        var response = await client.GetAsync($"/api/admin/reservas?estado=pendiente_admin&areaId={areaId}&from={fromStr}&to={toStr}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(
            s => s.GetReservasAdminAsync(condominioId, "pendiente_admin", areaId, from, to, It.IsAny<PaginationParams>()),
            Times.Once);
    }

    #endregion

    #region 3. Acciones de Administración (Aprobar, Rechazar, Cancelar, No-Utilizada)

    [Fact]
    public async Task AprobarReserva_AdminServicioTrue_Retorna204()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaAdminAsync(userId, reservaId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/aprobar", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.AprobarReservaAdminAsync(userId, reservaId), Times.Once);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task RechazarReserva_SinMotivoOConMotivoVacio_Retorna400(string? motivo)
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        HttpResponseMessage response;
        if (motivo == null)
        {
            response = await client.PostAsync(
                $"/api/admin/reservas/{reservaId}/rechazar",
                new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));
        }
        else
        {
            response = await client.PostAsJsonAsync(
                $"/api/admin/reservas/{reservaId}/rechazar",
                new MotivoObligatorioRequestDto { Motivo = motivo });
        }

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RechazarReserva_ConMotivoValido_Retorna204YMockRecibeMotivo()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        const string motivo = "Área saturada en ese horario";
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.RechazarReservaAdminAsync(userId, reservaId, motivo))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync(
            $"/api/admin/reservas/{reservaId}/rechazar",
            new MotivoObligatorioRequestDto { Motivo = motivo });

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.RechazarReservaAdminAsync(userId, reservaId, motivo), Times.Once);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CancelarReserva_SinMotivoOConMotivoVacio_Retorna400(string? motivo)
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        HttpResponseMessage response;
        if (motivo == null)
        {
            response = await client.PostAsync(
                $"/api/admin/reservas/{reservaId}/cancelar",
                new StringContent("{}", System.Text.Encoding.UTF8, "application/json"));
        }
        else
        {
            response = await client.PostAsJsonAsync(
                $"/api/admin/reservas/{reservaId}/cancelar",
                new MotivoObligatorioRequestDto { Motivo = motivo });
        }

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CancelarReserva_ConMotivoValido_Retorna204YMockRecibeMotivo()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        const string motivo = "Mantenimiento urgente de bomba de agua";
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAdminAsync(userId, reservaId, motivo))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync(
            $"/api/admin/reservas/{reservaId}/cancelar",
            new MotivoObligatorioRequestDto { Motivo = motivo });

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.CancelarReservaAdminAsync(userId, reservaId, motivo), Times.Once);
    }

    [Fact]
    public async Task MarcarNoUtilizada_AdminServicioTrue_Retorna204()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.MarcarNoUtilizadaAsync(userId, reservaId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/no-utilizada", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.MarcarNoUtilizadaAsync(userId, reservaId), Times.Once);
    }

    [Theory]
    [InlineData("aprobar")]
    [InlineData("no-utilizada")]
    public async Task AccionesAdmin_ServicioDevuelveFalse_Retorna400(string accion)
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaAdminAsync(userId, reservaId))
            .ReturnsAsync(false);
        _factory.MockSupabaseService
            .Setup(s => s.MarcarNoUtilizadaAsync(userId, reservaId))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/{accion}", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    #endregion

    #region 4. Mapeo de Errores RPC de Administración (RE013, RE004, RE009)

    [Fact]
    public async Task MarcarNoUtilizada_ErrorRpcRE013_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.MarcarNoUtilizadaAsync(userId, reservaId))
            .ThrowsAsync(new SupabaseRpcException("RE013", "Aún no termina"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/no-utilizada", null);

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.Conflict,
            "La reserva aún no termina, no puede marcarse como no utilizada.");
    }

    [Fact]
    public async Task AprobarReserva_ErrorRpcRE004_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaAdminAsync(userId, reservaId))
            .ThrowsAsync(new SupabaseRpcException("RE004", "Estado no permite"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/aprobar", null);

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.Conflict,
            "El estado de la reserva no permite esta operación.");
    }

    [Fact]
    public async Task CancelarReserva_SiEsBloqueo_Retorna400BadRequest()
    {
        var userId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto { Id = bloqueoId, Tipo = "BLOQUEO" });

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync(
            $"/api/admin/reservas/{bloqueoId}/cancelar",
            new MotivoObligatorioRequestDto { Motivo = "Cancelar bloqueo" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.BadRequest,
            "No se puede cancelar un bloqueo a través de este endpoint.");
    }

    [Fact]
    public async Task CancelarReserva_ErrorRpcNT001_Retorna404ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(reservaId, condominioId))
            .ReturnsAsync(new ReservaAdminDto { Id = reservaId, Tipo = "RESERVA" });

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAdminAsync(userId, reservaId, "Motivo"))
            .ThrowsAsync(new SupabaseRpcException("NT001", "Usuario no existe"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync(
            $"/api/admin/reservas/{reservaId}/cancelar",
            new MotivoObligatorioRequestDto { Motivo = "Motivo" });

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.NotFound,
            "El usuario destinatario no existe.");
    }

    [Fact]
    public async Task AprobarReserva_ErrorRpcRE009_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaAdminAsync(userId, reservaId))
            .ThrowsAsync(new SupabaseRpcException("RE009", "Choque de horario"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/reservas/{reservaId}/aprobar", null);

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.Conflict,
            "El horario choca con otra reserva aprobada o con un bloqueo del área.");
    }

    #endregion

    #region 5. GET api/admin/reservas/no-shows

    [Fact]
    public async Task GetNoShows_ConTitularId_Retorna200YFiltraPorTitular()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var titularId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetNoShowsAsync(condominioId, titularId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<NoShowDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync($"/api/admin/reservas/no-shows?titularId={titularId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetNoShowsAsync(condominioId, titularId, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetNoShows_SinTitularId_Retorna200YTraeTodosLosDelCondominio()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetNoShowsAsync(condominioId, null, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<NoShowDto>(), 0));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync("/api/admin/reservas/no-shows");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetNoShowsAsync(condominioId, null, It.IsAny<PaginationParams>()), Times.Once);
    }

    #endregion

    #region 6. POST api/admin/bloqueos (CrearBloqueo)

    [Fact]
    public async Task CrearBloqueo_AdminConBodyValido_Retorna201YRespuestaIncluyeReservasAfectadas()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var inicio = DateTimeOffset.UtcNow.AddDays(5);
        var fin = inicio.AddHours(8);
        const string motivo = "Mantenimiento general de alberca";

        SetupUserContext(userId, "Administrador", condominioId);

        var resultadoDto = new BloqueoResultadoDto
        {
            BloqueoId = Guid.NewGuid(),
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin,
            Motivo = motivo,
            ReservasAfectadas = 4
        };

        _factory.MockSupabaseService
            .Setup(s => s.CrearBloqueoAsync(userId, areaId, inicio, fin, motivo))
            .ReturnsAsync(resultadoDto);

        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin,
            Motivo = motivo
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.True(doc.RootElement.TryGetProperty("reservasAfectadas", out var afectadasProp));
        Assert.Equal(4, afectadasProp.GetInt32());

        _factory.MockSupabaseService.Verify(s => s.CrearBloqueoAsync(userId, areaId, inicio, fin, motivo), Times.Once);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CrearBloqueo_SinMotivoOConMotivoVacio_Retorna400(string? motivo)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(5),
            Fin = DateTimeOffset.UtcNow.AddDays(5).AddHours(4),
            Motivo = motivo!
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]   // Fin == Inicio
    [InlineData(-1)]  // Fin < Inicio
    public async Task CrearBloqueo_FinMenorOIgualAInicio_Retorna400(int horasDiferencia)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var inicio = DateTimeOffset.UtcNow.AddDays(5);
        var fin = inicio.AddHours(horasDiferencia);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = inicio,
            Fin = fin,
            Motivo = "Reparación de piso"
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CrearBloqueo_RolResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(5),
            Fin = DateTimeOffset.UtcNow.AddDays(5).AddHours(4),
            Motivo = "Bloqueo no autorizado"
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CrearBloqueo_ErrorRpcRE001_Retorna404ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var inicio = DateTimeOffset.UtcNow.AddDays(5);
        var fin = inicio.AddHours(4);
        const string motivo = "Mantenimiento";

        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CrearBloqueoAsync(userId, areaId, inicio, fin, motivo))
            .ThrowsAsync(new SupabaseRpcException("RE001", "Area no existe"));

        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin,
            Motivo = motivo
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.NotFound, "El área común no existe o está inactiva.");
    }

    [Fact]
    public async Task CrearBloqueo_ServicioDevuelveNull_Retorna400()
    {
        var userId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var inicio = DateTimeOffset.UtcNow.AddDays(5);
        var fin = inicio.AddHours(4);
        const string motivo = "Mantenimiento";

        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CrearBloqueoAsync(userId, areaId, inicio, fin, motivo))
            .ReturnsAsync((BloqueoResultadoDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearBloqueoRequestDto
        {
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin,
            Motivo = motivo
        };

        var response = await client.PostAsJsonAsync("/api/admin/bloqueos", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "No se pudo crear el bloqueo");
    }

    #endregion

    #region 7. GET api/admin/bloqueos/{id} (GetBloqueo)

    [Fact]
    public async Task GetBloqueo_AdminConBloqueoExistente_Retorna200YDatos()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var areaId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                AreaId = areaId,
                AreaNombre = "Piscina",
                Tipo = "BLOQUEO",
                Inicio = DateTimeOffset.UtcNow.AddDays(2),
                Fin = DateTimeOffset.UtcNow.AddDays(2).AddHours(4),
                Motivo = "Limpieza profunda",
                Estado = "APROBADA"
            });

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync($"/api/admin/bloqueos/{bloqueoId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.Equal(bloqueoId.ToString(), doc.RootElement.GetProperty("bloqueoId").GetString());
        Assert.Equal("Limpieza profunda", doc.RootElement.GetProperty("motivo").GetString());
    }

    [Fact]
    public async Task GetBloqueo_NoExiste_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync((ReservaAdminDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync($"/api/admin/bloqueos/{bloqueoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetBloqueo_ExistePeroEsReserva_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(reservaId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = reservaId,
                Tipo = "RESERVA"
            });

        var client = CreateAuthenticatedClient(userId);

        var response = await client.GetAsync($"/api/admin/bloqueos/{reservaId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    #endregion

    #region 8. PATCH / PUT api/admin/bloqueos/{id} (ActualizarBloqueo)

    [Fact]
    public async Task ActualizarBloqueo_AdminConDatosValidos_Retorna200YDatosActualizados()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var nuevoInicio = DateTimeOffset.UtcNow.AddDays(3);
        var nuevoFin = nuevoInicio.AddHours(5);
        const string nuevoMotivo = "Mantenimiento extendido";

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                AreaId = areaId,
                Tipo = "BLOQUEO",
                Inicio = DateTimeOffset.UtcNow.AddDays(2),
                Fin = DateTimeOffset.UtcNow.AddDays(2).AddHours(2),
                Motivo = "Mantenimiento previo"
            });

        _factory.MockSupabaseService
            .Setup(s => s.ActualizarBloqueoAsync(userId, bloqueoId, nuevoInicio, nuevoFin, nuevoMotivo))
            .ReturnsAsync(new BloqueoResultadoDto
            {
                BloqueoId = bloqueoId,
                AreaId = areaId,
                Inicio = nuevoInicio,
                Fin = nuevoFin,
                Motivo = nuevoMotivo
            });

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto
        {
            Inicio = nuevoInicio,
            Fin = nuevoFin,
            Motivo = nuevoMotivo
        };

        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.Equal(nuevoMotivo, doc.RootElement.GetProperty("motivo").GetString());
    }

    [Fact]
    public async Task ActualizarBloqueo_NoExiste_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync((ReservaAdminDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto { Motivo = "Cualquier motivo" };
        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarBloqueo_NoEsBloqueo_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var id = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(id, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = id,
                Tipo = "RESERVA"
            });

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto { Motivo = "Cambio motivo" };
        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{id}", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarBloqueo_FinMenorAInicio_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto
        {
            Inicio = DateTimeOffset.UtcNow.AddDays(3),
            Fin = DateTimeOffset.UtcNow.AddDays(2)
        };

        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarBloqueo_MotivoSoloEspacios_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto
        {
            Motivo = "    "
        };

        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarBloqueo_ViaHttpPut_Retorna200YDatosActualizados()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var nuevoInicio = DateTimeOffset.UtcNow.AddDays(4);
        var nuevoFin = nuevoInicio.AddHours(3);
        const string nuevoMotivo = "Mantenimiento con PUT";

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                AreaId = areaId,
                Tipo = "BLOQUEO",
                Inicio = DateTimeOffset.UtcNow.AddDays(3),
                Fin = DateTimeOffset.UtcNow.AddDays(3).AddHours(2),
                Motivo = "Motivo viejo"
            });

        _factory.MockSupabaseService
            .Setup(s => s.ActualizarBloqueoAsync(userId, bloqueoId, nuevoInicio, nuevoFin, nuevoMotivo))
            .ReturnsAsync(new BloqueoResultadoDto
            {
                BloqueoId = bloqueoId,
                AreaId = areaId,
                Inicio = nuevoInicio,
                Fin = nuevoFin,
                Motivo = nuevoMotivo
            });

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto
        {
            Inicio = nuevoInicio,
            Fin = nuevoFin,
            Motivo = nuevoMotivo
        };

        var response = await client.PutAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.Equal(nuevoMotivo, doc.RootElement.GetProperty("motivo").GetString());
    }

    [Fact]
    public async Task ActualizarBloqueo_ServicioDevuelveNull_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var areaId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                AreaId = areaId,
                Tipo = "BLOQUEO",
                Inicio = DateTimeOffset.UtcNow.AddDays(1),
                Fin = DateTimeOffset.UtcNow.AddDays(1).AddHours(2)
            });

        _factory.MockSupabaseService
            .Setup(s => s.ActualizarBloqueoAsync(userId, bloqueoId, It.IsAny<DateTimeOffset?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<string?>()))
            .ReturnsAsync((BloqueoResultadoDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto { Motivo = "Nuevo motivo" };
        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "No se pudo actualizar el bloqueo");
    }

    [Fact]
    public async Task ActualizarBloqueo_ErrorRpcRE009_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();
        var areaId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                AreaId = areaId,
                Tipo = "BLOQUEO",
                Inicio = DateTimeOffset.UtcNow.AddDays(1),
                Fin = DateTimeOffset.UtcNow.AddDays(1).AddHours(2)
            });

        _factory.MockSupabaseService
            .Setup(s => s.ActualizarBloqueoAsync(userId, bloqueoId, It.IsAny<DateTimeOffset?>(), It.IsAny<DateTimeOffset?>(), It.IsAny<string?>()))
            .ThrowsAsync(new SupabaseRpcException("RE009", "Choque con otra reserva"));

        var client = CreateAuthenticatedClient(userId);

        var dto = new ActualizarBloqueoRequestDto { Motivo = "Nuevo motivo" };
        var response = await client.PatchAsJsonAsync($"/api/admin/bloqueos/{bloqueoId}", dto);

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.Conflict,
            "El horario choca con otra reserva aprobada o con un bloqueo del área.");
    }

    #endregion

    #region 9. DELETE api/admin/bloqueos/{id} (EliminarBloqueo)

    [Fact]
    public async Task EliminarBloqueo_AdminConIdValido_Retorna204NoContent()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                Tipo = "BLOQUEO"
            });

        _factory.MockSupabaseService
            .Setup(s => s.EliminarBloqueoAsync(userId, bloqueoId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{bloqueoId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.EliminarBloqueoAsync(userId, bloqueoId), Times.Once);
    }

    [Fact]
    public async Task EliminarBloqueo_ViaPostCancelar_Retorna204NoContent()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                Tipo = "BLOQUEO"
            });

        _factory.MockSupabaseService
            .Setup(s => s.EliminarBloqueoAsync(userId, bloqueoId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/admin/bloqueos/{bloqueoId}/cancelar", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.EliminarBloqueoAsync(userId, bloqueoId), Times.Once);
    }

    [Fact]
    public async Task EliminarBloqueo_NoExiste_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync((ReservaAdminDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{bloqueoId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task EliminarBloqueo_NoEsBloqueo_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var id = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(id, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = id,
                Tipo = "RESERVA"
            });

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{id}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task EliminarBloqueo_RolResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Residente", Guid.NewGuid());

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{bloqueoId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task EliminarBloqueo_ServicioDevuelveFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                Tipo = "BLOQUEO"
            });

        _factory.MockSupabaseService
            .Setup(s => s.EliminarBloqueoAsync(userId, bloqueoId))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{bloqueoId}");

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "No se pudo eliminar el bloqueo");
    }

    [Fact]
    public async Task EliminarBloqueo_ErrorRpcRE004_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var bloqueoId = Guid.NewGuid();

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService
            .Setup(s => s.GetReservaAdminByIdAsync(bloqueoId, condominioId))
            .ReturnsAsync(new ReservaAdminDto
            {
                Id = bloqueoId,
                Tipo = "BLOQUEO"
            });

        _factory.MockSupabaseService
            .Setup(s => s.EliminarBloqueoAsync(userId, bloqueoId))
            .ThrowsAsync(new SupabaseRpcException("RE004", "El estado no permite"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.DeleteAsync($"/api/admin/bloqueos/{bloqueoId}");

        await AssertErrorResponseAsync(
            response,
            HttpStatusCode.Conflict,
            "El estado de la reserva no permite esta operación.");
    }

    #endregion
}
