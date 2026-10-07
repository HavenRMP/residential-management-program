using System.Net;
using System.Net.Http.Headers;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class RetirarResidenteCondominioTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public RetirarResidenteCondominioTests()
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
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{header}.{payload}.";
    }

    [Fact]
    public async Task RetirarResidente_WithoutToken_ReturnsUnauthorized()
    {
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RetirarResidente_UserResidente_ReturnsForbidden()
    {
        var adminId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.ResidenteNombre });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RetirarResidente_UserVigilancia_ReturnsForbidden()
    {
        var adminId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.VigilanciaNombre });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RetirarResidente_AdminWithoutCondominioId_ReturnsBadRequest()
    {
        var adminId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = null });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RetirarResidente_UserNotFound_ReturnsNotFound()
    {
        var adminId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync((UsuarioDto?)null);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RetirarResidente_AdminValidAndServiceReturnsTrue_ReturnsNoContent()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId), Times.Once);
    }

    [Fact]
    public async Task RetirarResidente_AdminValidAndServiceReturnsFalse_ReturnsNotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ReturnsAsync(false);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId), Times.Once);
    }

    [Fact]
    public async Task RetirarResidente_IgnoresCondominioIdInQueryAndUsesAdminCondominioId()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var fakeCondominioIdFromMischief = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio?condominioId={fakeCondominioIdFromMischief}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId), Times.Once);
    }

    [Fact]
    public async Task RetirarResidente_ServiceThrowsSupabaseRpcExceptionRC001_ReturnsNotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ThrowsAsync(new SupabaseRpcException("RC001", "Usuario no existe"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task RetirarResidente_ServiceThrowsSupabaseRpcExceptionRC002_ReturnsBadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ThrowsAsync(new SupabaseRpcException("RC002", "El usuario no tiene el rol de Residente"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task RetirarResidente_ServiceThrowsSupabaseRpcExceptionRC003_ReturnsConflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var residenteId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RetirarResidenteCondominioAsync(residenteId, condominioId, adminId))
            .ThrowsAsync(new SupabaseRpcException("RC003", "El usuario no pertenece al condominio"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var response = await client.DeleteAsync($"/api/Residentes/{residenteId}/condominio");

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }
}
