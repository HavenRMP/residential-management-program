using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HavenApi.Shared.Filters;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Roles;
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

    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [Authorize]
    [HttpPost("register-vigilante")]
    public async Task<IActionResult> RegisterVigilante([FromBody] RegisterRequestDto datos)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value ?? User.FindFirst("sub")?.Value;
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var adminId))
        {
            _logger.LogWarning("RegisterVigilante: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"].ToString().Replace("Bearer ", "");
        var adminUsuario = await _supabaseService.GetUsuarioByIdAsync(adminId, accessToken, adminId);

        if (adminUsuario == null)
        {
            _logger.LogWarning("RegisterVigilante: Requesting user {UserId} not found.", adminId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        if (!string.Equals(adminUsuario.EffectiveRol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("RegisterVigilante: Forbidden, user {UserId} is not an Admin.", adminId);
            return StatusCode(403, new { error = "Se requiere rol de administrador" });
        }

        if (adminUsuario.CondominioId == null)
        {
            _logger.LogWarning("RegisterVigilante: Admin {UserId} does not have a CondominioId.", adminId);
            return BadRequest(new { error = "El administrador no tiene un condominio asignado" });
        }

        var (usuario, error) = await _supabaseService.RegisterVigilanteAsync(datos, adminUsuario.CondominioId.Value, adminId);

        if (error != null)
        {
            if (error.Contains("ya esta registrado"))
            {
                _logger.LogWarning("RegisterVigilante: Conflict, {Error}", error);
                return Conflict(new { error });
            }

            _logger.LogWarning("RegisterVigilante: Bad request, {Error}", error);
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
            condominioId = usuario.CondominioId,
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
            creadoEn = usuario.CreadoEn,
            condominioId = usuario.CondominioId
        });
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [Authorize]
    [HttpGet("residentes")]
    public async Task<IActionResult> GetResidentes([FromQuery] PaginationParams paginacion, [FromQuery] bool sinVivienda = false)
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
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        List<UsuarioDto>? items;
        int? totalCount;

        if (sinVivienda)
        {
            (items, totalCount) = await _supabaseService.GetResidentesSinViviendaAsync(usuario.CondominioId.Value, paginacion);
        }
        else
        {
            (items, totalCount) = await _supabaseService.GetResidentesAsync(usuario.CondominioId.Value, paginacion);
        }

        var resultItems = (items ?? new List<UsuarioDto>()).Select(r => new
        {
            id = r.Id,
            nombre = r.Nombre,
            apellidos = r.Apellidos,
            telefono = r.Telefono,
            email = r.Email,
            creadoEn = r.CreadoEn
        }).Cast<object>().ToList();

        return Ok(PagedResult<object>.Create(resultItems, paginacion, totalCount));
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [Authorize]
    [HttpDelete("residentes/{id}")]
    public async Task<IActionResult> RetirarResidente(Guid id)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("RetirarResidente: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var adminUsuario = await _supabaseService.GetUsuarioByIdAsync(userId, accessToken, userId);

        if (adminUsuario == null)
        {
            _logger.LogWarning("RetirarResidente: Requesting user {UserId} not found.", userId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        if (!string.Equals(adminUsuario.EffectiveRol, "Administrador", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("RetirarResidente: Forbidden, user {UserId} is not an Admin.", userId);
            return StatusCode(403, new { error = "Se requiere rol de administrador" });
        }

        if (adminUsuario.CondominioId == null)
        {
            return BadRequest(new { error = "El administrador no tiene un condominio asignado" });
        }

        try
        {
            var result = await _supabaseService.RetirarResidenteCondominioAsync(id, adminUsuario.CondominioId.Value, userId);
            return Ok(new { message = "Residente retirado exitosamente." });
        }
        catch (HavenApi.Shared.Exceptions.SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
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