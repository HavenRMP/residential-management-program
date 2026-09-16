using Avisos.Api.DTOs;

namespace Avisos.Api.Services;

public interface ISupabaseService
{
    Task<(string? rol, Guid? condominioId)> GetUsuarioContextoAsync(Guid userId, string accessToken);
    Task<List<AvisoDto>> GetAvisosVigentesAsync(Guid condominioId);
    Task<List<AvisoDto>> GetAvisosHistoricoAsync(Guid condominioId);
    Task<(AvisoDto? aviso, string? error)> CreateAvisoAsync(Guid actorId, CreateAvisoRequestDto dto);
    Task<(AvisoDto? aviso, string? error)> UpdateAvisoAsync(Guid id, Guid actorId, UpdateAvisoRequestDto dto);
    Task<(bool ok, string? error)> DeleteAvisoAsync(Guid id, Guid actorId);
}
