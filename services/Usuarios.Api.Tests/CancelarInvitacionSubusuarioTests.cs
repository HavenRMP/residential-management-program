using System.Net;
using System.Net.Http.Headers;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class CancelarInvitacionSubusuarioTests
{
    private readonly int _viviendaId = 100;

    public CancelarInvitacionSubusuarioTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");
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
    public async Task RevocarSubusuario_IsInvitacion_NoToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        var invitacionId = Guid.NewGuid();

        var response = await client.DeleteAsync($"/api/Subusuarios/{invitacionId}?viviendaId={_viviendaId}&isInvitacion=true");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.CancelarInvitacionSubusuarioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }

    [Fact]
    public async Task RevocarSubusuario_IsInvitacion_Success_ReturnsNoContent()
    {
        var userId = Guid.NewGuid();
        var invitacionId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelarInvitacionSubusuarioAsync(invitacionId, userId, token))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/Subusuarios/{invitacionId}?viviendaId={_viviendaId}&isInvitacion=true");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.CancelarInvitacionSubusuarioAsync(invitacionId, userId, token), Times.Once);
    }

    [Fact]
    public async Task RevocarSubusuario_IsInvitacion_FalseResult_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var invitacionId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelarInvitacionSubusuarioAsync(invitacionId, userId, token))
            .ReturnsAsync(false);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/Subusuarios/{invitacionId}?viviendaId={_viviendaId}&isInvitacion=true");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Theory]
    [InlineData("P0002", HttpStatusCode.NotFound)]
    [InlineData("42501", HttpStatusCode.Forbidden)]
    [InlineData("SU004", HttpStatusCode.BadRequest)]
    [InlineData("22023", HttpStatusCode.BadRequest)]
    [InlineData("UNKNOWN", HttpStatusCode.InternalServerError)]
    public async Task RevocarSubusuario_IsInvitacion_RpcExceptions_ReturnsExpectedStatus(string code, HttpStatusCode expectedStatus)
    {
        var userId = Guid.NewGuid();
        var invitacionId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelarInvitacionSubusuarioAsync(invitacionId, userId, token))
            .ThrowsAsync(new SupabaseRpcException(code, "Mensaje"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/Subusuarios/{invitacionId}?viviendaId={_viviendaId}&isInvitacion=true");

        Assert.Equal(expectedStatus, response.StatusCode);
    }

    [Fact]
    public async Task RevocarSubusuario_IsNotInvitacion_Success_ReturnsNoContent_AndProtectsExistingFlow()
    {
        var userId = Guid.NewGuid();
        var id = Guid.NewGuid();
        var token = GenerateFakeToken(userId);

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RevocarSubusuarioAsync(_viviendaId, id, token))
            .ReturnsAsync((true, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/Subusuarios/{id}?viviendaId={_viviendaId}&isInvitacion=false");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.RevocarSubusuarioAsync(_viviendaId, id, token), Times.Once);
        mockSupabaseService.Verify(s => s.CancelarInvitacionSubusuarioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
        mockSupabaseService.Verify(s => s.CancelarInvitacionAsync(It.IsAny<Guid>(), It.IsAny<string>()), Times.Never);
    }
}
