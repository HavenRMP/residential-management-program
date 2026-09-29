using HavenApi.Shared.Pagination;
using Visitas.Api.DTOs;

namespace Visitas.Api.Services;

public interface ISupabaseService
{
    Task<(string? rolNombre, Guid? condominioId)> GetContextoUsuarioAsync(Guid userId, string accessToken);
    Task<VisitaDto> CreateVisitaAsync(CreateVisitaRequestDto dto, Guid actorId);
    Task<VisitaDto> UpdateVisitaAsync(Guid id, Guid actorId, UpdateVisitaRequestDto dto);
    Task<bool> CancelVisitaAsync(Guid id, Guid actorId);
    Task<(List<VisitaDto> Items, int? TotalCount)> GetMisVisitasAsync(string accessToken, string? estado, PaginationParams paginacion);
    Task<(List<VisitaDto> Items, int? TotalCount)> GetVisitasHoyAsync(Guid condominioId, PaginationParams paginacion);
    Task<(List<VisitaDto> Items, int? TotalCount)> GetVisitasHistoricoAsync(Guid condominioId, DateTimeOffset? desde, DateTimeOffset? hasta, int? viviendaId, string? estado, PaginationParams paginacion);
    Task<VisitaDto> ValidarCodigoAsync(string codigo, Guid actorId);
    Task<VisitaDto> RegistrarEntradaAsync(Guid visitaId, Guid actorId);
    Task<VisitaDto> RegistrarSalidaAsync(Guid visitaId, Guid actorId);
}
