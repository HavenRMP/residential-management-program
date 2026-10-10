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
}
