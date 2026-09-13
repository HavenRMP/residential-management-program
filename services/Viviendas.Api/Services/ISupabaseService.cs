using System.Text.Json;
using Viviendas.Api.DTOs;

namespace Viviendas.Api.Services;

public interface ISupabaseService
{
    Task<string?> GetUsuarioRolAsync(Guid userId, string accessToken);
    Task<(string? rolNombre, Guid? condominioId)> GetContextoAdminAsync(Guid userId, string accessToken);
    Task<List<ViviendaDto>> GetViviendasAsync(Guid condominioId);
    Task<ViviendaDto?> GetViviendaByIdAsync(int id);
    Task<(ViviendaDto? vivienda, string? error)> CreateViviendaAsync(CreateViviendaRequestDto dto, Guid condominioId);
    Task<(ViviendaDto? vivienda, string? error)> UpdateViviendaAsync(int id, UpdateViviendaRequestDto dto);
    Task<bool> DeleteViviendaAsync(int id);
    Task<(JsonElement? data, string? error)> AssignResidenteAsync(int viviendaId, AsignarResidenteRequestDto dto);
    Task<bool> RemoveResidenteAsync(int viviendaId, Guid usuarioId);
    Task<List<MiViviendaDto>> GetMisViviendasAsync(string accessToken);
    Task<JsonElement> GetResidentesByViviendaIdAsync(int viviendaId);
}
