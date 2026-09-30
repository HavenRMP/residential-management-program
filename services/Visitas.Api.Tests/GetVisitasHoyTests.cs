using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class GetVisitasHoyTests
{
    public GetVisitasHoyTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");
    }

    private WebApplicationFactory<Program> BuildApplication(Mock<ISupabaseService> mockSupabaseService)
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

                    var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseService));
                    if (descriptor != null) services.Remove(descriptor);
                    services.AddSingleton(mockSupabaseService.Object);
                });
            });
    }

    private string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{header}.{payload}.";
    }

    [Fact]
    public async Task GetVisitasHoy_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var response = await client.GetAsync("/api/visitas/hoy");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task GetVisitasHoy_Vigilancia_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedVisitas = new List<VisitaDto>();

        PaginationParams capturedParams = null!;
        mockSupabaseService.Setup(s => s.GetVisitasHoyAsync(condominioId, It.IsAny<PaginationParams>(), It.IsAny<string?>()))
            .Callback<Guid, PaginationParams, string?>((id, p, b) => capturedParams = p)
            .ReturnsAsync((expectedVisitas, 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(1, capturedParams.Page);
        Assert.Equal(20, capturedParams.PageSize);
    }

    [Fact]
    public async Task GetVisitasHoy_Administrador_ReturnsOk_PagParamsPropagados()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedVisitas = new List<VisitaDto>();

        PaginationParams capturedParams = null!;
        string? capturedBusqueda = null;
        
        mockSupabaseService.Setup(s => s.GetVisitasHoyAsync(condominioId, It.IsAny<PaginationParams>(), It.IsAny<string?>()))
            .Callback<Guid, PaginationParams, string?>((id, p, b) => {
                capturedParams = p;
                capturedBusqueda = b;
            })
            .ReturnsAsync((expectedVisitas, 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy?page=2&pageSize=10&busqueda=juanito");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(condominioId, It.IsAny<PaginationParams>(), "juanito"), Times.Once);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(2, capturedParams.Page);
        Assert.Equal(10, capturedParams.PageSize);
        Assert.Equal("juanito", capturedBusqueda);
    }

    [Fact]
    public async Task GetVisitasHoy_Residente_ReturnsForbiddenYNuncaLlamaAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task GetVisitasHoy_Mantenimiento_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Mantenimiento", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task GetVisitasHoy_VigilanciaSinCondominio_ReturnsOkVacioYNuncaLlamaAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetVisitasHoyAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>(), It.IsAny<string?>()), Times.Never);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(0, itemsElement.GetArrayLength());
        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        Assert.Equal(0, totalCountElement.GetInt32());
    }

    [Fact]
    public async Task GetVisitasHoy_StructureAndPrivacyAreCorrect()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedVisitas = new List<VisitaDto>
        {
            new VisitaDto 
            { 
                Id = Guid.NewGuid(), 
                Codigo = "SECRET",
                CreadoPor = Guid.NewGuid(),
                NombreVisitante = "Juan",
                Estado = "programada",
                ViviendaId = 1,
                CreadoPorNombre = "Residente A"
            }
        };

        mockSupabaseService.Setup(s => s.GetVisitasHoyAsync(condominioId, It.IsAny<PaginationParams>(), It.IsAny<string?>()))
            .ReturnsAsync((expectedVisitas, 1));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/hoy");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        
        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(JsonValueKind.Array, itemsElement.ValueKind);
        Assert.Equal(1, itemsElement.GetArrayLength());
        
        var firstItem = itemsElement[0];
        Assert.True(firstItem.TryGetProperty("id", out _));
        Assert.True(firstItem.TryGetProperty("nombreVisitante", out _));
        Assert.True(firstItem.TryGetProperty("estado", out _));
        
        // Privacy checks
        Assert.False(firstItem.TryGetProperty("codigo", out _));
        Assert.False(firstItem.TryGetProperty("creadoPor", out _));
        Assert.False(firstItem.TryGetProperty("email", out _));
        
        Assert.True(content.TryGetProperty("page", out _));
        Assert.True(content.TryGetProperty("pageSize", out _));
        Assert.True(content.TryGetProperty("totalCount", out _));
    }
}
