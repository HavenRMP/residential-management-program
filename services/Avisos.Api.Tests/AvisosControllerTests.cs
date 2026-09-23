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

namespace Avisos.Api.Tests;

public class AvisosControllerTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private readonly Mock<ISupabaseService> _mockSupabaseService;

    public AvisosControllerTests()
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
    public async Task GetAvisos_ReturnsOk_WithMockedData()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));
            
        _mockSupabaseService.Setup(s => s.GetAvisosVigentesAsync(condominioId, It.IsAny<HavenApi.Shared.Pagination.PaginationParams>()))
            .ReturnsAsync((new List<AvisoDto> { new AvisoDto { Id = Guid.NewGuid(), Titulo = "Test Aviso" } }, 1));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        // Act
        var response = await client.GetAsync("/api/avisos");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }
    
    [Fact]
    public async Task CreateAviso_ReturnsForbidden_WhenUserIsNotAdmin()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new CreateAvisoRequestDto { Titulo = "T", Contenido = "C" };

        // Act
        var response = await client.PostAsJsonAsync("/api/avisos", dto);

        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CreateAviso_ReturnsCreated_WhenUserIsAdmin()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        var avisoDto = new AvisoDto { Id = Guid.NewGuid(), Titulo = "T", Contenido = "C" };
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        _mockSupabaseService.Setup(s => s.CreateAvisoAsync(userId, It.IsAny<CreateAvisoRequestDto>()))
            .ReturnsAsync((avisoDto, null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new CreateAvisoRequestDto { Titulo = "T", Contenido = "C" };

        // Act
        var response = await client.PostAsJsonAsync("/api/avisos", dto);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
    }
    
    [Fact]
    public async Task UpdateAviso_ReturnsForbidden_WhenServiceReturnsCondominioError()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var avisoId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        _mockSupabaseService.Setup(s => s.UpdateAvisoAsync(avisoId, userId, It.IsAny<UpdateAvisoRequestDto>()))
            .ReturnsAsync((null, "El aviso no pertenece a su condominio"));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new UpdateAvisoRequestDto { Titulo = "New T" };

        // Act
        var response = await client.PutAsJsonAsync($"/api/avisos/{avisoId}", dto);

        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
    
    [Fact]
    public async Task DeleteAviso_ReturnsNoContent_WhenServiceReturnsOk()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var avisoId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        _mockSupabaseService.Setup(s => s.DeleteAvisoAsync(avisoId, userId))
            .ReturnsAsync((true, null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        // Act
        var response = await client.DeleteAsync($"/api/avisos/{avisoId}");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task CreateAviso_SinPrioridad_EnviaInformativoPorDefecto()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        var avisoDto = new AvisoDto { Id = Guid.NewGuid(), Titulo = "T", Contenido = "C" };
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        _mockSupabaseService.Setup(s => s.CreateAvisoAsync(userId, It.IsAny<CreateAvisoRequestDto>()))
            .ReturnsAsync((avisoDto, null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new CreateAvisoRequestDto { Titulo = "T", Contenido = "C" };

        // Act
        var response = await client.PostAsJsonAsync("/api/avisos", dto);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        _mockSupabaseService.Verify(s => s.CreateAvisoAsync(userId, It.Is<CreateAvisoRequestDto>(x => x.Prioridad == null)), Times.Once);
    }

    [Fact]
    public async Task UpdateAviso_ConPrioridad_PasaElValorAlServicio()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var avisoId = Guid.NewGuid();
        var token = GenerateMockJwt(userId);
        var avisoDto = new AvisoDto { Id = avisoId, Titulo = "T", Contenido = "C", Prioridad = "urgente" };
        
        _mockSupabaseService.Setup(s => s.GetUsuarioContextoAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
            
        _mockSupabaseService.Setup(s => s.UpdateAvisoAsync(avisoId, userId, It.IsAny<UpdateAvisoRequestDto>()))
            .ReturnsAsync((avisoDto, null));

        await using var application = CreateFactory();
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("Authorization", $"Bearer {token}");

        var dto = new UpdateAvisoRequestDto { Prioridad = "urgente" };

        // Act
        var response = await client.PutAsJsonAsync($"/api/avisos/{avisoId}", dto);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        _mockSupabaseService.Verify(s => s.UpdateAvisoAsync(avisoId, userId, It.Is<UpdateAvisoRequestDto>(x => x.Prioridad == "urgente")), Times.Once);
    }
}
