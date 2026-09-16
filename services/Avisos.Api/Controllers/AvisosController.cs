using Avisos.Api.DTOs;
using Avisos.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Avisos.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class AvisosController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<AvisosController> _logger;

    public AvisosController(ISupabaseService supabaseService, ILogger<AvisosController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    private async Task<(IActionResult? Error, Guid? CondominioId, Guid UserId)> ValidateAdminAsync()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("ValidateAdmin: Unauthorized, missing or invalid user ID.");
            return (Unauthorized(new { error = "Token invalido: no contiene ID de usuario" }), null, Guid.Empty);
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (rolNombre, condominioId) = await _supabaseService.GetUsuarioContextoAsync(userId, accessToken);

        if (rolNombre == null)
        {
            _logger.LogWarning("ValidateAdmin: User {UserId} not found.", userId);
            return (NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" }), null, userId);
        }

        if (!string.Equals(rolNombre, "Administrador", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("ValidateAdmin: Forbidden, user {UserId} is not an Admin.", userId);
            return (StatusCode(403, new { error = "Se requiere rol de administrador" }), null, userId);
        }

        return (null, condominioId, userId);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [HttpGet]
    public async Task<IActionResult> GetAvisos()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("GetAvisos: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (rolNombre, condominioId) = await _supabaseService.GetUsuarioContextoAsync(userId, accessToken);

        if (condominioId == null)
        {
            return Ok(new List<AvisoDto>());
        }

        var avisos = await _supabaseService.GetAvisosVigentesAsync(condominioId.Value);
        return Ok(avisos);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [HttpGet("historico")]
    public async Task<IActionResult> GetAvisosHistorico()
    {
        var (adminError, condominioId, _) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        if (condominioId == null)
        {
            return Ok(new List<AvisoDto>());
        }

        var avisos = await _supabaseService.GetAvisosHistoricoAsync(condominioId.Value);
        return Ok(avisos);
    }

    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [HttpPost]
    public async Task<IActionResult> CreateAviso([FromBody] CreateAvisoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (adminError, condominioId, actorId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        if (condominioId == null)
        {
            _logger.LogWarning("CreateAviso: El administrador no tiene un condominio asignado.");
            return BadRequest(new { error = "El administrador no tiene un condominio asignado" });
        }

        var (aviso, error) = await _supabaseService.CreateAvisoAsync(actorId, dto);
        if (error != null)
        {
            _logger.LogWarning("CreateAviso: Error {Error}", error);
            return BadRequest(new { error });
        }

        return StatusCode(201, aviso);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateAviso(Guid id, [FromBody] UpdateAvisoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (adminError, condominioId, actorId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var (aviso, error) = await _supabaseService.UpdateAvisoAsync(id, actorId, dto);
        if (error != null)
        {
            _logger.LogWarning("UpdateAviso: Error {Error}", error);

            if (error.Contains("no encontrado", StringComparison.OrdinalIgnoreCase))
            {
                return NotFound(new { error });
            }
            if (error.Contains("condominio", StringComparison.OrdinalIgnoreCase))
            {
                return StatusCode(403, new { error });
            }

            return BadRequest(new { error });
        }

        return Ok(aviso);
    }

    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteAviso(Guid id)
    {
        var (adminError, condominioId, actorId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var (ok, error) = await _supabaseService.DeleteAvisoAsync(id, actorId);
        if (!ok)
        {
            _logger.LogWarning("DeleteAviso: Error {Error}", error);

            if (error != null && error.Contains("no encontrado", StringComparison.OrdinalIgnoreCase))
            {
                return NotFound(new { error });
            }
            if (error != null && error.Contains("condominio", StringComparison.OrdinalIgnoreCase))
            {
                return StatusCode(403, new { error });
            }

            return BadRequest(new { error = error ?? "Error al eliminar el aviso" });
        }

        return NoContent();
    }
}
