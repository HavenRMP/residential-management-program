using HavenApi.Shared.Pagination;
using Avisos.Api.DTOs;

namespace Avisos.Api.Services;

public interface ISupabaseService
{
    Task<(string? rol, Guid? condominioId)> GetUsuarioContextoAsync(Guid userId, string accessToken);
    Task<(List<AvisoDto> Items, int? TotalCount)> GetAvisosVigentesAsync(Guid condominioId, PaginationParams paginacion);
    Task<(List<AvisoDto> Items, int? TotalCount)> GetAvisosHistoricoAsync(Guid condominioId, PaginationParams paginacion);
    Task<(AvisoDto? aviso, string? error)> CreateAvisoAsync(Guid actorId, CreateAvisoRequestDto dto);
    Task<(AvisoDto? aviso, string? error)> UpdateAvisoAsync(Guid id, Guid actorId, UpdateAvisoRequestDto dto);
    Task<(bool ok, string? error)> DeleteAvisoAsync(Guid id, Guid actorId);
    
    // Notificaciones y Lectura de Usuarios
    Task<List<Guid>> GetResidentesUsuarioIdsPorCondominioAsync(Guid condominioId);
    Task<bool> NotificarAvisoUrgenteAsync(Guid usuarioId, Guid avisoId, string tituloAviso);
}
