using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using Moq;
using Xunit;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Services;
using Reservas.Api.DTOs;
using Reservas.Api.Options;
using Reservas.Api.Services;
using Reservas.Api.Workers;

namespace Reservas.Api.Tests;

public class PushNotificationWorkerTests
{
    private readonly Mock<INotificacionesPushClient> _mockClient = new();
    private readonly Mock<IFirebaseNotificationService> _mockFirebase = new();
    private readonly Mock<ILogger<PushNotificationWorker>> _mockLogger = new();
    private readonly Mock<IServiceScopeFactory> _mockScopeFactory = new();

    private PushNotificationWorker CreateWorker(int batchSize = 50, int intervalSeconds = 30, bool enabled = true)
    {
        var mockScope = new Mock<IServiceScope>();
        var mockServiceProvider = new Mock<IServiceProvider>();

        mockServiceProvider
            .Setup(sp => sp.GetService(typeof(INotificacionesPushClient)))
            .Returns(_mockClient.Object);

        mockScope
            .Setup(s => s.ServiceProvider)
            .Returns(mockServiceProvider.Object);

        _mockScopeFactory
            .Setup(f => f.CreateScope())
            .Returns(mockScope.Object);

        var options = Microsoft.Extensions.Options.Options.Create(new PushWorkerOptions
        {
            BatchSize = batchSize,
            IntervalSeconds = intervalSeconds,
            Enabled = enabled
        });

        return new PushNotificationWorker(
            _mockFirebase.Object,
            options,
            _mockScopeFactory.Object,
            _mockLogger.Object);
    }

