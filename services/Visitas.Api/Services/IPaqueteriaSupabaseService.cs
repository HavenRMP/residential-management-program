using HavenApi.Shared.Pagination;
using Visitas.Api.DTOs;

namespace Visitas.Api.Services;

public interface IPaqueteriaSupabaseService
{
    Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken);
    Task<List<ServicioPaqueteriaDto>> GetServiciosPaqueteriaAsync(Guid? condominioId);
    Task<PaqueteDto> CreatePaqueteEsperadoAsync(CreatePaqueteEsperadoRequestDto dto, Guid actorId);
    Task<PaqueteDto> UpdatePaqueteEsperadoAsync(Guid id, Guid actorId, UpdatePaqueteEsperadoRequestDto dto);
    Task<bool> CancelPaqueteEsperadoAsync(Guid id, Guid actorId, string? motivo);
    Task<(List<PaqueteDto> Items, int? TotalCount)> GetMisPaquetesAsync(string accessToken, int? viviendaId, string? estado, PaginationParams paginacion);
}
