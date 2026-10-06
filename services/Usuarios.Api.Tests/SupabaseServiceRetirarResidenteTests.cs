using System.Net;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class SupabaseServiceRetirarResidenteTests
{
    private class FakeHttpMessageHandler : HttpMessageHandler
    {
        public Func<HttpRequestMessage, HttpResponseMessage>? HandlerFunc { get; set; }
        public HttpRequestMessage? LastRequest { get; private set; }
        public string LastRequestContent { get; private set; } = "";

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastRequest = request;
            if (request.Content != null)
            {
                // Read synchronously so we don't hit ObjectDisposedException later
                LastRequestContent = request.Content.ReadAsStringAsync(cancellationToken).GetAwaiter().GetResult();
            }
            if (HandlerFunc != null)
            {
                return Task.FromResult(HandlerFunc(request));
            }
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.NotFound));
        }
    }

    private SupabaseService CreateService(FakeHttpMessageHandler handler)
    {
        var httpClient = new HttpClient(handler);
        var configMock = new Mock<IConfiguration>();
        configMock.Setup(c => c["Supabase:Url"]).Returns("https://fake.supabase.co");
        configMock.Setup(c => c["Supabase:AnonKey"]).Returns("fake_anon_key");
        configMock.Setup(c => c["Supabase:ServiceRoleKey"]).Returns("fake_service_role_key");
        
        var loggerMock = new Mock<ILogger<SupabaseService>>();
        var firebaseMock = new Mock<HavenApi.Shared.Services.IFirebaseNotificationService>();

        return new SupabaseService(httpClient, configMock.Object, loggerMock.Object, firebaseMock.Object);
    }

    [Fact]
    public async Task RetirarResidenteCondominioAsync_RpcResponde200True_ReturnsTrueAndChecksHeadersAndPayload()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var usuarioId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var actorId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.EndsWith("/rest/v1/rpc/retirar_residente_condominio"))
            {
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = new StringContent("true", System.Text.Encoding.UTF8, "application/json")
                };
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);

        // Act
        var result = await service.RetirarResidenteCondominioAsync(usuarioId, condominioId, actorId);

        // Assert
        Assert.True(result);

        Assert.NotNull(handler.LastRequest);
        Assert.EndsWith("/rest/v1/rpc/retirar_residente_condominio", handler.LastRequest.RequestUri?.ToString());

        var reqContent = handler.LastRequestContent;
        using var jsonDoc = JsonDocument.Parse(reqContent);
        var root = jsonDoc.RootElement;
        
        Assert.Equal(2, root.EnumerateObject().Count());
        Assert.Equal(usuarioId, root.GetProperty("p_usuario_id").GetGuid());
        Assert.Equal(condominioId, root.GetProperty("p_condominio_id").GetGuid());

        Assert.True(handler.LastRequest.Headers.TryGetValues("apikey", out var apikeyValues));
        Assert.Contains("fake_service_role_key", apikeyValues);

        Assert.Equal("Bearer", handler.LastRequest.Headers.Authorization?.Scheme);
        Assert.Equal("fake_service_role_key", handler.LastRequest.Headers.Authorization?.Parameter);

        Assert.True(handler.LastRequest.Headers.TryGetValues("x-actor-id", out var actorIdValues));
        Assert.Contains(actorId.ToString(), actorIdValues);
    }

    [Fact]
    public async Task RetirarResidenteCondominioAsync_RpcResponde200Null_ReturnsFalse()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var usuarioId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var actorId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            return new HttpResponseMessage(HttpStatusCode.OK)
            {
                Content = new StringContent("null", System.Text.Encoding.UTF8, "application/json")
            };
        };

        var service = CreateService(handler);

        // Act
        var result = await service.RetirarResidenteCondominioAsync(usuarioId, condominioId, actorId);

        // Assert
        Assert.False(result);
    }

    [Fact]
    public async Task RetirarResidenteCondominioAsync_RpcResponde400Error_ThrowsSupabaseRpcExceptionWithCode()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var usuarioId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var actorId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var body = "{\"code\":\"RC003\",\"message\":\"Mensaje\"}";
            return new HttpResponseMessage(HttpStatusCode.BadRequest)
            {
                Content = new StringContent(body, System.Text.Encoding.UTF8, "application/json")
            };
        };

        var service = CreateService(handler);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<SupabaseRpcException>(() =>
            service.RetirarResidenteCondominioAsync(usuarioId, condominioId, actorId));

        Assert.Equal("RC003", ex.Code);
    }

    [Fact]
    public async Task RetirarResidenteCondominioAsync_RpcResponde500Malformed_ThrowsSupabaseRpcExceptionWithUnknownCode()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var usuarioId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var actorId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            return new HttpResponseMessage(HttpStatusCode.InternalServerError)
            {
                Content = new StringContent("Internal Server Error")
            };
        };

        var service = CreateService(handler);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<SupabaseRpcException>(() =>
            service.RetirarResidenteCondominioAsync(usuarioId, condominioId, actorId));

        Assert.Equal("UNKNOWN", ex.Code);
    }
}
