using Condominios.Api.DTOs;

namespace Condominios.Api.Services;

public interface ISupabaseService
{
    Task<List<CondominioDto>> GetCondominiosAsync(Guid condominioId);
    Task<CondominioDto?> GetCondominioByIdAsync(Guid id);
    Task<(CondominioDto? condominio, string? error)> CrearCondominioAsync(CreateCondominioRequestDto dto);
    Task<bool> DesactivarCondominioAsync(Guid id);
    Task<(CondominioDto? condominio, string? error)> ActualizarCondominioAsync(Guid id, UpdateCondominioRequestDto dto);
    Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken);
    Task<CodigoCondominioDto?> GenerarCodigoCondominioAsync(Guid condominioId, int? minutosVigencia, Guid actorId);
    Task<UsuarioResumenDto?> RedimirCodigoCondominioAsync(string codigo, Guid usuarioId, Guid actorId);
}
