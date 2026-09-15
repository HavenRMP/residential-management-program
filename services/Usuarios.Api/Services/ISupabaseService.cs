using Usuarios.Api.DTOs;

namespace Usuarios.Api.Services;

public interface ISupabaseService
{
    Task<UsuarioDto?> GetUsuarioByIdAsync(Guid userId, string accessToken, Guid actorId);
    Task<string?> GetDbVersionAsync();
    Task<(UsuarioDto? usuario, string? error)> RegisterAdminAsync(RegisterRequestDto datos, Guid? actorId = null);
    Task<(UsuarioDto? usuario, string? error)> CompletarPerfilAsync(Guid userId, CompletarPerfilRequestDto datos, string accessToken, Guid actorId);
    Task<List<UsuarioDto>> GetResidentesAsync(Guid condominioId);
    Task<(UsuarioDto? usuario, string? error)> AsignarCondominioAdminAsync(Guid adminId, Guid condominioId);
}