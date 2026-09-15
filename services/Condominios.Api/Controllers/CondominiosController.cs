using Condominios.Api.DTOs;
using Condominios.Api.Services;
using HavenApi.Shared.Filters;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;

namespace Condominios.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class CondominiosController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<CondominiosController> _logger;

    public CondominiosController(ISupabaseService supabaseService, ILogger<CondominiosController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [HttpGet]
    public async Task<IActionResult> GetCondominios()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;
                          
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (_, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, accessToken);

        if (condominioId == null)
        {
            return Ok(new List<object>());
        }

        var condominios = await _supabaseService.GetCondominiosAsync(condominioId.Value);
        var result = condominios.Select(c => new
        {
            id = c.Id,
            nombre = c.Nombre,
            activo = c.Activo,
            creadoEn = c.CreadoEn
        });

        return Ok(result);
    }

    [Authorize]
    [HttpGet("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetCondominio(Guid id)
    {
        var condominio = await _supabaseService.GetCondominioByIdAsync(id);
        if (condominio == null)
        {
            _logger.LogWarning("GetCondominio: Condominio {Id} not found.", id);
            return NotFound(new { error = "Condominio no encontrado" });
        }

        return Ok(new
        {
            id = condominio.Id,
            nombre = condominio.Nombre,
            activo = condominio.Activo,
            creadoEn = condominio.CreadoEn
        });
    }

    [AllowAnonymous]
    [RequireDevKey]
    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> CreateCondominio([FromBody] CreateCondominioRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (condominio, error) = await _supabaseService.CrearCondominioAsync(dto);
        if (error != null)
        {
            return BadRequest(new { error });
        }

        return CreatedAtAction(nameof(GetCondominio), new { id = condominio!.Id }, new
        {
            id = condominio.Id,
            nombre = condominio.Nombre,
            activo = condominio.Activo,
            creadoEn = condominio.CreadoEn
        });
    }

    [AllowAnonymous]
    [RequireDevKey]
    [HttpPost("{id}/baja")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> BajaCondominio(Guid id)
    {
        var result = await _supabaseService.DesactivarCondominioAsync(id);
        if (!result)
        {
            return NotFound(new { error = "Condominio no encontrado" });
        }

        return NoContent();
    }

    [AllowAnonymous]
    [RequireDevKey]
    [HttpPatch("{id}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateCondominio(Guid id, [FromBody] UpdateCondominioRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (condominio, error) = await _supabaseService.ActualizarCondominioAsync(id, dto);
        if (error != null)
        {
            if (error == "Condominio no encontrado")
            {
                return NotFound(new { error });
            }
            return BadRequest(new { error });
        }

        return Ok(new
        {
            id = condominio!.Id,
            nombre = condominio.Nombre,
            activo = condominio.Activo,
            creadoEn = condominio.CreadoEn
        });
    }

    [Authorize]
    [HttpPost("{id}/codigo")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GenerarCodigo(Guid id, [FromBody] GenerarCodigoRequestDto? dto)
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;
                          
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, accessToken);

        if (!string.Equals(rolNombre, "Administrador", StringComparison.OrdinalIgnoreCase) || condominioId != id)
        {
            return StatusCode(403, new { error = "No tienes permiso sobre este condominio" });
        }

        try
        {
            var result = await _supabaseService.GenerarCodigoCondominioAsync(id, dto?.MinutosVigencia, userId);
            return Ok(result);
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [Authorize]
    [HttpPost("~/api/codigos/condominio/redimir")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status410Gone)]
    public async Task<IActionResult> RedimirCodigoCondominio([FromBody] RedimirCodigoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;
                          
        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var result = await _supabaseService.RedimirCodigoCondominioAsync(dto.Codigo, userId, userId);
            return Ok(result);
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
