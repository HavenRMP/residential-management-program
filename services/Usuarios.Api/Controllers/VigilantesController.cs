using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HavenApi.Shared.Pagination;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using HavenApi.Shared.Roles;
using HavenApi.Shared.Extensions;

namespace Usuarios.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class VigilantesController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<VigilantesController> _logger;

    public VigilantesController(ISupabaseService supabaseService, ILogger<VigilantesController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetVigilantes([FromQuery] PaginationParams paginacion)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var accessToken = HttpContext.Request.GetBearerToken();
        var usuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (usuario == null)
            return NotFound(new { error = "Usuario no encontrado" });

        if (!string.Equals(usuario.EffectiveRol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase))
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        if (usuario.CondominioId == null)
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));

        var (items, totalCount) = await _supabaseService.GetVigilantesAsync(usuario.CondominioId.Value, paginacion);

        var resultItems = (items ?? new List<VigilanteDto>()).Select(r => new
        {
            id = r.Id,
            nombre = r.Nombre,
            apellidos = r.Apellidos,
            telefono = r.Telefono,
            email = r.Email,
            activo = r.Activo,
            creadoEn = r.CreadoEn
        }).Cast<object>().ToList();

        return Ok(PagedResult<object>.Create(resultItems, paginacion, totalCount));
    }

    [HttpPatch("{id}/baja")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> BajaVigilante(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var accessToken = HttpContext.Request.GetBearerToken();
        var usuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (usuario == null)
            return NotFound(new { error = "Usuario no encontrado" });

        if (!string.Equals(usuario.EffectiveRol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase))
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        var (success, error) = await _supabaseService.BajaVigilanteAsync(id, accessToken);
        if (!success)
        {
            return BadRequest(new { error = error ?? "Error al dar de baja al vigilante" });
        }

        return NoContent();
    }

    [HttpPatch("{id}/reactivar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ReactivarVigilante(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var accessToken = HttpContext.Request.GetBearerToken();
        var usuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (usuario == null)
            return NotFound(new { error = "Usuario no encontrado" });

        if (!string.Equals(usuario.EffectiveRol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase))
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        var (success, error) = await _supabaseService.ReactivarVigilanteAsync(id, accessToken);
        if (!success)
        {
            return BadRequest(new { error = error ?? "Error al reactivar al vigilante" });
        }

        return NoContent();
    }
}
