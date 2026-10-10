using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Roles;
using HavenApi.Shared.Rpc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Reservas.Api.DTOs;
using Reservas.Api.Services;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;

namespace Reservas.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AreasController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;

    public AreasController(ISupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetAreas([FromQuery] PaginationParams paginacion)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        var soloActivas = !rol.EsAdministrador();

        var (items, totalCount) = await _supabaseService.GetAreasAsync(condominioId.Value, soloActivas, paginacion);
        
        items ??= new List<AreaComunDto>();

        var result = items.Select(a => (object)new
        {
            id = a.Id,
            nombre = a.Nombre,
            descripcion = a.Descripcion,
            horaApertura = a.HoraApertura,
            horaCierre = a.HoraCierre,
            zonaHoraria = a.ZonaHoraria,
            activo = a.Activo
        }).ToList();

        return Ok(PagedResult<object>.Create(result, paginacion, totalCount ?? result.Count));
    }

    [HttpGet("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetArea(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        var area = await _supabaseService.GetAreaByIdAsync(id);

        if (area == null || area.CondominioId != condominioId.Value)
            return NotFound(new { error = "Área no encontrada" });

        if (!area.Activo && !rol.EsAdministrador())
            return NotFound(new { error = "Área no encontrada" });

        return Ok(new
        {
            id = area.Id,
            nombre = area.Nombre,
            descripcion = area.Descripcion,
            horaApertura = area.HoraApertura,
            horaCierre = area.HoraCierre,
            zonaHoraria = area.ZonaHoraria,
            activo = area.Activo
        });
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> CrearArea([FromBody] CreateAreaComunRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rol.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var area = await _supabaseService.CrearAreaAsync(condominioId.Value, dto, userId);
            return CreatedAtAction(nameof(GetArea), new { id = area!.Id }, new
            {
                id = area.Id,
                nombre = area.Nombre,
                descripcion = area.Descripcion,
                horaApertura = area.HoraApertura,
                horaCierre = area.HoraCierre,
                zonaHoraria = area.ZonaHoraria,
                activo = area.Activo
            });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPatch("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ActualizarArea(Guid id, [FromBody] UpdateAreaComunRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rol.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        var areaExistente = await _supabaseService.GetAreaByIdAsync(id);
        if (areaExistente == null || areaExistente.CondominioId != condominioId.Value)
            return NotFound(new { error = "Área no encontrada" });

        try
        {
            var area = await _supabaseService.ActualizarAreaAsync(id, dto, userId);
            return Ok(new
            {
                id = area!.Id,
                nombre = area.Nombre,
                descripcion = area.Descripcion,
                horaApertura = area.HoraApertura,
                horaCierre = area.HoraCierre,
                zonaHoraria = area.ZonaHoraria,
                activo = area.Activo
            });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/baja")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> BajaArea(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rol.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        var areaExistente = await _supabaseService.GetAreaByIdAsync(id);
        if (areaExistente == null || areaExistente.CondominioId != condominioId.Value)
            return NotFound(new { error = "Área no encontrada" });

        try
        {
            var result = await _supabaseService.BajaAreaAsync(id, userId);
            if (result)
                return NoContent();
            else
                return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/reactivar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ReactivarArea(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        var (rol, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);

        if (condominioId == null)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rol.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        var areaExistente = await _supabaseService.GetAreaByIdAsync(id);
        if (areaExistente == null || areaExistente.CondominioId != condominioId.Value)
            return NotFound(new { error = "Área no encontrada" });

        try
        {
            var result = await _supabaseService.ReactivarAreaAsync(id, userId);
            if (result)
                return NoContent();
            else
                return BadRequest(new { error = "No se pudo completar la operación" });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
