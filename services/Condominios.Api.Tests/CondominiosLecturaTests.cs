using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Condominios.Api.DTOs;
using Condominios.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Xunit;

namespace Condominios.Api.Tests;

public class CondominiosLecturaTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public CondominiosLecturaTests()
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
        var handler = new JwtSecurityTokenHandler();
        var token = new JwtSecurityToken(claims: new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim("sub", userId.ToString())
        });
        return handler.WriteToken(token);
    }

    // ---------------------------------------------------------
    // GET /api/condominios
    // ---------------------------------------------------------

    [Fact]
    public async Task GetCondominios_UsuarioConCondominioId_LlamaAlServicio_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedList = new List<CondominioDto>
        {
            new CondominioDto { Id = condominioId, Nombre = "Condominio Alpha" }
        };

        mockSupabaseService.Setup(s => s.GetCondominiosAsync(condominioId))
            .ReturnsAsync(expectedList);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/condominios");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<List<JsonElement>>();
        Assert.NotNull(content);
        Assert.Single(content);
        Assert.Equal(condominioId.ToString(), content[0].GetProperty("id").GetString());

        mockSupabaseService.Verify(s => s.GetCondominiosAsync(condominioId), Times.Once);
    }

    [Fact]
    public async Task GetCondominios_UsuarioSinCondominioId_RetornaVacio_NuncaLlamaAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/condominios");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<List<JsonElement>>();
        Assert.NotNull(content);
        Assert.Empty(content);

        mockSupabaseService.Verify(s => s.GetCondominiosAsync(It.IsAny<Guid>()), Times.Never);
    }

    // ---------------------------------------------------------
    // GET /api/condominios/{id}
    // ---------------------------------------------------------

    [Fact]
    public async Task GetCondominioById_IdCoincide_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
        
        mockSupabaseService.Setup(s => s.GetCondominioByIdAsync(condominioId))
            .ReturnsAsync(new CondominioDto { Id = condominioId, Nombre = "Condominio Alpha" });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/condominios/{condominioId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(condominioId.ToString(), content.GetProperty("id").GetString());
    }

    [Fact]
    public async Task GetCondominioById_IdNoCoincide_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioUsuarioId = Guid.NewGuid();
        var condominioRequestedId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioUsuarioId));
        
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/condominios/{condominioRequestedId}");

        // El requerimiento es claro: debe devolver 404, no 403, para no hacer leak de información.
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetCondominioByIdAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GetCondominioById_UsuarioSinCondominioId_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioRequestedId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/condominios/{condominioRequestedId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetCondominioByIdAsync(It.IsAny<Guid>()), Times.Never);
    }
}
