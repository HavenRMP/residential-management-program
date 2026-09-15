using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class AuthControllerResidentesTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public AuthControllerResidentesTests()
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
            new Claim("sub", userId.ToString()) // Just in case
        });
        return handler.WriteToken(token);
    }

    [Fact]
    public async Task GetResidentes_AdminWithCondominioId_ReturnsResidentes()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), It.IsAny<Guid>()))
            .ReturnsAsync(new UsuarioDto { Id = adminId, CondominioId = condominioId });

        var expectedResidentes = new List<UsuarioDto> 
        { 
            new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId } 
        };

        mockSupabaseService.Setup(s => s.GetResidentesAsync(condominioId))
            .ReturnsAsync(expectedResidentes);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/Auth/residentes");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetResidentesAsync(condominioId), Times.Once);
        
        var content = await response.Content.ReadFromJsonAsync<List<UsuarioDto>>();
        Assert.NotNull(content);
        Assert.Single(content);
    }

    [Fact]
    public async Task GetResidentes_AdminWithoutCondominioId_ReturnsEmptyArray()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), It.IsAny<Guid>()))
            .ReturnsAsync(new UsuarioDto { Id = adminId, CondominioId = null });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/Auth/residentes");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetResidentesAsync(It.IsAny<Guid>()), Times.Never);
        
        var content = await response.Content.ReadFromJsonAsync<List<UsuarioDto>>();
        Assert.NotNull(content);
        Assert.Empty(content);
    }

    [Fact]
    public async Task GetResidentes_SinViviendaTrue_ReturnsUnassignedResidentesOnly()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);

        var userA = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };
        var userB = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };
        var userC = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), It.IsAny<Guid>()))
            .ReturnsAsync(new UsuarioDto { Id = adminId, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.GetResidentesAsync(condominioId))
            .ReturnsAsync(new List<UsuarioDto> { userA, userB, userC });

        mockSupabaseService.Setup(s => s.GetViviendasResidentesAsync())
            .ReturnsAsync(new List<ViviendaResidentesDto>
            {
                new ViviendaResidentesDto 
                { 
                    Residentes = new List<UsuarioDto> { userA } 
                }
            });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/Auth/residentes?sinVivienda=true");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<List<UsuarioDto>>();
        Assert.NotNull(content);
        Assert.Equal(2, content.Count);
        Assert.DoesNotContain(content, u => u.Id == userA.Id);
        Assert.Contains(content, u => u.Id == userB.Id);
        Assert.Contains(content, u => u.Id == userC.Id);
    }

    [Fact]
    public async Task GetResidentes_SinViviendaFalse_ReturnsAllResidentes_DoesNotCallViviendas()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);

        var userA = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };
        var userB = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };
        var userC = new UsuarioDto { Id = Guid.NewGuid(), CondominioId = condominioId };

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), It.IsAny<Guid>()))
            .ReturnsAsync(new UsuarioDto { Id = adminId, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.GetResidentesAsync(condominioId))
            .ReturnsAsync(new List<UsuarioDto> { userA, userB, userC });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/Auth/residentes?sinVivienda=false");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.GetViviendasResidentesAsync(), Times.Never);

        var content = await response.Content.ReadFromJsonAsync<List<UsuarioDto>>();
        Assert.NotNull(content);
        Assert.Equal(3, content.Count);
    }
}
