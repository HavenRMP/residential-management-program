using Usuarios.Api.DTOs;

using HavenApi.Shared.Pagination;

namespace Usuarios.Api.Services;

public interface ISupabaseService
{
    Task<UsuarioDto?> GetUsuarioByIdAsync(Guid userId, string accessToken, Guid actorId);
    Task<string?> GetDbVersionAsync();
    Task<(UsuarioDto? usuario, string? error)> RegisterAdminAsync(RegisterRequestDto datos, Guid? actorId = null);
    Task<(UsuarioDto? usuario, string? error)> RegisterVigilanteAsync(RegisterRequestDto datos, Guid condominioId, Guid? actorId = null);
    Task<(UsuarioDto? usuario, string? error)> CompletarPerfilAsync(Guid userId, CompletarPerfilRequestDto datos, string accessToken, Guid actorId);
    Task<(List<UsuarioDto>? Items, int? TotalCount)> GetResidentesAsync(Guid condominioId, PaginationParams paginacion);
    Task<(List<UsuarioDto>? Items, int? TotalCount)> GetResidentesSinViviendaAsync(Guid condominioId, PaginationParams paginacion);
    Task<(UsuarioDto? usuario, string? error)> AsignarCondominioAdminAsync(Guid adminId, Guid condominioId);
    
    // Notificaciones
    Task<(List<NotificacionDto>? Notificaciones, string? Error)> GetNotificacionesAsync(Guid userId, string accessToken);
    Task<(int? Count, string? Error)> GetContadorNoLeidasAsync(Guid userId, string accessToken);
    Task<(bool Success, string? Error)> MarcarNotificacionComoLeidaAsync(Guid id, Guid userId, string accessToken);
    Task<(bool Success, string? Error)> MarcarTodasComoLeidasAsync(Guid userId, string accessToken);

    // Sub-usuarios
    Task<List<VwViviendaSubusuarioDto>?> GetSubusuariosActivosAsync(int viviendaId, string accessToken);
    Task<List<VwInvitacionSubusuarioDto>?> GetInvitacionesViviendaAsync(int viviendaId, string accessToken);
    Task<List<VwInvitacionSubusuarioDto>?> GetMisInvitacionesPendientesAsync(Guid invitadoId, string accessToken);
    Task<(VwInvitacionSubusuarioDto? invitacion, string? error)> InvitarSubusuarioAsync(int viviendaId, string email, string parentesco, Guid creadoPor, string accessToken);
    Task<bool> ResponderInvitacionAsync(Guid invitacionId, Guid usuarioId, string respuesta, string accessToken);
    Task<bool> CancelarInvitacionAsync(Guid invitacionId, string accessToken);
    Task<bool> RevocarSubusuarioAsync(int viviendaId, Guid usuarioId, string accessToken);
}