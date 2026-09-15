using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class RedimirCodigoViviendaTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public RedimirCodigoViviendaTests()
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
        
        var expectedDto = new RedimirViviendaResultDto
        {
            Vivienda = new ViviendaDto { Id = 100 }
        };

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RedimirCodigoViviendaAsync("CODE123", userId, userId))
            .ReturnsAsync(expectedDto);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE123" };
        var response = await client.PostAsJsonAsync("/api/codigos/vivienda/redimir", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.RedimirCodigoViviendaAsync("CODE123", userId, userId), Times.Once);
        
        var content = await response.Content.ReadFromJsonAsync<RedimirViviendaResultDto>();
        Assert.NotNull(content);
        Assert.Equal(expectedDto.Vivienda.Id, content.Vivienda.Id);
    }

    [Fact]
    public async Task RedimirCodigo_RpcExceptionCD002_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RedimirCodigoViviendaAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<Guid>()))
            .ThrowsAsync(new SupabaseRpcException("CD002", "El usuario ya reside en esa vivienda"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE123" };
        var response = await client.PostAsJsonAsync("/api/codigos/vivienda/redimir", requestBody);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task RedimirCodigo_RpcExceptionCD003_ReturnsGone()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RedimirCodigoViviendaAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<Guid>()))
            .ThrowsAsync(new SupabaseRpcException("CD003", "El código ha expirado"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE123" };
        var response = await client.PostAsJsonAsync("/api/codigos/vivienda/redimir", requestBody);

        Assert.Equal(HttpStatusCode.Gone, response.StatusCode);
    }

    [Fact]
    public async Task RedimirCodigo_NoJwt_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        
        // No enviamos authorization header
        var requestBody = new RedimirCodigoRequestDto { Codigo = "CODE123" };
        var response = await client.PostAsJsonAsync("/api/codigos/vivienda/redimir", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.RedimirCodigoViviendaAsync(It.IsAny<string>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }
}
