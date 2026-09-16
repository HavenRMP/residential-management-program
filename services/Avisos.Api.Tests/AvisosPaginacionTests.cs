using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Avisos.Api.DTOs;
using Avisos.Api.Services;
using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Xunit;

namespace Avisos.Api.Tests;

public class AvisosPaginacionTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private readonly Mock<ISupabaseService> _mockSupabaseService;

    public AvisosPaginacionTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");

        _dbContainer = new PostgreSqlBuilder()
            .WithImage("postgres:15-alpine")
            .WithDatabase("haven_db")
            .WithUsername("postgres")
            .WithPassword("postgres")
            .Build();
            
        _mockSupabaseService = new Mock<ISupabaseService>();
    }

    public async Task InitializeAsync()
    {
        await _dbContainer.StartAsync();
    }

    public async Task DisposeAsync()
    {
        await _dbContainer.DisposeAsync();
    }

    private WebApplicationFactory<Program> CreateFactory()
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((context, configBuilder) =>
                {
                    configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        { "Supabase:Url", "http://localhost:54321" },
                        { "Supabase:AnonKey", "fake-anon-key" },
                        { "Supabase:ServiceRoleKey", "fake-service-key" }
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
                    services.AddSingleton(_mockSupabaseService.Object);
                });
            });
    }

    private string GenerateMockJwt(Guid userId)
    {
        var claims = new[] { new Claim("sub", userId.ToString()) };
        var jwt = new JwtSecurityToken(claims: claims);
        return new JwtSecurityTokenHandler().WriteToken(jwt);
    }

    // ==========================================
    // TESTS PARA GET /api/avisos
    // ==========================================

    [Fact]
    public async Task GetAvisos_WithPaginationParams_PassesParamsToService()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));
            
        PaginationParams capturedParams = null!;
        _mockSupabaseService.Setup(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .Callback<Guid, PaginationParams>((id, p) => capturedParams = p)
            .ReturnsAsync((new List<AvisoDto>(), 0));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos?page=3&pageSize=10");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _mockSupabaseService.Verify(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        Assert.NotNull(capturedParams);
        Assert.Equal(3, capturedParams.Page);
        Assert.Equal(10, capturedParams.PageSize);
    }

    [Fact]
    public async Task GetAvisos_ReturnsCorrectPagedResultStructure()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));
            
        var expectedAvisos = new List<AvisoDto> { new AvisoDto { Id = Guid.NewGuid(), Titulo = "T" } };
        _mockSupabaseService.Setup(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((expectedAvisos, 50));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(JsonValueKind.Array, itemsElement.ValueKind);
        Assert.Equal(1, itemsElement.GetArrayLength());
        
        Assert.True(content.TryGetProperty("page", out var pageElement));
        Assert.Equal(2, pageElement.GetInt32());

        Assert.True(content.TryGetProperty("pageSize", out var pageSizeElement));
        Assert.Equal(5, pageSizeElement.GetInt32());

        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        Assert.Equal(50, totalCountElement.GetInt32());
    }

    [Fact]
    public async Task GetAvisos_WithoutCondominioId_ReturnsEmptyPagedResult_NeverCallsService()
    {
        var userId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", (Guid?)null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(0, itemsElement.GetArrayLength());
        Assert.Equal(0, content.GetProperty("totalCount").GetInt32());

        _mockSupabaseService.Verify(s => s.GetAvisosVigentesAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    // ==========================================
    // TESTS PARA GET /api/avisos/historico
    // ==========================================

    [Fact]
    public async Task GetAvisosHistorico_WithPaginationParams_PassesParamsToService()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        // Requiere rol administrador
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        PaginationParams capturedParams = null!;
        _mockSupabaseService.Setup(s => s.GetAvisosHistoricoAsync(condominioId, It.IsAny<PaginationParams>()))
            .Callback<Guid, PaginationParams>((id, p) => capturedParams = p)
            .ReturnsAsync((new List<AvisoDto>(), 0));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos/historico?page=3&pageSize=10");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _mockSupabaseService.Verify(s => s.GetAvisosHistoricoAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        Assert.NotNull(capturedParams);
        Assert.Equal(3, capturedParams.Page);
        Assert.Equal(10, capturedParams.PageSize);
    }

    [Fact]
    public async Task GetAvisosHistorico_ReturnsCorrectPagedResultStructure()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        var expectedAvisos = new List<AvisoDto> { new AvisoDto { Id = Guid.NewGuid(), Titulo = "T" } };
        _mockSupabaseService.Setup(s => s.GetAvisosHistoricoAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((expectedAvisos, 50));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos/historico?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(JsonValueKind.Array, itemsElement.ValueKind);
        Assert.Equal(1, itemsElement.GetArrayLength());
        
        Assert.True(content.TryGetProperty("page", out var pageElement));
        Assert.Equal(2, pageElement.GetInt32());

        Assert.True(content.TryGetProperty("pageSize", out var pageSizeElement));
        Assert.Equal(5, pageSizeElement.GetInt32());

        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        Assert.Equal(50, totalCountElement.GetInt32());
    }

    [Fact]
    public async Task GetAvisosHistorico_WithoutCondominioId_ReturnsEmptyPagedResult_NeverCallsService()
    {
        var userId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos/historico?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();

        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(0, itemsElement.GetArrayLength());
        Assert.Equal(0, content.GetProperty("totalCount").GetInt32());

        _mockSupabaseService.Verify(s => s.GetAvisosHistoricoAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }
}
