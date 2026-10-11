using System;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Moq;
using Xunit;
using HavenApi.Shared.Exceptions;
using Reservas.Api.DTOs;
using Reservas.Api.Services;

namespace Reservas.Api.Tests;

public class ReservasEscrituraControllerTests : IClassFixture<ReservasApiFactory>
{
    private readonly ReservasApiFactory _factory;

    public ReservasEscrituraControllerTests(ReservasApiFactory factory)
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

    #region 1. POST api/reservas (SolicitarReserva)

    [Fact]
    public async Task SolicitarReserva_SinToken_Retorna401()
    {
        var client = _factory.CreateClient();
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(8),
            Fin = DateTimeOffset.UtcNow.AddDays(8).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("Administrador")]
    [InlineData("Vigilancia")]
    public async Task SolicitarReserva_RolNoPermitido_Retorna403(string rol)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, rol, Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(8),
            Fin = DateTimeOffset.UtcNow.AddDays(8).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task SolicitarReserva_ResidenteConBodyValido_Retorna201YMockRecibeParametros()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", condominioId);

        var areaId = Guid.NewGuid();
        var inicio = DateTimeOffset.UtcNow.AddDays(10);
        var fin = inicio.AddHours(3);

        var dto = new CrearReservaRequestDto
        {
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin
        };

