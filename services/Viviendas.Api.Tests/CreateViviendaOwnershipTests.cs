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
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class CreateViviendaOwnershipTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public CreateViviendaOwnershipTests()
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
    public async Task CreateVivienda_AdminWithCondominioId_ForcesCondominioIdFromContext()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var expectedCondominioId = Guid.NewGuid();
        var fakeCondominioIdInBody = Guid.NewGuid(); // To simulate someone trying to inject a different CondominioId

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", expectedCondominioId));

        mockSupabaseService.Setup(s => s.CreateViviendaAsync(It.IsAny<CreateViviendaRequestDto>(), expectedCondominioId))
            .ReturnsAsync((new ViviendaDto { Id = 1, CondominioId = expectedCondominioId }, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new { NumeroCasa = "123", Tipo = "Casa", CondominioId = fakeCondominioIdInBody };

        // Act
        var response = await client.PostAsJsonAsync("/api/viviendas", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockSupabaseService.Verify(s => s.CreateViviendaAsync(It.IsAny<CreateViviendaRequestDto>(), expectedCondominioId), Times.Once);
    }

    [Fact]
    public async Task CreateVivienda_AdminWithoutCondominioId_ReturnsBadRequest_NeverCallsCreate()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new { NumeroCasa = "123", Tipo = "Casa" };

        // Act
        var response = await client.PostAsJsonAsync("/api/viviendas", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockSupabaseService.Verify(s => s.CreateViviendaAsync(It.IsAny<CreateViviendaRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }
}
