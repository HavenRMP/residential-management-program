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
    
    Task<(IEnumerable<PaqueteCasetaDto> Items, int TotalCount)> GetPaquetesCasetaAsync(Guid condominioId, string estado, int? viviendaId, PaginationParams paginacion);
    Task<PaqueteCasetaDto> RecibirPaqueteAsync(RecibirPaqueteRequestDto dto, Guid actorId);
    Task<PaqueteCasetaDto> EntregarPaqueteAsync(Guid paqueteId, EntregarPaqueteRequestDto dto, Guid actorId);
    
    Task<(IEnumerable<PaqueteHistoricoDto> Items, int TotalCount)> GetPaquetesHistoricoAsync(
        Guid condominioId, DateTimeOffset? desde, DateTimeOffset? hasta, int? viviendaId, string? estado, PaginationParams paginacion);
        
    Task<ServicioPaqueteriaDto> CreateServicioPaqueteriaAsync(Guid condominioId, CreateServicioPaqueteriaRequestDto dto, Guid actorId);
    Task<bool> DeleteServicioPaqueteriaAsync(int servicioId, Guid actorId);
}
