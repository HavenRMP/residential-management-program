using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Reservas.Api.DTOs;
using Reservas.Api.Services;
using System;
using System.Linq;
using System.Threading.Tasks;

namespace Reservas.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ReservasController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;

    public ReservasController(ISupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    [HttpGet("calendario")]
    public async Task<IActionResult> GetCalendario(
        [FromQuery] DateTimeOffset from, 
        [FromQuery] DateTimeOffset to, 
        [FromQuery] Guid? areaId, 
        [FromQuery] PaginationParams paginationParams)
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        if (to <= from)
        {
            return BadRequest(new { error = "La fecha de fin 'to' debe ser posterior a la fecha de inicio 'from'." });
        }

        if ((to - from).TotalDays > 62)
        {
            return BadRequest(new { error = "El rango de fechas no puede exceder los 62 días." });
        }

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        if (!condominioId.HasValue)
        {
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });
        }

        try
        {
            if (rolNombre.EsAdministrador())
            {
                var result = await _supabaseService.GetCalendarioAdminAsync(condominioId.Value, from, to, areaId, paginationParams);
                var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
                return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
            }
            else if (rolNombre.EsResidente())
            {
                var result = await _supabaseService.GetCalendarioAsync(condominioId.Value, from, to, areaId, false, paginationParams);
                var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
                return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
            }
            else if (rolNombre.EsRolDeSoloLectura())
            {
                var result = await _supabaseService.GetCalendarioAsync(condominioId.Value, from, to, areaId, true, paginationParams);
                var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
                return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
            }
            else
            {
                return StatusCode(403, new { error = "No tienes permiso para ver el calendario de reservas" });
            }
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("mias")]
    public async Task<IActionResult> GetMisReservas(
        [FromQuery] string? estado, 
        [FromQuery] PaginationParams paginationParams)
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        if (!condominioId.HasValue)
        {
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });
        }

        if (!rolNombre.EsResidente())
        {
            return StatusCode(403, new { error = "Solo los residentes pueden consultar sus reservas" });
        }

        try
        {
            var result = await _supabaseService.GetMisReservasAsync(userId, estado, paginationParams);
            var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
            return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("por-aprobar-titular")]
    public async Task<IActionResult> GetPendientesTitular([FromQuery] PaginationParams paginationParams)
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        if (!condominioId.HasValue)
        {
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });
        }

        if (!rolNombre.EsResidente())
        {
            return StatusCode(403, new { error = "Solo los residentes pueden consultar las reservas pendientes por aprobar" });
        }

        try
        {
            var result = await _supabaseService.GetPendientesTitularAsync(userId, paginationParams);
            var items = result.Items?.Select(MapToCamelCase).ToList() ?? new System.Collections.Generic.List<object>();
            return Ok(PagedResult<object>.Create(items, paginationParams, result.TotalCount ?? 0));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    private static object MapToCamelCase(CalendarioReservaDto dto) => new
    {
        id = dto.Id,
        areaId = dto.AreaId,
        areaNombre = dto.AreaNombre,
        tipo = dto.Tipo,
        estado = dto.Estado,
        inicio = dto.Inicio,
        fin = dto.Fin,
        titularNombre = dto.TitularNombre,
        titularApellidos = dto.TitularApellidos,
        numeroCasa = dto.NumeroCasa,
        motivo = dto.Motivo
    };

    private static object MapToCamelCase(ReservaUsuarioDto dto) => new
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
        actualizadoEn = dto.ActualizadoEn
    };

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

    private static object MapToCamelCase(PendienteTitularDto dto) => new
    {
        id = dto.Id,
        areaId = dto.AreaId,
        areaNombre = dto.AreaNombre,
        condominioId = dto.CondominioId,
        inicio = dto.Inicio,
        fin = dto.Fin,
        titularId = dto.TitularId,
        viviendaId = dto.ViviendaId,
        numeroCasa = dto.NumeroCasa,
        solicitanteId = dto.SolicitanteId,
        solicitanteNombre = dto.SolicitanteNombre,
        solicitanteApellidos = dto.SolicitanteApellidos,
        solicitanteEmail = dto.SolicitanteEmail,
        parentesco = dto.Parentesco,
        creadoEn = dto.CreadoEn
    };
}
