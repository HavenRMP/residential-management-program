using Visitas.Api.DTOs;

namespace Visitas.Api.Services;

public interface ISupabaseService
{
    Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken);
    Task<VisitaDto> CreateVisitaAsync(CreateVisitaRequestDto dto, Guid actorId);
}
