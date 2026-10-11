using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using HavenApi.Shared.Services;
using Reservas.Api.Options;
using Reservas.Api.Services;

namespace Reservas.Api.Workers;

public class PushNotificationWorker : BackgroundService
{
    private readonly IFirebaseNotificationService _firebaseNotificationService;
    private readonly IOptions<PushWorkerOptions> _options;
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PushNotificationWorker> _logger;

    public PushNotificationWorker(
        IFirebaseNotificationService firebaseNotificationService,
        IOptions<PushWorkerOptions> options,
        IServiceScopeFactory scopeFactory,
        ILogger<PushNotificationWorker> logger)
    {
        _firebaseNotificationService = firebaseNotificationService;
        _options = options;
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        var options = _options.Value;
        if (!options.Enabled)
        {
            _logger.LogInformation("PushNotificationWorker está deshabilitado por configuración.");
            return;
        }

        using var timer = new PeriodicTimer(TimeSpan.FromSeconds(options.IntervalSeconds));

        try
        {
            while (await timer.WaitForNextTickAsync(stoppingToken))
            {
                try
                {
                    await ProcesarLoteAsync(stoppingToken);
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error durante la ejecución del ciclo de PushNotificationWorker.");
                }
            }
        }
        catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
        {
            _logger.LogInformation("PushNotificationWorker detenido por cancelación.");
        }
    }

    public async Task ProcesarLoteAsync(CancellationToken cancellationToken = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var client = scope.ServiceProvider.GetRequiredService<INotificacionesPushClient>();
        await ProcesarLoteAsync(client, cancellationToken);
    }

    public async Task ProcesarLoteAsync(INotificacionesPushClient client, CancellationToken cancellationToken = default)
    {
        var batchSize = _options.Value.BatchSize;
        var notificaciones = await client.ReclamarPendientesAsync(batchSize, cancellationToken);

        if (notificaciones == null || notificaciones.Count == 0)
        {
            return;
        }

        int enviadas = 0;
        int liberadas = 0;

        foreach (var notificacion in notificaciones)
        {
            cancellationToken.ThrowIfCancellationRequested();

            try
            {
                var topic = FirebaseTopics.GetUserTopic(notificacion.UsuarioId);
                var data = new Dictionary<string, string>
                {
                    { "tipo", notificacion.TipoEvento },
                    { "click_action", "FLUTTER_NOTIFICATION_CLICK" }
                };

                if (notificacion.ReservaId.HasValue)
                {
                    data["reserva_id"] = notificacion.ReservaId.Value.ToString();
                }

                if (!string.IsNullOrEmpty(notificacion.UrlRedireccion))
                {
                    data["url_redireccion"] = notificacion.UrlRedireccion;
                }

                bool enviado;
                try
                {
                    enviado = await _firebaseNotificationService.SendToTopicAsync(
                        topic,
                        notificacion.Titulo,
                        notificacion.Mensaje,
                        data);
                }
                catch (Exception ex)
                {
                    _logger.LogError(ex, "Error al enviar notificación push {NotificacionId} a Firebase.", notificacion.Id);
                    enviado = false;
                }

                if (enviado)
                {
                    try
                    {
                        var marcada = await client.MarcarEnviadaAsync(notificacion.Id, cancellationToken);
                        if (!marcada)
                        {
                            _logger.LogWarning("MarcarEnviadaAsync devolvió false para la notificación {NotificacionId}.", notificacion.Id);
                        }
                        enviadas++;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error al invocar MarcarEnviadaAsync para la notificación {NotificacionId}.", notificacion.Id);
                    }
                }
                else
                {
                    try
                    {
                        var liberada = await client.LiberarAsync(notificacion.Id, cancellationToken);
                        if (!liberada)
                        {
                            _logger.LogWarning("LiberarAsync devolvió false para la notificación {NotificacionId}.", notificacion.Id);
                        }
                        liberadas++;
                    }
                    catch (Exception ex)
                    {
                        _logger.LogError(ex, "Error al invocar LiberarAsync para la notificación {NotificacionId}.", notificacion.Id);
                    }
                }
            }
            catch (OperationCanceledException) when (cancellationToken.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Error inesperado al procesar la notificación {NotificacionId}.", notificacion.Id);
            }
        }

        if (notificaciones.Count > 0)
        {
            _logger.LogInformation(
                "Lote de push de reservas procesado: {Reclamadas} reclamadas, {Enviadas} enviadas, {Liberadas} liberadas.",
                notificaciones.Count,
                enviadas,
                liberadas);
        }
    }
}
