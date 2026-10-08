using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class PaqueteriaCasetaTests
{
    public PaqueteriaCasetaTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");
    }

    private WebApplicationFactory<Program> BuildApplication(Mock<IPaqueteriaSupabaseService> mockService)
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((context, configBuilder) =>
                {
                    configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        { "Supabase:Url", "http://localhost:54321" }
                    });
                });
                builder.ConfigureServices(services =>
                {
                    services.PostConfigure<Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerOptions>(
                        Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerDefaults.AuthenticationScheme,
                        options =>
                        {
                            options.Authority = null;
                            options.TokenValidationParameters.ValidateIssuer = false;
                            options.TokenValidationParameters.ValidateAudience = false;
                            options.TokenValidationParameters.ValidateLifetime = false;
                            options.TokenValidationParameters.ValidateIssuerSigningKey = false;
                            options.TokenValidationParameters.RequireSignedTokens = false;
                        });

                    var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(IPaqueteriaSupabaseService));
                    if (descriptor != null) services.Remove(descriptor);
                    services.AddSingleton(mockService.Object);
                });
            });
    }

    private string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{header}.{payload}.";
    }

    private void SetupUserRole(Mock<IPaqueteriaSupabaseService> mockService, Guid userId, string roleName, Guid? condominioId)
    {
        mockService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((roleName, condominioId));
    }

    // 1. Esperados e inventario: sin token 401; vigilancia y administrador 200; residente y mantenimiento 403 y el servicio nunca se llama.
    [Theory]
    [InlineData("esperados")]
    [InlineData("inventario")]
    public async Task GetCaseta_SinToken_Returns401(string endpoint)
    {
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();

        var response = await client.GetAsync($"/api/paqueteria/{endpoint}");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("esperados", "administrador")]
    [InlineData("esperados", "vigilancia")]
    [InlineData("inventario", "administrador")]
    [InlineData("inventario", "vigilancia")]
    public async Task GetCaseta_RolesPermitidos_Returns200(string endpoint, string rol)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, rol, Guid.NewGuid());
        mockService.Setup(s => s.GetPaquetesCasetaAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<PaqueteCasetaDto>(), 0));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync($"/api/paqueteria/{endpoint}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Theory]
    [InlineData("esperados", "residente")]
    [InlineData("esperados", "mantenimiento")]
    [InlineData("inventario", "residente")]
    [InlineData("inventario", "mantenimiento")]
    public async Task GetCaseta_RolesDenegados_Returns403_NoServiceCall(string endpoint, string rol)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, rol, Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync($"/api/paqueteria/{endpoint}");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockService.Verify(s => s.GetPaquetesCasetaAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // 2. Esperados e inventario: cada uno llama al servicio con su estado correcto y propaga parametros
    [Fact]
    public async Task GetCaseta_Esperados_PropagaParametrosYEstado()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", condominioId);
        mockService.Setup(s => s.GetPaquetesCasetaAsync(condominioId, PaqueteEstados.Esperado, 5, It.Is<PaginationParams>(p => p.Page == 2 && p.PageSize == 10)))
            .ReturnsAsync((new List<PaqueteCasetaDto>(), 0)).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/esperados?viviendaId=5&page=2&pageSize=10");
        mockService.Verify();
    }

    [Fact]
    public async Task GetCaseta_Inventario_PropagaParametrosYEstado()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", condominioId);
        mockService.Setup(s => s.GetPaquetesCasetaAsync(condominioId, PaqueteEstados.Recibido, null, It.Is<PaginationParams>(p => p.Page == 1 && p.PageSize == 20)))
            .ReturnsAsync((new List<PaqueteCasetaDto>(), 0)).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/inventario?page=1&pageSize=20");
        mockService.Verify();
    }

    // 3. Esperados e inventario: usuario sin condominio recibe 200 con items vacío y totalCount 0, y el servicio nunca se llama.
    [Theory]
    [InlineData("esperados")]
    [InlineData("inventario")]
    public async Task GetCaseta_SinCondominio_ReturnsVacio_NoServiceCall(string endpoint)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", null);

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync($"/api/paqueteria/{endpoint}");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        Assert.Empty(doc.RootElement.GetProperty("items").EnumerateArray());
        Assert.Equal(0, doc.RootElement.GetProperty("totalCount").GetInt32());

        mockService.Verify(s => s.GetPaquetesCasetaAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // 4. Privacidad: la respuesta de caseta NO contiene creadoPor ni email y SÍ contiene creadoPorNombre.
    [Fact]
    public async Task GetCaseta_Proyeccion_ValidaPrivacidad()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());
        var paquete = new PaqueteCasetaDto { Id = Guid.NewGuid(), CreadoPorNombre = "Juan", DestinatarioNombre = "Pedro" };
        mockService.Setup(s => s.GetPaquetesCasetaAsync(It.IsAny<Guid>(), It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<PaqueteCasetaDto> { paquete }, 1));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/esperados");
        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        var item = doc.RootElement.GetProperty("items")[0];

        Assert.False(item.TryGetProperty("creadoPor", out _));
        Assert.False(item.TryGetProperty("email", out _));
        Assert.True(item.TryGetProperty("creadoPorNombre", out var cpn) && cpn.GetString() == "Juan");
    }

    // 5. Recepción: validaciones de rol, token, body, etc.
    [Theory]
    [InlineData("vigilancia", HttpStatusCode.Created)]
    [InlineData("administrador", HttpStatusCode.Created)]
    [InlineData("residente", HttpStatusCode.Forbidden)]
    public async Task Recepcion_Roles(string rol, HttpStatusCode expectedCode)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, rol, Guid.NewGuid());
        mockService.Setup(s => s.RecibirPaqueteAsync(It.IsAny<RecibirPaqueteRequestDto>(), It.IsAny<Guid>()))
            .ReturnsAsync(new PaqueteCasetaDto { Id = Guid.NewGuid(), DestinatarioNombre = "x", CreadoPorNombre = "y" });

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new RecibirPaqueteRequestDto { PaqueteId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync("/api/paqueteria/recepcion", body);

        Assert.Equal(expectedCode, response.StatusCode);
    }

    [Fact]
    public async Task Recepcion_SinToken_Returns401()
    {
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();

        var body = new RecibirPaqueteRequestDto { PaqueteId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync("/api/paqueteria/recepcion", body);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Recepcion_BodyInvalido_Returns400_NoServiceCall()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        // Invalido: Sin paqueteId, sin viviendaId, sin destinatarioNombre
        var body = new RecibirPaqueteRequestDto { Descripcion = "Test" };
        var response = await client.PostAsJsonAsync("/api/paqueteria/recepcion", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.RecibirPaqueteAsync(It.IsAny<RecibirPaqueteRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task Recepcion_PaqueteIdSinVivienda_Returns201_PropagaActorId()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());
        mockService.Setup(s => s.RecibirPaqueteAsync(It.IsAny<RecibirPaqueteRequestDto>(), userId))
            .ReturnsAsync(new PaqueteCasetaDto { Id = Guid.NewGuid(), DestinatarioNombre = "x", CreadoPorNombre = "y" }).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new RecibirPaqueteRequestDto { PaqueteId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync("/api/paqueteria/recepcion", body);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockService.Verify();
    }

    // 6. Recepción: errores RPC se mapean
    [Theory]
    [InlineData("PQ007", HttpStatusCode.Forbidden)]
    [InlineData("PQ004", HttpStatusCode.Conflict)]
    [InlineData("PQ003", HttpStatusCode.BadRequest)]
    [InlineData("PQ010", HttpStatusCode.Forbidden)]
    public async Task Recepcion_ErroresRpc_SeMapean(string errorCode, HttpStatusCode expectedCode)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());
        mockService.Setup(s => s.RecibirPaqueteAsync(It.IsAny<RecibirPaqueteRequestDto>(), userId))
            .ThrowsAsync(new SupabaseRpcException(errorCode, "Error"));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new RecibirPaqueteRequestDto { PaqueteId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync("/api/paqueteria/recepcion", body);

        Assert.Equal(expectedCode, response.StatusCode);
    }

    // 7. Entrega: validaciones
    [Theory]
    [InlineData("vigilancia", HttpStatusCode.OK)]
    [InlineData("administrador", HttpStatusCode.OK)]
    [InlineData("residente", HttpStatusCode.Forbidden)]
    public async Task Entrega_Roles(string rol, HttpStatusCode expectedCode)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, rol, Guid.NewGuid());
        mockService.Setup(s => s.EntregarPaqueteAsync(It.IsAny<Guid>(), It.IsAny<EntregarPaqueteRequestDto>(), It.IsAny<Guid>()))
            .ReturnsAsync(new PaqueteCasetaDto { Id = Guid.NewGuid(), DestinatarioNombre = "x", CreadoPorNombre = "y" });

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new EntregarPaqueteRequestDto { EntregadoANombre = "Juan" };
        var response = await client.PostAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}/entrega", body);

        Assert.Equal(expectedCode, response.StatusCode);
    }

    [Fact]
    public async Task Entrega_SinEntregadoANombre_Returns400_NoServiceCall()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new EntregarPaqueteRequestDto { EntregadoANombre = "" };
        var response = await client.PostAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}/entrega", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.EntregarPaqueteAsync(It.IsAny<Guid>(), It.IsAny<EntregarPaqueteRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    [Theory]
    [InlineData("PQ004", HttpStatusCode.Conflict)]
    [InlineData("PQ001", HttpStatusCode.NotFound)]
    public async Task Entrega_ErroresRpc(string errorCode, HttpStatusCode expectedCode)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());
        mockService.Setup(s => s.EntregarPaqueteAsync(It.IsAny<Guid>(), It.IsAny<EntregarPaqueteRequestDto>(), It.IsAny<Guid>()))
            .ThrowsAsync(new SupabaseRpcException(errorCode, "Error"));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new EntregarPaqueteRequestDto { EntregadoANombre = "Juan" };
        var response = await client.PostAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}/entrega", body);

        Assert.Equal(expectedCode, response.StatusCode);
    }

    // 8. Histórico
    [Fact]
    public async Task GetHistorico_Administrador_Returns200_PropagaFiltros()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", condominioId);
        mockService.Setup(s => s.GetPaquetesHistoricoAsync(condominioId, It.IsAny<DateTimeOffset>(), It.IsAny<DateTimeOffset>(), 5, "entregado", It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<PaqueteHistoricoDto>(), 0)).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var desde = DateTimeOffset.UtcNow.AddDays(-1).ToString("O");
        var hasta = DateTimeOffset.UtcNow.ToString("O");
        var response = await client.GetAsync($"/api/paqueteria/historico?desde={Uri.EscapeDataString(desde)}&hasta={Uri.EscapeDataString(hasta)}&viviendaId=5&estado=entregado");
        
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockService.Verify();
    }

    [Theory]
    [InlineData("vigilancia")]
    [InlineData("residente")]
    public async Task GetHistorico_RolesDenegados_Returns403(string rol)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, rol, Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/historico");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetHistorico_DesdeMayorQueHasta_Returns400()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var desde = DateTimeOffset.UtcNow.ToString("O");
        var hasta = DateTimeOffset.UtcNow.AddDays(-1).ToString("O");
        var response = await client.GetAsync($"/api/paqueteria/historico?desde={Uri.EscapeDataString(desde)}&hasta={Uri.EscapeDataString(hasta)}");
        
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetHistorico_EstadoInvalido_Returns400()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/historico?estado=invento");
        
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GetHistorico_SinCondominio_Returns200Vacio()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", null);

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/historico");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var json = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(json);
        Assert.Empty(doc.RootElement.GetProperty("items").EnumerateArray());
    }

    // 9. Catálogo admin
    [Fact]
    public async Task CreateServicio_Administrador_Returns201_UsaCondominioContexto()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", condominioId);
        mockService.Setup(s => s.CreateServicioPaqueteriaAsync(condominioId, It.IsAny<CreateServicioPaqueteriaRequestDto>(), userId))
            .ReturnsAsync(new ServicioPaqueteriaDto { Id = 1, Nombre = "Amazon" }).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreateServicioPaqueteriaRequestDto { Nombre = "Amazon" };
        var response = await client.PostAsJsonAsync("/api/paqueteria/servicios", body);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockService.Verify();
    }

    [Fact]
    public async Task CreateServicio_Vigilancia_Returns403()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreateServicioPaqueteriaRequestDto { Nombre = "Amazon" };
        var response = await client.PostAsJsonAsync("/api/paqueteria/servicios", body);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateServicio_SinCondominio_Returns400()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", null);

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreateServicioPaqueteriaRequestDto { Nombre = "Amazon" };
        var response = await client.PostAsJsonAsync("/api/paqueteria/servicios", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task DeleteServicio_Administrador_Returns204()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", Guid.NewGuid());
        mockService.Setup(s => s.DeleteServicioPaqueteriaAsync(1, userId))
            .ReturnsAsync(true).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.DeleteAsync("/api/paqueteria/servicios/1");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockService.Verify();
    }

    [Fact]
    public async Task DeleteServicio_Administrador_Returns404IfFalse()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "administrador", Guid.NewGuid());
        mockService.Setup(s => s.DeleteServicioPaqueteriaAsync(1, userId))
            .ReturnsAsync(false);

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.DeleteAsync("/api/paqueteria/servicios/1");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeleteServicio_Vigilancia_Returns403()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        SetupUserRole(mockService, userId, "vigilancia", Guid.NewGuid());

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.DeleteAsync("/api/paqueteria/servicios/1");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}
