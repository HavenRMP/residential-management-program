using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;

namespace Usuarios.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class NotificacionesController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<NotificacionesController> _logger;

    public NotificacionesController(ISupabaseService supabaseService, ILogger<NotificacionesController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    private (Guid? UserId, string AccessToken) GetUserInfo()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        Guid? userId = userIdClaim != null && Guid.TryParse(userIdClaim, out var parsedId) ? parsedId : null;
        
        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        return (userId, accessToken);
    }

    [HttpGet]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetNotificaciones()
    {
        var (userId, accessToken) = GetUserInfo();
        if (userId == null)
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var (notificaciones, error) = await _supabaseService.GetNotificacionesAsync(userId.Value, accessToken);
        if (error != null)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { error });
        }
        if (notificaciones == null)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { error = "Error al obtener notificaciones" });
        }

        return Ok(notificaciones);
    }

    [HttpGet("contador-no-leidas")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetContadorNoLeidas()
    {
        var (userId, accessToken) = GetUserInfo();
        if (userId == null)
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var (count, error) = await _supabaseService.GetContadorNoLeidasAsync(userId.Value, accessToken);
        if (error != null)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { error });
        }
        return Ok(new { count = count ?? 0 });
    }

    [HttpPatch("{id:guid}/leer")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> MarcarComoLeida(Guid id)
    {
        var (userId, accessToken) = GetUserInfo();
        if (userId == null)
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var (success, error) = await _supabaseService.MarcarNotificacionComoLeidaAsync(id, userId.Value, accessToken);
        if (error != null)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { error });
        }
        if (!success)
        {
            return BadRequest(new { error = "No se pudo marcar la notificación como leída" });
        }

        return NoContent();
    }

    [HttpPost("marcar-todas")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<IActionResult> MarcarTodasComoLeidas()
    {
        var (userId, accessToken) = GetUserInfo();
        if (userId == null)
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var (success, error) = await _supabaseService.MarcarTodasComoLeidasAsync(userId.Value, accessToken);
        if (error != null)
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { error });
        }
        if (!success)
        {
            return BadRequest(new { error = "No se pudieron marcar las notificaciones como leídas" });
        }

        return NoContent();
    }
}
