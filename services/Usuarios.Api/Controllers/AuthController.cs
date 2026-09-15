using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HavenApi.Shared.Filters;
namespace Usuarios.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase

{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(ISupabaseService supabaseService, ILogger<AuthController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [HttpGet("ping")]
    public async Task<IActionResult> Ping()
    {
        var dbVersion = await _supabaseService.GetDbVersionAsync();

        return Ok(new
        {
            message = "Haven API is running",
            timestamp = DateTime.UtcNow,
            dbVersion
        });
    }

    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [Authorize] // Protected for admins
    [HttpPost("register-admin")]
    public async Task<IActionResult> RegisterAdmin([FromBody] RegisterRequestDto datos)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        Guid? actorId = userIdClaim != null && Guid.TryParse(userIdClaim, out var parsedId) ? parsedId : null;

        var (usuario, error) = await _supabaseService.RegisterAdminAsync(datos, actorId);

        if (error != null)
        {
            if (error.Contains("ya esta registrado"))
            {
                _logger.LogWarning("RegisterAdmin: Conflict, {Error}", error);
                return Conflict(new { error });
            }

            _logger.LogWarning("RegisterAdmin: Bad request, {Error}", error);
            return BadRequest(new { error });
        }

        return Created("/api/auth/me", new
        {
            id = usuario!.Id,
            rolId = usuario.RolId,
            email = usuario.Email,
            nombre = usuario.Nombre,
            apellidos = usuario.Apellidos,
            telefono = usuario.Telefono,
            creadoEn = usuario.CreadoEn
        });
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [Authorize]
    [HttpGet("me")]
    public async Task<IActionResult> Me()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("Me: Unauthorized, missing or invalid user ID in token.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var usuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (usuario == null)
        {
            _logger.LogWarning("Me: User {UserId} not found in 'usuarios' table.", userId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        return Ok(new
        {
            id = usuario.Id,
            rolId = usuario.RolId,
            nombre = usuario.Nombre,
            apellidos = usuario.Apellidos,
            telefono = usuario.Telefono,
            rol = usuario.EffectiveRol,
            email = User.FindFirst(ClaimTypes.Email)?.Value
                    ?? User.FindFirst("email")?.Value,
            creadoEn = usuario.CreadoEn
        });
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [Authorize]
    [HttpGet("residentes")]
    public async Task<IActionResult> GetResidentes()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("GetResidentes: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var usuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (usuario == null)
        {
            _logger.LogWarning("GetResidentes: Requesting user {UserId} not found.", userId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        if (!string.Equals(usuario.EffectiveRol, "Administrador", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("GetResidentes: Forbidden, user {UserId} is not an Admin.", userId);
            return StatusCode(403, new { error = "Se requiere rol de administrador" });
        }

        if (usuario.CondominioId == null)
        {
            return Ok(new List<object>());
        }

        var residentes = await _supabaseService.GetResidentesAsync(usuario.CondominioId.Value);

        var result = residentes.Select(r => new
        {
            id = r.Id,
            nombre = r.Nombre,
            apellidos = r.Apellidos,
            telefono = r.Telefono,
            email = r.Email,
            creadoEn = r.CreadoEn
        });

        return Ok(result);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [Authorize]
    [HttpPatch("completar-perfil")]
    public async Task<IActionResult> CompletarPerfil([FromBody] CompletarPerfilRequestDto datos)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("CompletarPerfil: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (usuario, error) = await _supabaseService.CompletarPerfilAsync(userId, datos, accessToken, userId);

        if (error != null)
        {
            _logger.LogWarning("CompletarPerfil: Bad request for user {UserId}. Error: {Error}", userId, error);
            return BadRequest(new { error });
        }

        if (usuario == null)
        {
            _logger.LogWarning("CompletarPerfil: User {UserId} not found.", userId);
            return NotFound(new { error = "Usuario no encontrado" });
        }

        return Ok(new
        {
            id = usuario.Id,
            nombre = usuario.Nombre,
            apellidos = usuario.Apellidos,
            telefono = usuario.Telefono
        });
    }

    [RequireDevKey]
    [HttpPost("~/api/usuarios/{id}/condominio")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> AsignarCondominioAdmin(Guid id, [FromBody] AsignarCondominioAdminRequestDto dto)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        var (usuario, error) = await _supabaseService.AsignarCondominioAdminAsync(id, dto.CondominioId);

        if (error != null)
        {
            if (error == "Usuario no encontrado")
            {
                return NotFound(new { error });
            }
            if (error.Contains("Ya existe un administrador"))
            {
                return Conflict(new { error });
            }

            return BadRequest(new { error });
        }

        return Ok(new
        {
            id = usuario!.Id,
            nombre = usuario.Nombre,
            apellidos = usuario.Apellidos,
            email = usuario.Email,
            rolId = usuario.RolId,
            condominioId = usuario.CondominioId
        });
    }
}