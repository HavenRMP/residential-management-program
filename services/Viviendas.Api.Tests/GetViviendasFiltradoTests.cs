using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class GetViviendasFiltradoTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public GetViviendasFiltradoTests()
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

    [Fact]
    public async Task GetViviendas_UserWithCondominioId_ReturnsFilteredViviendas()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedViviendas = new List<ViviendaDto>
        {
            new ViviendaDto { Id = 1, CondominioId = condominioId, NumeroCasa = "1A" },
            new ViviendaDto { Id = 2, CondominioId = condominioId, NumeroCasa = "2B" }
        };

        mockSupabaseService.Setup(s => s.GetViviendasAsync(condominioId))
            .ReturnsAsync(expectedViviendas);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<List<JsonElement>>();
        Assert.NotNull(content);
        Assert.Equal(2, content.Count);
        Assert.Equal(1, content[0].GetProperty("id").GetInt32());
        Assert.Equal("1A", content[0].GetProperty("numeroCasa").GetString());

        mockSupabaseService.Verify(s => s.GetViviendasAsync(condominioId), Times.Once);
    }

    [Fact]
    public async Task GetViviendas_UserWithoutCondominioId_ReturnsEmptyList_NeverCallsService()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/viviendas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<List<JsonElement>>();
        Assert.NotNull(content);
        Assert.Empty(content);

        mockSupabaseService.Verify(s => s.GetViviendasAsync(It.IsAny<Guid>()), Times.Never);
    }
}

// Requerido por ReadFromJsonAsync de arriba para un test limpio, usamos JsonElement o clases genericas.
