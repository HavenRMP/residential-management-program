using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
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

public class RegisterVigilanteTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public RegisterVigilanteTests()
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
    public async Task RegisterVigilante_WithoutToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RegisterVigilante_UserResidente_ReturnsForbidden()
    {
        var adminId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.ResidenteNombre });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RegisterVigilante_UserVigilancia_ReturnsForbidden()
    {
        var adminId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.VigilanciaNombre });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RegisterVigilante_AdminWithoutCondominioId_ReturnsBadRequest()
    {
        var adminId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = null });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), It.IsAny<Guid>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task RegisterVigilante_AdminWithCondominioId_Success_ReturnsCreated()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        var expectedUser = new UsuarioDto { Id = Guid.NewGuid(), Email = "test@test.com", RolId = 3, CondominioId = condominioId };
        mockSupabaseService.Setup(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId))
            .ReturnsAsync((expectedUser, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId), Times.Once);
    }

    [Fact]
    public async Task RegisterVigilante_SendsAdminCondominioIdAlways()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var fakeCondominioIdFromMischief = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        var expectedUser = new UsuarioDto { Id = Guid.NewGuid(), Email = "test@test.com", RolId = 3, CondominioId = condominioId };
        mockSupabaseService.Setup(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId))
            .ReturnsAsync((expectedUser, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestObj = new { email = "test@test.com", password = "Password123", nombre = "A", apellidos = "B", telefono = "12345678", condominioId = fakeCondominioIdFromMischief };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestObj);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId), Times.Once);
    }

    [Fact]
    public async Task RegisterVigilante_EmailAlreadyRegistered_ReturnsConflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId))
            .ReturnsAsync((null, "El email ya esta registrado"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task RegisterVigilante_OtherError_ReturnsBadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetUsuarioByIdAsync(adminId, It.IsAny<string>(), adminId))
            .ReturnsAsync(new UsuarioDto { Id = adminId, Rol = RolesHaven.AdministradorNombre, CondominioId = condominioId });

        mockSupabaseService.Setup(s => s.RegisterVigilanteAsync(It.IsAny<RegisterRequestDto>(), condominioId, adminId))
            .ReturnsAsync((null, "Otro error"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", GenerateFakeToken(adminId));

        var requestDto = new RegisterRequestDto { Email = "test@test.com", Password = "Password123", Nombre = "A", Apellidos = "B", Telefono = "12345678" };
        var response = await client.PostAsJsonAsync("/api/Auth/register-vigilante", requestDto);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
