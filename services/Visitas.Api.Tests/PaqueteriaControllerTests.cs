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

public class PaqueteriaControllerTests
{
    public PaqueteriaControllerTests()
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

    // --- 1. Crear: sin token ---
    [Fact]
    public async Task Crear_SinToken_ReturnsUnauthorized()
    {
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();

        var body = new CreatePaqueteEsperadoRequestDto { ViviendaId = 1, DestinatarioNombre = "Juan", ServicioId = 1 };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockService.Verify(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    // --- 2. Crear: body inválido ---
    [Fact]
    public async Task Crear_BodyInvalido_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        // Falta DestinatarioNombre y no hay servicio
        var body = new CreatePaqueteEsperadoRequestDto { ViviendaId = 1 };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    // --- 3. Crear: ambas fechas y hasta < desde ---
    [Fact]
    public async Task Crear_FechasIncoherentes_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreatePaqueteEsperadoRequestDto 
        { 
            ViviendaId = 1, 
            DestinatarioNombre = "Juan", 
            ServicioId = 1,
            FechaEsperadaDesde = DateTimeOffset.UtcNow.AddDays(2),
            FechaEsperadaHasta = DateTimeOffset.UtcNow.AddDays(1)
        };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    // --- 4. Crear: hasta ya vencido ---
    [Fact]
    public async Task Crear_HastaVencido_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreatePaqueteEsperadoRequestDto 
        { 
            ViviendaId = 1, 
            DestinatarioNombre = "Juan", 
            ServicioId = 1,
            FechaEsperadaHasta = DateTimeOffset.UtcNow.AddDays(-1)
        };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    // --- 5. Crear: sin fechas devuelve 201 ---
    [Fact]
    public async Task Crear_SinFechas_ReturnsCreated()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        var dto = new PaqueteDto { Id = Guid.NewGuid(), DestinatarioNombre = "Juan" };
        mockService.Setup(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), userId)).ReturnsAsync(dto);
        
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreatePaqueteEsperadoRequestDto { ViviendaId = 1, DestinatarioNombre = "Juan", ServicioId = 1 };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }

    // --- 6. Crear: válido devuelve 201 y pasa token userId ---
    [Fact]
    public async Task Crear_Valido_ReturnsCreatedAndPropagatesUserId()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        var dto = new PaqueteDto { Id = Guid.NewGuid(), DestinatarioNombre = "Juan" };
        mockService.Setup(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), userId)).ReturnsAsync(dto).Verifiable();
        
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreatePaqueteEsperadoRequestDto 
        { 
            ViviendaId = 1, 
            DestinatarioNombre = "Juan", 
            ServicioNombre = "Servicio X",
            FechaEsperadaHasta = DateTimeOffset.UtcNow.AddDays(1)
        };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockService.Verify();
    }

    // --- 7. Crear: Excepciones PQ003 y PQ002 ---
    [Theory]
    [InlineData("PQ003", HttpStatusCode.BadRequest)]
    [InlineData("PQ002", HttpStatusCode.Forbidden)]
    public async Task Crear_RpcException_ReturnsMappedStatus(string rpcCode, HttpStatusCode expectedStatus)
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        mockService.Setup(s => s.CreatePaqueteEsperadoAsync(It.IsAny<CreatePaqueteEsperadoRequestDto>(), userId))
            .ThrowsAsync(new SupabaseRpcException(rpcCode, "Error"));
        
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var body = new CreatePaqueteEsperadoRequestDto { ViviendaId = 1, DestinatarioNombre = "Juan", ServicioId = 1 };
        var response = await client.PostAsJsonAsync("/api/paqueteria", body);

        Assert.Equal(expectedStatus, response.StatusCode);
    }

    // --- 8. Mis paquetes: defaults y propagación ---
    [Fact]
    public async Task MisPaquetes_PropagaParamsYPaginaCorrectamente()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        var token = GenerateFakeToken(userId);
        
        PaginationParams capturedParams = null!;
        int? capturedViviendaId = null;
        string? capturedEstado = null;

        mockService.Setup(s => s.GetMisPaquetesAsync(It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<string?>(), It.IsAny<PaginationParams>()))
            .Callback<string, int?, string?, PaginationParams>((t, v, e, p) => { capturedViviendaId = v; capturedEstado = e; capturedParams = p; })
            .ReturnsAsync((new List<PaqueteDto>(), 5));
        
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Sin query params
        var response1 = await client.GetAsync("/api/paqueteria/mis-paquetes");
        Assert.Equal(HttpStatusCode.OK, response1.StatusCode);
        Assert.Equal(1, capturedParams.Page);
        Assert.Equal(20, capturedParams.PageSize);
        Assert.Null(capturedViviendaId);
        Assert.Null(capturedEstado);

        // Con query params
        var response2 = await client.GetAsync("/api/paqueteria/mis-paquetes?page=2&pageSize=10&viviendaId=5&estado=recibido");
        Assert.Equal(HttpStatusCode.OK, response2.StatusCode);
        Assert.Equal(2, capturedParams.Page);
        Assert.Equal(10, capturedParams.PageSize);
        Assert.Equal(5, capturedViviendaId);
        Assert.Equal("recibido", capturedEstado);

        var content = await response2.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(content.TryGetProperty("items", out _));
        Assert.True(content.TryGetProperty("page", out var p) && p.GetInt32() == 2);
        Assert.True(content.TryGetProperty("pageSize", out var ps) && ps.GetInt32() == 10);
        Assert.True(content.TryGetProperty("totalCount", out var tc) && tc.GetInt32() == 5);
    }

    // --- 9. Mis paquetes: estado inválido ---
    [Fact]
    public async Task MisPaquetes_EstadoInvalido_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/mis-paquetes?estado=inexistente");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockService.Verify(s => s.GetMisPaquetesAsync(It.IsAny<string>(), It.IsAny<int?>(), It.IsAny<string?>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // --- 10. Editar: body vacío, válido y PQ004 ---
    [Fact]
    public async Task Editar_BodyVacio_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.PutAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}", new UpdatePaqueteEsperadoRequestDto());
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Editar_Valido_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var paqueteId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        mockService.Setup(s => s.UpdatePaqueteEsperadoAsync(paqueteId, userId, It.IsAny<UpdatePaqueteEsperadoRequestDto>()))
            .ReturnsAsync(new PaqueteDto { Id = paqueteId }).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.PutAsJsonAsync($"/api/paqueteria/{paqueteId}", new UpdatePaqueteEsperadoRequestDto { Notas = "Nuevas notas" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockService.Verify();
    }

    [Fact]
    public async Task Editar_ErrorPQ004_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var paqueteId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        mockService.Setup(s => s.UpdatePaqueteEsperadoAsync(paqueteId, userId, It.IsAny<UpdatePaqueteEsperadoRequestDto>()))
            .ThrowsAsync(new SupabaseRpcException("PQ004", "Estado no permite editar"));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.PutAsJsonAsync($"/api/paqueteria/{paqueteId}", new UpdatePaqueteEsperadoRequestDto { Notas = "x" });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    // --- 11. Cancelar: sin body, con motivo, false -> 404, PQ004 -> 409 ---
    [Fact]
    public async Task Cancelar_SinBodyYConMotivo_PropagaServicio()
    {
        var userId = Guid.NewGuid();
        var paqueteId1 = Guid.NewGuid();
        var paqueteId2 = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        
        mockService.Setup(s => s.CancelPaqueteEsperadoAsync(paqueteId1, userId, null)).ReturnsAsync(true).Verifiable();
        mockService.Setup(s => s.CancelPaqueteEsperadoAsync(paqueteId2, userId, "Motivo x")).ReturnsAsync(true).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response1 = await client.PostAsJsonAsync($"/api/paqueteria/{paqueteId1}/cancelar", new { });
        Assert.Equal(HttpStatusCode.NoContent, response1.StatusCode);

        var response2 = await client.PostAsJsonAsync($"/api/paqueteria/{paqueteId2}/cancelar", new CancelPaqueteEsperadoRequestDto { Motivo = "Motivo x" });
        Assert.Equal(HttpStatusCode.NoContent, response2.StatusCode);

        mockService.Verify();
    }

    [Fact]
    public async Task Cancelar_ServicioFalse_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        mockService.Setup(s => s.CancelPaqueteEsperadoAsync(It.IsAny<Guid>(), userId, It.IsAny<string>())).ReturnsAsync(false);

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.PostAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}/cancelar", new CancelPaqueteEsperadoRequestDto());
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Cancelar_ErrorPQ004_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        mockService.Setup(s => s.CancelPaqueteEsperadoAsync(It.IsAny<Guid>(), userId, It.IsAny<string>()))
            .ThrowsAsync(new SupabaseRpcException("PQ004", ""));

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.PostAsJsonAsync($"/api/paqueteria/{Guid.NewGuid()}/cancelar", new CancelPaqueteEsperadoRequestDto());
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    // --- 12. Catálogo ---
    [Fact]
    public async Task Catalogo_ConCondominioYGlobales()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        
        mockService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));
            
        mockService.Setup(s => s.GetServiciosPaqueteriaAsync(condominioId))
            .ReturnsAsync(new List<ServicioPaqueteriaDto> { new ServicioPaqueteriaDto { Id = 1 } }).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/servicios");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockService.Verify();
    }

    [Fact]
    public async Task Catalogo_SinCondominio_SoloGlobales()
    {
        var userId = Guid.NewGuid();
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        
        mockService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", null));
            
        mockService.Setup(s => s.GetServiciosPaqueteriaAsync(null))
            .ReturnsAsync(new List<ServicioPaqueteriaDto> { new ServicioPaqueteriaDto { Id = 1 } }).Verifiable();

        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(userId));

        var response = await client.GetAsync("/api/paqueteria/servicios");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockService.Verify();
    }

    [Fact]
    public async Task Catalogo_SinToken_ReturnsUnauthorized()
    {
        var mockService = new Mock<IPaqueteriaSupabaseService>();
        await using var app = BuildApplication(mockService);
        var client = app.CreateClient();

        var response = await client.GetAsync("/api/paqueteria/servicios");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
