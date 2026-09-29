using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class SupabaseServiceNotificacionesTests
{
    private class FakeHttpMessageHandler : HttpMessageHandler
    {
        public Func<HttpRequestMessage, HttpResponseMessage>? HandlerFunc { get; set; }
        public List<HttpRequestMessage> Requests { get; } = new();

        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request, CancellationToken cancellationToken)
        {
            Requests.Add(request);
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

        return new SupabaseService(httpClient, configMock.Object, loggerMock.Object);
    }

    [Fact]
    public async Task RegistrarEntrada_CreadoPorInformado_LlamaAltaNotificacion()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var visitaId = Guid.NewGuid();
        var creadoPor = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("registrar_entrada_visita"))
            {
                var responseVisita = new VisitaDto 
                { 
                    Id = visitaId, 
                    CreadoPor = creadoPor,
                    NombreVisitante = "Juan",
                    ApellidosVisitante = "Pérez"
                };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseVisita)
                };
            }
            if (url.Contains("alta_notificacion"))
            {
                return new HttpResponseMessage(HttpStatusCode.OK);
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);

        // Act
        var result = await service.RegistrarEntradaAsync(visitaId, Guid.NewGuid());

        // Assert
        Assert.NotNull(result);
        Assert.Equal(visitaId, result.Id);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Single(notifRequests);

        var reqStr = notifRequests[0].Content?.ReadAsStringAsync().Result ?? "";
        Assert.Contains(creadoPor.ToString(), reqStr, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task RegistrarEntrada_FalloAlNotificar_NoRevierteRegistro()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var visitaId = Guid.NewGuid();
        var creadoPor = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("registrar_entrada_visita"))
            {
                var responseVisita = new VisitaDto 
                { 
                    Id = visitaId, 
                    CreadoPor = creadoPor,
                    NombreVisitante = "Juan",
                    ApellidosVisitante = "Pérez"
                };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseVisita)
                };
            }
            if (url.Contains("alta_notificacion"))
            {
                return new HttpResponseMessage(HttpStatusCode.InternalServerError);
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);

        // Act
        var result = await service.RegistrarEntradaAsync(visitaId, Guid.NewGuid());

        // Assert
        Assert.NotNull(result);
        Assert.Equal(visitaId, result.Id);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Single(notifRequests);
    }

    [Fact]
    public async Task RegistrarEntrada_RpcFalla_LanzaSupabaseRpcExceptionYNoNotifica()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        
        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("registrar_entrada_visita"))
            {
                var errorResponse = new { code = "VI006", message = "Visita no válida" };
                return new HttpResponseMessage(HttpStatusCode.BadRequest)
                {
                    Content = JsonContent.Create(errorResponse)
                };
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<SupabaseRpcException>(() => service.RegistrarEntradaAsync(Guid.NewGuid(), Guid.NewGuid()));
        Assert.Equal("VI006", ex.Code);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Empty(notifRequests);
    }

    [Fact]
    public async Task RegistrarEntrada_CreadoPorNulo_NoNotifica()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var visitaId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("registrar_entrada_visita"))
            {
                var responseVisita = new VisitaDto 
                { 
                    Id = visitaId, 
                    CreadoPor = null,
                    NombreVisitante = "Juan",
                    ApellidosVisitante = "Pérez"
                };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseVisita)
                };
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);

        // Act
        var result = await service.RegistrarEntradaAsync(visitaId, Guid.NewGuid());

        // Assert
        Assert.NotNull(result);
        Assert.Equal(visitaId, result.Id);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Empty(notifRequests);
    }
}
