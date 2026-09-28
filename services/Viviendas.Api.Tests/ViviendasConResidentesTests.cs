using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class ViviendasConResidentesTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public ViviendasConResidentesTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");

        _dbContainer = new PostgreSqlBuilder()
            .WithImage("postgres:15-alpine")
            .WithDatabase("haven_db")
            .WithUsername("postgres")
            .WithPassword("postgres")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _dbContainer.StartAsync();
    }

    public async Task DisposeAsync()
    {
        await _dbContainer.DisposeAsync();
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

    // 1. Rol Vigilancia con condominio: 200; recibe PaginationParams.
    [Fact]
    public async Task GetConResidentes_Vigilancia_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedViviendas = new List<ViviendaConResidentesDto>
        {
            new ViviendaConResidentesDto { Id = 1, CondominioId = condominioId, NumeroCasa = "10A" }
        };

        PaginationParams capturedParams = null!;
        mockSupabaseService.Setup(s => s.GetViviendasConResidentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .Callback<Guid, PaginationParams>((id, p) => capturedParams = p)
            .ReturnsAsync((expectedViviendas, 1));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        mockSupabaseService.Verify(s => s.GetViviendasConResidentesAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        Assert.NotNull(capturedParams);
        Assert.Equal(2, capturedParams.Page);
        Assert.Equal(5, capturedParams.PageSize);
    }

    // 2. Rol Administrador con condominio: 200.
    [Fact]
    public async Task GetConResidentes_Administrador_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        mockSupabaseService.Setup(s => s.GetViviendasConResidentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<ViviendaConResidentesDto>(), 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    // 3. Rol Residente: 403 y el servicio nunca se invoca.
    [Fact]
    public async Task GetConResidentes_Residente_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetViviendasConResidentesAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // 4. Rol Mantenimiento: 403 y el servicio nunca se invoca.
    [Fact]
    public async Task GetConResidentes_Mantenimiento_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Mantenimiento", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetViviendasConResidentesAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // 5. Usuario Vigilancia sin condominio: 200 con items vacío y totalCount 0; el servicio nunca se invoca.
    [Fact]
    public async Task GetConResidentes_VigilanciaSinCondominio_ReturnsEmptyList()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(0, itemsElement.GetArrayLength());
        
        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        Assert.Equal(0, totalCountElement.GetInt32());

        mockSupabaseService.Verify(s => s.GetViviendasConResidentesAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // 6, 7. Estructura de respuesta y Contenido de cada item.
    [Fact]
    public async Task GetConResidentes_StructureAndContentAreCorrect()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedViviendas = new List<ViviendaConResidentesDto>
        {
            new ViviendaConResidentesDto 
            { 
                Id = 1, 
                NumeroCasa = "10B",
                EstaOcupada = true,
                TotalResidentes = 1,
                Residentes = new List<ResidenteVigilanciaDto>
                {
                    new ResidenteVigilanciaDto
                    {
                        Id = Guid.NewGuid(),
                        Nombre = "Juan",
                        Apellidos = "Pérez",
                        Telefono = "12345678"
                    }
                }
            }
        };

        mockSupabaseService.Setup(s => s.GetViviendasConResidentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((expectedViviendas, 50));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes?page=1&pageSize=10");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        
        // Estructura paginada
        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(JsonValueKind.Array, itemsElement.ValueKind);
        Assert.True(content.TryGetProperty("page", out var pageElement));
        Assert.Equal(1, pageElement.GetInt32());
        Assert.True(content.TryGetProperty("pageSize", out var pageSizeElement));
        Assert.Equal(10, pageSizeElement.GetInt32());
        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        Assert.Equal(50, totalCountElement.GetInt32());

        // Contenido del item
        var item = itemsElement[0];
        Assert.True(item.TryGetProperty("numeroCasa", out var numeroCasa));
        Assert.Equal("10B", numeroCasa.GetString());
        Assert.True(item.TryGetProperty("estaOcupada", out var estaOcupada));
        Assert.True(estaOcupada.GetBoolean());
        Assert.True(item.TryGetProperty("totalResidentes", out var totalResidentes));
        Assert.Equal(1, totalResidentes.GetInt32());
        
        // Contenido de residentes
        Assert.True(item.TryGetProperty("residentes", out var residentes));
        Assert.Equal(JsonValueKind.Array, residentes.ValueKind);
        Assert.Equal(1, residentes.GetArrayLength());
        
        var residente = residentes[0];
        Assert.True(residente.TryGetProperty("id", out _));
        Assert.True(residente.TryGetProperty("nombre", out var nombre));
        Assert.Equal("Juan", nombre.GetString());
        Assert.True(residente.TryGetProperty("apellidos", out var apellidos));
        Assert.Equal("Pérez", apellidos.GetString());
        Assert.True(residente.TryGetProperty("telefono", out var telefono));
        Assert.Equal("12345678", telefono.GetString());
        Assert.False(residente.TryGetProperty("email", out _)); // NO debe existir email
    }

    // 8. Vivienda sin residentes: residentes es un arreglo vacío.
    [Fact]
    public async Task GetConResidentes_WithoutResidentes_ReturnsEmptyArray()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedViviendas = new List<ViviendaConResidentesDto>
        {
            new ViviendaConResidentesDto 
            { 
                Id = 1, 
                NumeroCasa = "10C",
                Residentes = new List<ResidenteVigilanciaDto>()
            }
        };

        mockSupabaseService.Setup(s => s.GetViviendasConResidentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((expectedViviendas, 1));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas/con-residentes");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        var item = content.GetProperty("items")[0];
        
        Assert.True(item.TryGetProperty("residentes", out var residentes));
        Assert.Equal(JsonValueKind.Array, residentes.ValueKind);
        Assert.Equal(0, residentes.GetArrayLength());
    }

    // 9. Sin token: 401.
    [Fact]
    public async Task GetConResidentes_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var response = await client.GetAsync("/api/viviendas/con-residentes");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
