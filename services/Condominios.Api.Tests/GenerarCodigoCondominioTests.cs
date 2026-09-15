using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using Condominios.Api.DTOs;
using Condominios.Api.Services;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Xunit;

namespace Condominios.Api.Tests;

public class GenerarCodigoCondominioTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public GenerarCodigoCondominioTests()
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
    public async Task GenerarCodigo_UserNotAdministrador_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId)); // Rol distinto de Administrador

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/condominios/{condominioId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GenerarCodigoCondominioAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GenerarCodigo_MismatchCondominioId_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioDelAdmin = Guid.NewGuid();
        var condominioTarget = Guid.NewGuid(); // Distinto

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioDelAdmin));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/condominios/{condominioTarget}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GenerarCodigoCondominioAsync(It.IsAny<Guid>(), It.IsAny<int?>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GenerarCodigo_AdministradorMatchCondominio_ReturnsOkWithCodigo()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        var expectedResult = new CodigoCondominioDto
        {
            Codigo = "GHIJKL",
            ExpiraEn = DateTime.UtcNow.AddMinutes(60)
        };

        mockSupabaseService.Setup(s => s.GenerarCodigoCondominioAsync(condominioId, 60, userId))
            .ReturnsAsync(expectedResult);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/condominios/{condominioId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<CodigoCondominioDto>();
        Assert.NotNull(content);
        Assert.Equal("GHIJKL", content.Codigo);
    }

    [Fact]
    public async Task GenerarCodigo_RpcExceptionThrown_MapsToCorrectStatusCode()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        mockSupabaseService.Setup(s => s.GenerarCodigoCondominioAsync(condominioId, 60, userId))
            .ThrowsAsync(new SupabaseRpcException("CD002", "Ya existe un código activo"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/condominios/{condominioId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }
}
