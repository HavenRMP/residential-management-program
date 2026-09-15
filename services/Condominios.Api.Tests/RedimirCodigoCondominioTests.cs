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

public class RedimirCodigoCondominioTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public RedimirCodigoCondominioTests()
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
    public async Task RedimirCodigo_ValidJwt_UsesUserIdFromTokenAndReturnsOk()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var expectedDto = new UsuarioResumenDto
        {
            Id = userId,
            Nombre = "Juan Perez",
            Email = "juan@example.com",
            CondominioId = Guid.NewGuid(),
            RolNombre = "Administrador"
        };

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RedimirCodigoCondominioAsync("CODE456", userId, userId))
            .ReturnsAsync(expectedDto);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE456" };
        var response = await client.PostAsJsonAsync("/api/codigos/condominio/redimir", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.RedimirCodigoCondominioAsync("CODE456", userId, userId), Times.Once);
        
        var content = await response.Content.ReadFromJsonAsync<UsuarioResumenDto>();
        Assert.NotNull(content);
        Assert.Equal(expectedDto.Id, content.Id);
        Assert.Equal(expectedDto.CondominioId, content.CondominioId);
    }

    [Fact]
    public async Task RedimirCodigo_RpcExceptionCD004_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RedimirCodigoCondominioAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<Guid>()))
            .ThrowsAsync(new SupabaseRpcException("CD004", "El usuario ya pertenece a otro condominio"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE456" };
        var response = await client.PostAsJsonAsync("/api/codigos/condominio/redimir", requestBody);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task RedimirCodigo_NoJwt_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        
        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE456" };
        var response = await client.PostAsJsonAsync("/api/codigos/condominio/redimir", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.RedimirCodigoCondominioAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }
}
