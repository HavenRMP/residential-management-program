using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;

namespace Usuarios.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class SubusuariosController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<SubusuariosController> _logger;

    public SubusuariosController(ISupabaseService supabaseService, ILogger<SubusuariosController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    // Usado por el titular para ver quién está en su vivienda o a quién invitó
    [HttpGet("mis-subusuarios")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMisSubusuarios([FromQuery] int viviendaId)
    {
        if (viviendaId <= 0)
        {
            return BadRequest(new { error = "Se requiere viviendaId válido" });
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");

        var activos = await _supabaseService.GetSubusuariosActivosAsync(viviendaId, accessToken);
        var invitaciones = await _supabaseService.GetInvitacionesViviendaAsync(viviendaId, accessToken);

        var result = new List<SubusuarioItemDto>();

        if (activos != null)
        {
            result.AddRange(activos.Select(a => new SubusuarioItemDto
            {
                Id = a.UsuarioId,
                Nombre = a.UsuarioNombre,
                Email = a.UsuarioEmail,
                Telefono = a.UsuarioTelefono,
                Parentesco = a.Parentesco,
                Estado = "Activo"
            }));
        }

        if (invitaciones != null)
        {
            result.AddRange(invitaciones.Select(i => new SubusuarioItemDto
            {
                Id = i.Id,
                Nombre = "Pendiente",
                Email = i.InvitadoEmail ?? "Desconocido",
                Telefono = "Pendiente",
                Parentesco = i.Parentesco,
                Estado = "Pendiente",
                CreadoEn = i.CreadoEn
            }));
        }

        return Ok(result);
    }

    // Usado por el titular para invitar a alguien vía email
    [HttpPost("invitar")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> InvitarSubusuario([FromBody] InvitarSubusuarioRequestDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");

        var (invitacion, error) = await _supabaseService.InvitarSubusuarioAsync(dto.ViviendaId, dto.Email, dto.Parentesco, userId, accessToken);

        if (error != null)
        {
            if (error.Contains("Límite máximo") || error.Contains("ya está invitado"))
            {
                return Conflict(new { error });
            }
            if (error.Contains("No se encontró"))
            {
                return NotFound(new { error });
            }
            return BadRequest(new { error });
        }

        if (invitacion == null)
        {
            return BadRequest(new { error = "Error desconocido al generar invitación" });
        }

        var result = new SubusuarioItemDto
        {
            Id = invitacion.Id,
            Nombre = "Pendiente",
            Email = dto.Email,
            Telefono = "Pendiente",
            Parentesco = invitacion.Parentesco,
            Estado = "Pendiente",
            CreadoEn = invitacion.CreadoEn
        };

        return Created($"/api/subusuarios/mis-subusuarios?viviendaId={dto.ViviendaId}", result);
    }

    // Usado por el invitado para ver qué invitaciones tiene pendientes
    [HttpGet("mis-invitaciones")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMisInvitaciones()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        var invitaciones = await _supabaseService.GetMisInvitacionesPendientesAsync(userId, accessToken);

        return Ok(invitaciones ?? new List<VwInvitacionSubusuarioDto>());
    }

    // Usado por el invitado para aceptar o rechazar la invitación
    [HttpPost("invitaciones/{id}/responder")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> ResponderInvitacion(Guid id, [FromBody] ResponderInvitacionDto dto)
    {
        if (dto.Respuesta != "ACEPTADA" && dto.Respuesta != "RECHAZADA")
        {
            return BadRequest(new { error = "La respuesta debe ser ACEPTADA o RECHAZADA" });
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        var result = await _supabaseService.ResponderInvitacionAsync(id, userId, dto.Respuesta, accessToken);

        if (!result.Success)
        {
            return BadRequest(new { error = result.Error ?? "No se pudo procesar la respuesta a la invitación. Puede que ya haya sido procesada o cancelada." });
        }

        return Ok(new { message = $"Invitación {dto.Respuesta.ToLower()} exitosamente." });
    }

    // Usado por el titular para revocar el acceso
    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> RevocarSubusuario(Guid id, [FromQuery] int viviendaId, [FromQuery] bool isInvitacion = false)
    {
        if (viviendaId <= 0)
        {
            return BadRequest(new { error = "Se requiere viviendaId válido" });
        }

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");

        bool success = false;
        string? error = null;
        
        if (isInvitacion)
        {
            // Este camino valida titularidad utilizando el token del usuario.
            try
            {
                var result = await _supabaseService.CancelarInvitacionSubusuarioAsync(id, userId, accessToken);
                if (result)
                {
                    return NoContent();
                }
                return NotFound(new { error = "Invitación no encontrada" });
            }
            catch (SupabaseRpcException ex)
            {
                var (status, mensaje) = RpcErrorMapper.Map(ex);
                return StatusCode(status, new { error = mensaje });
            }
        }
        else
        {
            // Intentamos revocar usuario activo
            var res = await _supabaseService.RevocarSubusuarioAsync(viviendaId, id, accessToken);
            success = res.Success;
            error = res.Error;
            
            // Si falló, tal vez era una invitación pendiente y mandaron isInvitacion=false por error
            if (!success)
            {
                var resInvitacion = await _supabaseService.CancelarInvitacionAsync(id, accessToken);
                success = resInvitacion.Success;
                if (!success) error = resInvitacion.Error ?? error;
            }
        }

        if (!success)
        {
            return BadRequest(new { error = error ?? "No se pudo revocar el sub-usuario o invitación." });
        }

        return NoContent();
    }
}