        var reservaCreada = new ReservaUsuarioDto
        {
            Id = Guid.NewGuid(),
            AreaId = areaId,
            CondominioId = condominioId,
            Inicio = inicio,
            Fin = fin,
            SolicitanteId = userId,
            Estado = "pendiente_titular"
        };

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, areaId, inicio, fin))
            .ReturnsAsync(reservaCreada);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.SolicitarReservaAsync(userId, areaId, inicio, fin), Times.Once);
    }

    [Fact]
    public async Task SolicitarReserva_SinAreaId_Retorna400()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var dto = new CrearReservaRequestDto
        {
            AreaId = null,
            Inicio = DateTimeOffset.UtcNow.AddDays(8),
            Fin = DateTimeOffset.UtcNow.AddDays(8).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]   // Fin == Inicio
    [InlineData(-1)]  // Fin < Inicio
    public async Task SolicitarReserva_FinMenorOIgualAInicio_Retorna400(int horasDiferencia)
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());
        var client = CreateAuthenticatedClient(userId);

        var inicio = DateTimeOffset.UtcNow.AddDays(8);
        var fin = inicio.AddHours(horasDiferencia);

        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = inicio,
            Fin = fin
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task SolicitarReserva_ServicioDevuelveNull_Retorna400()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        var areaId = Guid.NewGuid();
        var inicio = DateTimeOffset.UtcNow.AddDays(10);
        var fin = inicio.AddHours(2);

        var dto = new CrearReservaRequestDto
        {
            AreaId = areaId,
            Inicio = inicio,
            Fin = fin
        };

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, areaId, inicio, fin))
            .ReturnsAsync((ReservaUsuarioDto?)null);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "No se pudo crear la reserva");
    }

    #endregion

    #region 2. Aprobar, Rechazar, Confirmar y Cancelar

    [Fact]
    public async Task AprobarTitular_ResidenteServicioTrue_Retorna204()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaTitularAsync(userId, reservaId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/aprobar-titular", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.AprobarReservaTitularAsync(userId, reservaId), Times.Once);
    }

    [Fact]
    public async Task AprobarTitular_ResidenteServicioFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.AprobarReservaTitularAsync(userId, reservaId))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/aprobar-titular", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task AprobarTitular_RolNoResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/aprobar-titular", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task RechazarTitular_ResidenteConBody_Retorna204YMockRecibeMotivo()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        const string motivo = "Fecha no disponible para el titular";
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.RechazarReservaTitularAsync(userId, reservaId, motivo))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync($"/api/reservas/{reservaId}/rechazar-titular", new MotivoOpcionalRequestDto { Motivo = motivo });

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.RechazarReservaTitularAsync(userId, reservaId, motivo), Times.Once);
    }

    [Fact]
    public async Task RechazarTitular_ResidenteSinBody_Retorna204YMockRecibeMotivoNull()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.RechazarReservaTitularAsync(userId, reservaId, null))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/rechazar-titular", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.RechazarReservaTitularAsync(userId, reservaId, null), Times.Once);
    }

    [Fact]
    public async Task RechazarTitular_ResidenteServicioFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.RechazarReservaTitularAsync(userId, reservaId, It.IsAny<string?>()))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/rechazar-titular", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RechazarTitular_RolNoResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Vigilancia", Guid.NewGuid());

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/rechazar-titular", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ConfirmarReserva_ResidenteServicioTrue_Retorna204()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.ConfirmarReservaAsync(userId, reservaId))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/confirmar", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.ConfirmarReservaAsync(userId, reservaId), Times.Once);
    }

    [Fact]
    public async Task ConfirmarReserva_ResidenteServicioFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.ConfirmarReservaAsync(userId, reservaId))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/confirmar", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ConfirmarReserva_RolNoResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Administrador", Guid.NewGuid());

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/confirmar", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CancelarReserva_ResidenteConBody_Retorna204YMockRecibeMotivo()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        const string motivo = "Imprevisto familiar";
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAsync(userId, reservaId, motivo))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsJsonAsync($"/api/reservas/{reservaId}/cancelar", new MotivoOpcionalRequestDto { Motivo = motivo });

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.CancelarReservaAsync(userId, reservaId, motivo), Times.Once);
    }

    [Fact]
    public async Task CancelarReserva_ResidenteSinBody_Retorna204YMockRecibeMotivoNull()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAsync(userId, reservaId, null))
            .ReturnsAsync(true);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.CancelarReservaAsync(userId, reservaId, null), Times.Once);
    }

    [Fact]
    public async Task CancelarReserva_ResidenteServicioFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAsync(userId, reservaId, It.IsAny<string?>()))
            .ReturnsAsync(false);

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task CancelarReserva_RolNoResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Vigilancia", Guid.NewGuid());

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion

    #region 3. Mapeo de Códigos de Error SupabaseRpcException (RE005, RE007, RE008, RE009, RE011, RE003)

    [Fact]
    public async Task SolicitarReserva_ErrorRpcRE005_Retorna400ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>()))
            .ThrowsAsync(new SupabaseRpcException("RE005", "Horario fuera de rango"));

        var client = CreateAuthenticatedClient(userId);
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(8),
            Fin = DateTimeOffset.UtcNow.AddDays(8).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "El horario solicitado está fuera del horario de operación del área.");
    }

    [Fact]
    public async Task SolicitarReserva_ErrorRpcRE007_Retorna400ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>()))
            .ThrowsAsync(new SupabaseRpcException("RE007", "Anticipacion invalida"));

        var client = CreateAuthenticatedClient(userId);
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(2),
            Fin = DateTimeOffset.UtcNow.AddDays(2).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.BadRequest, "La reserva debe hacerse con entre 7 y 30 días de anticipación.");
    }

    [Fact]
    public async Task SolicitarReserva_ErrorRpcRE008_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>()))
            .ThrowsAsync(new SupabaseRpcException("RE008", "Ya tiene reserva"));

        var client = CreateAuthenticatedClient(userId);
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(10),
            Fin = DateTimeOffset.UtcNow.AddDays(10).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.Conflict, "Ya tienes una reserva para ese día.");
    }

    [Fact]
    public async Task SolicitarReserva_ErrorRpcRE009_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>()))
            .ThrowsAsync(new SupabaseRpcException("RE009", "Choque de horario"));

        var client = CreateAuthenticatedClient(userId);
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(10),
            Fin = DateTimeOffset.UtcNow.AddDays(10).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(response, HttpStatusCode.Conflict, "El horario choca con otra reserva aprobada o con un bloqueo del área.");
    }

    [Fact]
    public async Task ConfirmarReserva_ErrorRpcRE011_Retorna409ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.ConfirmarReservaAsync(userId, reservaId))
            .ThrowsAsync(new SupabaseRpcException("RE011", "Fuera de ventana de confirmacion"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/confirmar", null);

        await AssertErrorResponseAsync(response, HttpStatusCode.Conflict, "La reserva solo puede confirmarse entre 7 días y 72 horas antes del evento.");
    }

    [Fact]
    public async Task CancelarReserva_ErrorRpcRE003_Retorna403ConMensajeMapeado()
    {
        var userId = Guid.NewGuid();
        var reservaId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.CancelarReservaAsync(userId, reservaId, It.IsAny<string?>()))
            .ThrowsAsync(new SupabaseRpcException("RE003", "No tienes permiso"));

        var client = CreateAuthenticatedClient(userId);

        var response = await client.PostAsync($"/api/reservas/{reservaId}/cancelar", null);

        await AssertErrorResponseAsync(response, HttpStatusCode.Forbidden, "No tienes permiso sobre esta reserva.");
    }

    #endregion

    #region 4. Error RPC con Código Desconocido (500)

    [Fact]
    public async Task SolicitarReserva_ErrorRpcCodigoDesconocido_Retorna500ConMensajeGenerico()
    {
        var userId = Guid.NewGuid();
        SetupUserContext(userId, "Residente", Guid.NewGuid());

        _factory.MockSupabaseService
            .Setup(s => s.SolicitarReservaAsync(userId, It.IsAny<Guid>(), It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>()))
            .ThrowsAsync(new SupabaseRpcException("COD_DESCONOCIDO_999", "Error no mapeado"));

        var client = CreateAuthenticatedClient(userId);
        var dto = new CrearReservaRequestDto
        {
            AreaId = Guid.NewGuid(),
            Inicio = DateTimeOffset.UtcNow.AddDays(10),
            Fin = DateTimeOffset.UtcNow.AddDays(10).AddHours(2)
        };

        var response = await client.PostAsJsonAsync("/api/reservas", dto);

        await AssertErrorResponseAsync(
            response, 
            HttpStatusCode.InternalServerError, 
            "Ocurrió un error inesperado al procesar el código. (Código: COD_DESCONOCIDO_999)");
    }

    #endregion
}