    [Fact]
    public async Task ProcesarLoteAsync_SinNotificacionesPendientes_NoLlamaAFirebaseNiAMarcarOLiberar()
    {
        // Arrange
        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto>());

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockFirebase.Verify(
            f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()),
            Times.Never);
        _mockClient.Verify(
            c => c.MarcarEnviadaAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
        _mockClient.Verify(
            c => c.LiberarAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()),
            Times.Never);
    }

    [Fact]
    public async Task ProcesarLoteAsync_UnaNotificacionEnvioExitoso_EnviaAFirebaseYMarcaEnviada()
    {
        // Arrange
        var notifId = Guid.NewGuid();
        var usuarioId = Guid.Parse("7c9e6679-7425-40de-944b-e07fc1f90ae7");
        var reservaId = Guid.Parse("3fa85f64-5717-4562-b3fc-2c963f66afa6");

        var notificacion = new NotificacionPushPendienteDto
        {
            Id = notifId,
            UsuarioId = usuarioId,
            TipoEvento = "reserva_aprobada",
            Titulo = "Reserva Aprobada",
            Mensaje = "Tu reserva para la Alberca Principal ha sido aprobada.",
            UrlRedireccion = "/reservas/3fa85f64-5717-4562-b3fc-2c963f66afa6",
            ReservaId = reservaId
        };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notificacion });

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.MarcarEnviadaAsync(notifId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        var expectedTopic = "user" + usuarioId.ToString("N");
        _mockFirebase.Verify(
            f => f.SendToTopicAsync(
                expectedTopic,
                "Reserva Aprobada",
                "Tu reserva para la Alberca Principal ha sido aprobada.",
                It.Is<Dictionary<string, string>>(data =>
                    data["tipo"] == "reserva_aprobada" &&
                    data["reserva_id"] == reservaId.ToString() &&
                    data["click_action"] == "FLUTTER_NOTIFICATION_CLICK" &&
                    data["url_redireccion"] == "/reservas/3fa85f64-5717-4562-b3fc-2c963f66afa6")),
            Times.Once);

        _mockClient.Verify(c => c.MarcarEnviadaAsync(notifId, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.LiberarAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcesarLoteAsync_MarcarEnviadaDevuelveFalse_RegistraAdvertenciaYContinua()
    {
        // Arrange
        var notifId = Guid.NewGuid();
        var notificacion = new NotificacionPushPendienteDto
        {
            Id = notifId,
            UsuarioId = Guid.NewGuid(),
            TipoEvento = "reserva_aprobada",
            Titulo = "Reserva Aprobada",
            Mensaje = "Mensaje",
            ReservaId = Guid.NewGuid()
        };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notificacion });

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.MarcarEnviadaAsync(notifId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(false);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockClient.Verify(c => c.MarcarEnviadaAsync(notifId, It.IsAny<CancellationToken>()), Times.Once);
        _mockLogger.Verify(
            l => l.Log(
                LogLevel.Warning,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => v != null && v.ToString()!.Contains(notifId.ToString())),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce);
    }

    [Fact]
    public async Task ProcesarLoteAsync_NotificacionSinReservaId_DatosNoIncluyenReservaId()
    {
        // Arrange
        var notifId = Guid.NewGuid();
        var notificacion = new NotificacionPushPendienteDto
        {
            Id = notifId,
            UsuarioId = Guid.NewGuid(),
            TipoEvento = "notificacion_general",
            Titulo = "Aviso",
            Mensaje = "Mensaje general",
            ReservaId = null
        };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notificacion });

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.MarcarEnviadaAsync(notifId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockFirebase.Verify(
            f => f.SendToTopicAsync(
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.IsAny<string>(),
                It.Is<Dictionary<string, string>>(data =>
                    data["tipo"] == "notificacion_general" &&
                    data["click_action"] == "FLUTTER_NOTIFICATION_CLICK" &&
                    !data.ContainsKey("reserva_id"))),
            Times.Once);
    }

    [Fact]
    public async Task ProcesarLoteAsync_FirebaseDevuelveFalse_LiberaNotificacion()
    {
        // Arrange
        var notifId = Guid.NewGuid();
        var notificacion = new NotificacionPushPendienteDto
        {
            Id = notifId,
            UsuarioId = Guid.NewGuid(),
            TipoEvento = "reserva_rechazada",
            Titulo = "Reserva Rechazada",
            Mensaje = "Tu reserva ha sido rechazada.",
            ReservaId = Guid.NewGuid()
        };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notificacion });

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(false);

        _mockClient
            .Setup(c => c.LiberarAsync(notifId, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockClient.Verify(c => c.LiberarAsync(notifId, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.MarcarEnviadaAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Never);
    }

    [Fact]
    public async Task ProcesarLoteAsync_FirebaseLanzaExcepcion_LiberaNotificacionYContinuaLote()
    {
        // Arrange
        var notif1 = new NotificacionPushPendienteDto
        {
            Id = Guid.NewGuid(),
            UsuarioId = Guid.NewGuid(),
            TipoEvento = "reserva_aprobada",
            Titulo = "Titulo 1",
            Mensaje = "Mensaje 1"
        };
        var notif2 = new NotificacionPushPendienteDto
        {
            Id = Guid.NewGuid(),
            UsuarioId = Guid.NewGuid(),
            TipoEvento = "reserva_aprobada",
            Titulo = "Titulo 2",
            Mensaje = "Mensaje 2"
        };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notif1, notif2 });

        var topic1 = FirebaseTopics.GetUserTopic(notif1.UsuarioId);
        var topic2 = FirebaseTopics.GetUserTopic(notif2.UsuarioId);

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(topic1, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ThrowsAsync(new Exception("Firebase connection timeout"));

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(topic2, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.LiberarAsync(notif1.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.MarcarEnviadaAsync(notif2.Id, It.IsAny<CancellationToken>()))
            .ReturnsAsync(true);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockClient.Verify(c => c.LiberarAsync(notif1.Id, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.MarcarEnviadaAsync(notif2.Id, It.IsAny<CancellationToken>()), Times.Once);
    }

    [Fact]
    public async Task ProcesarLoteAsync_LoteConTresNotificacionesExitoFalloExito_MarcaDosYLiberaUna()
    {
        // Arrange
        var notif1 = new NotificacionPushPendienteDto { Id = Guid.NewGuid(), UsuarioId = Guid.NewGuid(), TipoEvento = "evento1" };
        var notif2 = new NotificacionPushPendienteDto { Id = Guid.NewGuid(), UsuarioId = Guid.NewGuid(), TipoEvento = "evento2" };
        var notif3 = new NotificacionPushPendienteDto { Id = Guid.NewGuid(), UsuarioId = Guid.NewGuid(), TipoEvento = "evento3" };

        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto> { notif1, notif2, notif3 });

        var topic1 = FirebaseTopics.GetUserTopic(notif1.UsuarioId);
        var topic2 = FirebaseTopics.GetUserTopic(notif2.UsuarioId);
        var topic3 = FirebaseTopics.GetUserTopic(notif3.UsuarioId);

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(topic1, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(topic2, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(false);

        _mockFirebase
            .Setup(f => f.SendToTopicAsync(topic3, It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()))
            .ReturnsAsync(true);

        _mockClient.Setup(c => c.MarcarEnviadaAsync(notif1.Id, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _mockClient.Setup(c => c.LiberarAsync(notif2.Id, It.IsAny<CancellationToken>())).ReturnsAsync(true);
        _mockClient.Setup(c => c.MarcarEnviadaAsync(notif3.Id, It.IsAny<CancellationToken>())).ReturnsAsync(true);

        var worker = CreateWorker();

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockClient.Verify(c => c.MarcarEnviadaAsync(notif1.Id, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.LiberarAsync(notif2.Id, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.MarcarEnviadaAsync(notif3.Id, It.IsAny<CancellationToken>()), Times.Once);
        _mockClient.Verify(c => c.MarcarEnviadaAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Exactly(2));
        _mockClient.Verify(c => c.LiberarAsync(It.IsAny<Guid>(), It.IsAny<CancellationToken>()), Times.Exactly(1));
    }

    [Fact]
    public async Task ProcesarLoteAsync_ClienteReclamarLanzaExcepcion_SeRegistraYNoRevienta()
    {
        // Arrange
        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(It.IsAny<int>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new SupabaseUnavailableException("Supabase no responde"));

        var worker = CreateWorker();

        // Act
        var exception = await Record.ExceptionAsync(() => worker.ProcesarLoteAsync(CancellationToken.None));

        // Assert
        Assert.Null(exception);
        _mockFirebase.Verify(
            f => f.SendToTopicAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<string>(), It.IsAny<Dictionary<string, string>>()),
            Times.Never);
        _mockLogger.Verify(
            l => l.Log(
                LogLevel.Error,
                It.IsAny<EventId>(),
                It.Is<It.IsAnyType>((v, t) => true),
                It.IsAny<Exception?>(),
                It.IsAny<Func<It.IsAnyType, Exception?, string>>()),
            Times.AtLeastOnce);
    }

    [Fact]
    public async Task ProcesarLoteAsync_BatchSizeConfigurado_EsElLimiteQueSePasaAlReclamar()
    {
        // Arrange
        const int batchSizeConfigurado = 42;
        _mockClient
            .Setup(c => c.ReclamarPendientesAsync(batchSizeConfigurado, It.IsAny<CancellationToken>()))
            .ReturnsAsync(new List<NotificacionPushPendienteDto>());

        var worker = CreateWorker(batchSize: batchSizeConfigurado);

        // Act
        await worker.ProcesarLoteAsync(CancellationToken.None);

        // Assert
        _mockClient.Verify(c => c.ReclamarPendientesAsync(batchSizeConfigurado, It.IsAny<CancellationToken>()), Times.Once);
    }
}
