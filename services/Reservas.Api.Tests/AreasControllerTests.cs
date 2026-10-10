using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using Moq;
using Reservas.Api.DTOs;
using Reservas.Api.Services;
using System;
using System.Collections.Generic;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Xunit;

namespace Reservas.Api.Tests;

public class AreasControllerTests : IClassFixture<ReservasApiFactory>
{
    private readonly ReservasApiFactory _factory;

    public AreasControllerTests(ReservasApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseService.Invocations.Clear();
    }

    private void SetupUserContext(Guid userId, string rol, Guid? condominioId)
    {
        _factory.MockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((rol, condominioId));
    }

    [Fact]
    public async Task GetAreas_SinToken_Retorna401()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/areas");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetAreas_ConResidente_Retorna200_Y_SoloActivasTrue()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreasAsync(condominioId, true, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<AreaComunDto>(), 0));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/areas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetAreasAsync(condominioId, true, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetAreas_ConAdmin_Retorna200_Y_SoloActivasFalse()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreasAsync(condominioId, false, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<AreaComunDto>(), 0));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/areas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _factory.MockSupabaseService.Verify(s => s.GetAreasAsync(condominioId, false, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetAreas_UsuarioSinCondominio_Retorna403()
    {
        var userId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", null);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/areas");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetArea_Inexistente_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId))
            .ReturnsAsync((AreaComunDto?)null);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/areas/{areaId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetArea_Inactiva_ConResidente_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId))
            .ReturnsAsync(new AreaComunDto { Id = areaId, CondominioId = condominioId, Activo = false });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/areas/{areaId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CrearArea_ConResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", condominioId);

        var dto = new CreateAreaComunRequestDto
        {
            Nombre = "Gym",
            HoraApertura = new TimeOnly(8, 0),
            HoraCierre = new TimeOnly(20, 0)
        };

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync("/api/areas", dto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CrearArea_ConAdminYBodyValido_Retorna201()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        var dto = new CreateAreaComunRequestDto
        {
            Nombre = "Gym",
            HoraApertura = new TimeOnly(8, 0),
            HoraCierre = new TimeOnly(20, 0)
        };

        var areaCreada = new AreaComunDto { Id = Guid.NewGuid(), Nombre = "Gym", CondominioId = condominioId, Activo = true };
        _factory.MockSupabaseService.Setup(s => s.CrearAreaAsync(condominioId, It.IsAny<CreateAreaComunRequestDto>(), userId))
            .ReturnsAsync(areaCreada);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync("/api/areas", dto);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    [Fact]
    public async Task CrearArea_AperturaMayorQueCierre_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        var dto = new CreateAreaComunRequestDto
        {
            Nombre = "Gym",
            HoraApertura = new TimeOnly(22, 0),
            HoraCierre = new TimeOnly(8, 0)
        };

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync("/api/areas", dto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarArea_ConAdmin_Retorna200()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        var areaExistente = new AreaComunDto { Id = areaId, CondominioId = condominioId };
        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId)).ReturnsAsync(areaExistente);

        var dto = new UpdateAreaComunRequestDto { Nombre = "Gym Modificado" };
        var areaActualizada = new AreaComunDto { Id = areaId, Nombre = "Gym Modificado", CondominioId = condominioId, Activo = true };
        _factory.MockSupabaseService.Setup(s => s.ActualizarAreaAsync(areaId, It.IsAny<UpdateAreaComunRequestDto>(), userId))
            .ReturnsAsync(areaActualizada);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new HttpRequestMessage(HttpMethod.Patch, $"/api/areas/{areaId}")
        {
            Content = JsonContent.Create(dto)
        };
        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task ActualizarArea_OtroCondominio_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        var areaExistente = new AreaComunDto { Id = areaId, CondominioId = otroCondominioId };
        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId)).ReturnsAsync(areaExistente);

        var dto = new UpdateAreaComunRequestDto { Nombre = "Gym Modificado" };

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new HttpRequestMessage(HttpMethod.Patch, $"/api/areas/{areaId}")
        {
            Content = JsonContent.Create(dto)
        };
        var response = await client.SendAsync(request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task BajaArea_ConAdmin_Retorna204()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId)).ReturnsAsync(new AreaComunDto { Id = areaId, CondominioId = condominioId });
        _factory.MockSupabaseService.Setup(s => s.BajaAreaAsync(areaId, userId)).ReturnsAsync(true);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/areas/{areaId}/baja", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task BajaArea_ConResidente_Retorna403()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Residente", condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/areas/{areaId}/baja", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task ReactivarArea_ServicioDevuelveFalse_Retorna400()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId)).ReturnsAsync(new AreaComunDto { Id = areaId, CondominioId = condominioId });
        _factory.MockSupabaseService.Setup(s => s.ReactivarAreaAsync(areaId, userId)).ReturnsAsync(false);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/areas/{areaId}/reactivar", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task BajaArea_SupabaseRpcExceptionRE001_Retorna404()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var areaId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateFakeToken(userId);

        SetupUserContext(userId, "Administrador", condominioId);

        _factory.MockSupabaseService.Setup(s => s.GetAreaByIdAsync(areaId)).ReturnsAsync(new AreaComunDto { Id = areaId, CondominioId = condominioId });
        
        _factory.MockSupabaseService.Setup(s => s.BajaAreaAsync(areaId, userId))
            .ThrowsAsync(new SupabaseRpcException("RE001", "Mensaje original"));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/areas/{areaId}/baja", null);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("El área común no existe o está inactiva.", content.GetProperty("error").GetString());
    }
}
