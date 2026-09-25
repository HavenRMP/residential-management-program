using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;

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
        var invitaciones = await _supabaseService.GetInvitacionesSubusuarioAsync(viviendaId, accessToken);

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
                Email = "Pendiente",
                Telefono = "Pendiente",
                Parentesco = i.Parentesco,
                Estado = "Pendiente",
                Codigo = i.Codigo,
                ExpiraEn = i.ExpiraEn
            }));
        }

        return Ok(result);
    }

    [HttpPost("invitar")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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

        var (invitacion, error) = await _supabaseService.InvitarSubusuarioAsync(dto.ViviendaId, dto.Parentesco, userId, accessToken);

        if (error != null)
        {
            if (error.Contains("Límite máximo"))
            {
                return Conflict(new { error });
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
            Nombre = dto.Nombre,
            Email = dto.Email,
            Telefono = dto.Telefono,
            Parentesco = invitacion.Parentesco,
            Estado = "Pendiente",
            Codigo = invitacion.Codigo,
            ExpiraEn = invitacion.ExpiraEn
        };

        return Created($"/api/subusuarios/mis-subusuarios?viviendaId={dto.ViviendaId}", result);
    }

    [HttpDelete("{id}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
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
        
        // El id puede ser el ID del código de invitación o el ID del usuario
        if (isInvitacion)
        {
            success = await _supabaseService.CancelarInvitacionAsync(id, accessToken);
        }
        else
        {
            // Intentamos revocar usuario activo
            success = await _supabaseService.RevocarSubusuarioAsync(viviendaId, id, accessToken);
            
            // Si falló y no estábamos seguros, tal vez era una invitación
            if (!success)
            {
                success = await _supabaseService.CancelarInvitacionAsync(id, accessToken);
            }
        }

        if (!success)
        {
            return BadRequest(new { error = "No se pudo revocar el sub-usuario o invitación." });
        }

        return NoContent();
    }
}
