using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Avisos.Api.DTOs;
using Avisos.Api.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using Xunit;

namespace Avisos.Api.Tests;

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
    public async Task CreateAviso_PrioridadUrgente_LlamaAltaNotificacionPorCadaResidente()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var avisoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var res1 = Guid.NewGuid();
        var res2 = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("alta_aviso"))
            {
                var responseAviso = new AvisoDto { Id = avisoId, CondominioId = condominioId, Titulo = "Test Urgente" };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseAviso)
                };
            }
            if (url.Contains("vw_usuarios"))
            {
                var resList = new[]
                {
                    new { id = res1 },
                    new { id = res2 }
                };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(resList)
                };
            }
            if (url.Contains("alta_notificacion"))
            {
                return new HttpResponseMessage(HttpStatusCode.OK);
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);
        var dto = new CreateAvisoRequestDto { Titulo = "Test Urgente", Contenido = "Contenido", Prioridad = "urgente" };

        // Act
        var (result, error) = await service.CreateAvisoAsync(Guid.NewGuid(), dto);

        // Assert
        Assert.Null(error);
        Assert.NotNull(result);
        Assert.Equal(avisoId, result!.Id);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Equal(2, notifRequests.Count);

        // Validar payload
        var req1Str = notifRequests[0].Content?.ReadAsStringAsync().Result ?? "";
        var req2Str = notifRequests[1].Content?.ReadAsStringAsync().Result ?? "";
        
        Assert.Contains(res1.ToString(), req1Str, StringComparison.OrdinalIgnoreCase);
        Assert.Contains(res2.ToString(), req2Str, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CreateAviso_PrioridadInformativo_NoLlamaAltaNotificacion()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var avisoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("alta_aviso"))
            {
                var responseAviso = new AvisoDto { Id = avisoId, CondominioId = condominioId, Titulo = "Test Informativo" };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseAviso)
                };
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);
        var dto = new CreateAvisoRequestDto { Titulo = "Test Informativo", Contenido = "Contenido", Prioridad = "informativo" };

        // Act
        var (result, error) = await service.CreateAvisoAsync(Guid.NewGuid(), dto);

        // Assert
        Assert.Null(error);
        Assert.NotNull(result);
        Assert.Equal(avisoId, result!.Id);

        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Empty(notifRequests);
    }

    [Fact]
    public async Task CreateAviso_FalloAlNotificar_NoRevierteCreacionDelAviso()
    {
        // Arrange
        var handler = new FakeHttpMessageHandler();
        var avisoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var res1 = Guid.NewGuid();

        handler.HandlerFunc = req =>
        {
            var url = req.RequestUri?.ToString() ?? "";
            if (url.Contains("alta_aviso"))
            {
                var responseAviso = new AvisoDto { Id = avisoId, CondominioId = condominioId, Titulo = "Test Urgente Fallo" };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(responseAviso)
                };
            }
            if (url.Contains("vw_usuarios"))
            {
                var resList = new[]
                {
                    new { id = res1 }
                };
                return new HttpResponseMessage(HttpStatusCode.OK)
                {
                    Content = JsonContent.Create(resList)
                };
            }
            if (url.Contains("alta_notificacion"))
            {
                // Simulamos un 500 al notificar
                return new HttpResponseMessage(HttpStatusCode.InternalServerError);
            }
            return new HttpResponseMessage(HttpStatusCode.NotFound);
        };

        var service = CreateService(handler);
        var dto = new CreateAvisoRequestDto { Titulo = "Test Urgente", Contenido = "Contenido", Prioridad = "urgente" };

        // Act
        var (result, error) = await service.CreateAvisoAsync(Guid.NewGuid(), dto);

        // Assert
        Assert.Null(error);
        Assert.NotNull(result);
        Assert.Equal(avisoId, result!.Id);

        // Igual se intentó notificar
        var notifRequests = handler.Requests.Where(r => r.RequestUri?.ToString().Contains("alta_notificacion") == true).ToList();
        Assert.Single(notifRequests);
    }
}
