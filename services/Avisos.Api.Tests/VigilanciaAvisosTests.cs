using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Avisos.Api.Services;
using Avisos.Api.DTOs;
using Xunit;
using System.Security.Claims;
using System.IdentityModel.Tokens.Jwt;
using HavenApi.Shared.Pagination;

namespace Avisos.Api.Tests;

public class VigilanciaAvisosTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private readonly Mock<ISupabaseService> _mockSupabaseService;

    public VigilanciaAvisosTests()
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

    [Fact]
    public async Task GetAvisos_Vigilancia_ReturnsOk()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));
            
        _mockSupabaseService.Setup(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<PaginationParams>()))
            .ReturnsAsync((new List<AvisoDto>(), 0));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _mockSupabaseService.Verify(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<PaginationParams>()), Times.Once);
    }

    [Fact]
    public async Task GetAvisosHistorico_Vigilancia_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.GetAsync("/api/avisos/historico");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        _mockSupabaseService.Verify(s => s.GetAvisosHistoricoAsync(It.IsAny<Guid>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    [Fact]
    public async Task CreateAviso_Vigilancia_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new CreateAvisoRequestDto { Titulo = "T", Contenido = "C" };
        var response = await client.PostAsJsonAsync("/api/avisos", dto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        _mockSupabaseService.Verify(s => s.CreateAvisoAsync(It.IsAny<Guid>(), It.IsAny<CreateAvisoRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task UpdateAviso_Vigilancia_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var avisoId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new UpdateAvisoRequestDto { Titulo = "New T" };
        var response = await client.PutAsJsonAsync($"/api/avisos/{avisoId}", dto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        _mockSupabaseService.Verify(s => s.UpdateAvisoAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<UpdateAvisoRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task DeleteAviso_Vigilancia_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var avisoId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var response = await client.DeleteAsync($"/api/avisos/{avisoId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        _mockSupabaseService.Verify(s => s.DeleteAvisoAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }
}
