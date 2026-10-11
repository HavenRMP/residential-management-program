using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Tasks;
using Reservas.Api.DTOs;

namespace Reservas.Api.Services;

public interface INotificacionesPushClient
{
    Task<List<NotificacionPushPendienteDto>> ReclamarPendientesAsync(int limite, CancellationToken cancellationToken = default);
    Task<bool> MarcarEnviadaAsync(Guid notificacionId, CancellationToken cancellationToken = default);
    Task<bool> LiberarAsync(Guid notificacionId, CancellationToken cancellationToken = default);
}
