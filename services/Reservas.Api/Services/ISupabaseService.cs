using System.Threading.Tasks;
using Reservas.Api.DTOs;
using HavenApi.Shared.Pagination;
using System.Collections.Generic;

namespace Reservas.Api.Services;

public interface ISupabaseService
{
    Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken);

    Task<(List<AreaComunDto>? Items, int? TotalCount)> GetAreasAsync(Guid condominioId, bool soloActivas, PaginationParams paginacion);
    Task<AreaComunDto?> GetAreaByIdAsync(Guid id);
    Task<AreaComunDto?> CrearAreaAsync(Guid condominioId, CreateAreaComunRequestDto dto, Guid actorId);
    Task<AreaComunDto?> ActualizarAreaAsync(Guid id, UpdateAreaComunRequestDto dto, Guid actorId);
    Task<bool> BajaAreaAsync(Guid id, Guid actorId);
    Task<bool> ReactivarAreaAsync(Guid id, Guid actorId);

    Task<(List<CalendarioReservaDto>? Items, int? TotalCount)> GetCalendarioAsync(Guid condominioId, DateTimeOffset desde, DateTimeOffset hasta, Guid? areaId, bool limitado, PaginationParams paginacion);
    Task<(List<ReservaAdminDto>? Items, int? TotalCount)> GetCalendarioAdminAsync(Guid condominioId, DateTimeOffset desde, DateTimeOffset hasta, Guid? areaId, PaginationParams paginacion);
    Task<(List<ReservaUsuarioDto>? Items, int? TotalCount)> GetMisReservasAsync(Guid usuarioId, string? estado, PaginationParams paginacion);
    Task<(List<PendienteTitularDto>? Items, int? TotalCount)> GetPendientesTitularAsync(Guid titularId, PaginationParams paginacion);
    Task<(List<ReservaAdminDto>? Items, int? TotalCount)> GetReservasAdminAsync(Guid condominioId, string? estado, Guid? areaId, DateTimeOffset? desde, DateTimeOffset? hasta, PaginationParams paginacion);
    Task<(List<NoShowDto>? Items, int? TotalCount)> GetNoShowsAsync(Guid condominioId, Guid? titularId, PaginationParams paginacion);
}
