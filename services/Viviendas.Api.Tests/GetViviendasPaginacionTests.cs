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

public class GetViviendasPaginacionTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public GetViviendasPaginacionTests()
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

    [Fact]
    public async Task GetViviendas_WithPaginationParams_PassesParamsToService()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();

        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedViviendas = new List<ViviendaDto>
        {
            new ViviendaDto { Id = 1, CondominioId = condominioId, NumeroCasa = "1A" }
        };

        PaginationParams capturedParams = null!;

        mockSupabaseService.Setup(s => s.GetViviendasAsync(condominioId, It.IsAny<PaginationParams>()))
            .Callback<Guid, PaginationParams>((id, p) => capturedParams = p)
            .ReturnsAsync((expectedViviendas, 1));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas?page=2&pageSize=5");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        mockSupabaseService.Verify(s => s.GetViviendasAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(2, capturedParams.Page);
        Assert.Equal(5, capturedParams.PageSize);
    }

    [Fact]
    public async Task GetViviendas_ReturnsCorrectPagedResultStructure()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();

        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedViviendas = new List<ViviendaDto>
        {
            new ViviendaDto { Id = 1, CondominioId = condominioId, NumeroCasa = "1A" }
        };

        mockSupabaseService.Setup(s => s.GetViviendasAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((expectedViviendas, 100));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas?page=2&pageSize=5");

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
        Assert.Equal(100, totalCountElement.GetInt32());
    }

    [Fact]
    public async Task GetViviendas_WithoutPaginationParams_UsesDefaultParams()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();

        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedViviendas = new List<ViviendaDto>();

        PaginationParams capturedParams = null!;

        mockSupabaseService.Setup(s => s.GetViviendasAsync(condominioId, It.IsAny<PaginationParams>()))
            .Callback<Guid, PaginationParams>((id, p) => capturedParams = p)
            .ReturnsAsync((expectedViviendas, 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        mockSupabaseService.Verify(s => s.GetViviendasAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(1, capturedParams.Page);
        Assert.Equal(20, capturedParams.PageSize);
    }
}
