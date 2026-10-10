using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Reservas.Api.DTOs;
using Reservas.Api.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Reservas.Api.Controllers;

[ApiController]
[Route("api/admin/reservas")]
[Authorize]
public class AdminReservasController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;

    public AdminReservasController(ISupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetReservas(
        [FromQuery] string? estado,
        [FromQuery] Guid? areaId,
        [FromQuery] DateTimeOffset? from,
        [FromQuery] DateTimeOffset? to,
        [FromQuery] PaginationParams paginationParams)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.GetReservasAdminAsync(condominioId.Value, estado, areaId, from, to, paginationParams);
            var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
            return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("no-shows")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetNoShows(
        [FromQuery] Guid? titularId,
        [FromQuery] PaginationParams paginationParams)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.GetNoShowsAsync(condominioId.Value, titularId, paginationParams);
            var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
            return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/aprobar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> AprobarReserva(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.AprobarReservaAdminAsync(userId, id);
            if (result) return NoContent();
            return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/rechazar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RechazarReserva(Guid id, [FromBody] MotivoObligatorioRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.RechazarReservaAdminAsync(userId, id, dto.Motivo);
            if (result) return NoContent();
            return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/cancelar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CancelarReserva(Guid id, [FromBody] MotivoObligatorioRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.CancelarReservaAdminAsync(userId, id, dto.Motivo);
            if (result) return NoContent();
            return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/no-utilizada")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> MarcarNoUtilizada(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.MarcarNoUtilizadaAsync(userId, id);
            if (result) return NoContent();
            return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    private static object MapToCamelCase(ReservaAdminDto dto) => new
    {
        id = dto.Id,
        areaId = dto.AreaId,
        areaNombre = dto.AreaNombre,
        condominioId = dto.CondominioId,
        tipo = dto.Tipo,
        estado = dto.Estado,
        inicio = dto.Inicio,
        fin = dto.Fin,
        titularId = dto.TitularId,
        titularNombre = dto.TitularNombre,
        titularApellidos = dto.TitularApellidos,
        viviendaId = dto.ViviendaId,
        numeroCasa = dto.NumeroCasa,
        solicitanteId = dto.SolicitanteId,
        solicitanteNombre = dto.SolicitanteNombre,
        solicitanteApellidos = dto.SolicitanteApellidos,
        aprobadorId = dto.AprobadorId,
        aprobadorNombre = dto.AprobadorNombre,
        aprobadorApellidos = dto.AprobadorApellidos,
        motivo = dto.Motivo,
        confirmadaEn = dto.ConfirmadaEn,
        creadoEn = dto.CreadoEn,
        actualizadoEn = dto.ActualizadoEn,
        noShowsTitular = dto.NoShowsTitular,
        noShowsSolicitante = dto.NoShowsSolicitante
    };

    private static object MapToCamelCase(NoShowDto dto) => new
    {
        id = dto.Id,
        areaId = dto.AreaId,
        areaNombre = dto.AreaNombre,
        condominioId = dto.CondominioId,
        inicio = dto.Inicio,
        fin = dto.Fin,
        titularId = dto.TitularId,
        titularNombre = dto.TitularNombre,
        titularApellidos = dto.TitularApellidos,
        viviendaId = dto.ViviendaId,
        numeroCasa = dto.NumeroCasa,
        solicitanteId = dto.SolicitanteId,
        solicitanteNombre = dto.SolicitanteNombre,
        solicitanteApellidos = dto.SolicitanteApellidos,
        creadoEn = dto.CreadoEn
    };
}
