using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace Viviendas.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ViviendasController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<ViviendasController> _logger;

    public ViviendasController(ISupabaseService supabaseService, ILogger<ViviendasController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    private async Task<(IActionResult? Error, Guid? CondominioId)> ValidateAdminAsync()
    {
        var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? User.FindFirst("sub")?.Value;

        if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
        {
            _logger.LogWarning("ValidateAdmin: Unauthorized, missing or invalid user ID.");
            return (Unauthorized(new { error = "Token invalido: no contiene ID de usuario" }), null);
        }

        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        var (rolNombre, condominioId) = await _supabaseService.GetContextoAdminAsync(userId, accessToken);

        if (rolNombre == null)
        {
            _logger.LogWarning("ValidateAdmin: User {UserId} not found.", userId);
            return (NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" }), null);
        }

        if (!string.Equals(rolNombre, "Administrador", StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("ValidateAdmin: Forbidden, user {UserId} is not an Admin.", userId);
            return (StatusCode(403, new { error = "Se requiere rol de administrador" }), null);
        }

        return (null, condominioId);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [HttpGet]
    public async Task<IActionResult> GetViviendas()
    {
        var viviendas = await _supabaseService.GetViviendasAsync();
        var result = viviendas.Select(v => new
        {
            id = v.Id,
            numeroCasa = v.NumeroCasa,
            tipo = v.Tipo,
            condominioId = v.CondominioId,
            condominioNombre = v.CondominioNombre,
            creadoEn = v.CreadoEn
        });

        return Ok(result);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [HttpGet("{id}")]
    public async Task<IActionResult> GetVivienda(int id)
    {
        var vivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (vivienda == null)
        {
            _logger.LogWarning("GetVivienda: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        return Ok(new
        {
            id = vivienda.Id,
            numeroCasa = vivienda.NumeroCasa,
            tipo = vivienda.Tipo,
            condominioId = vivienda.CondominioId,
            condominioNombre = vivienda.CondominioNombre,
            creadoEn = vivienda.CreadoEn
        });
    }

    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [HttpPost]
    public async Task<IActionResult> CreateVivienda([FromBody] CreateViviendaRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        if (condominioId == null)
        {
            _logger.LogWarning("CreateVivienda: El administrador no tiene un condominio asignado.");
            return BadRequest(new { error = "El administrador no tiene un condominio asignado" });
        }

        var (vivienda, error) = await _supabaseService.CreateViviendaAsync(dto, condominioId.Value);
        if (error != null)
        {
            if (error.Contains("Ya existe una vivienda registrada con ese número de casa"))
            {
                _logger.LogWarning("CreateVivienda: Conflict, {Error}", error);
                return Conflict(new { error });
            }

            _logger.LogWarning("CreateVivienda: Bad request, {Error}", error);
            return BadRequest(new { error });
        }

        return CreatedAtAction(nameof(GetVivienda), new { id = vivienda!.Id }, new
        {
            id = vivienda.Id,
            numeroCasa = vivienda.NumeroCasa,
            tipo = vivienda.Tipo,
            condominioId = vivienda.CondominioId,
            condominioNombre = vivienda.CondominioNombre,
            creadoEn = vivienda.CreadoEn
        });
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [HttpPut("{id}")]
    public async Task<IActionResult> UpdateVivienda(int id, [FromBody] UpdateViviendaRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var currentVivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (currentVivienda == null)
        {
            _logger.LogWarning("UpdateVivienda: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        if (currentVivienda.CondominioId != condominioId)
        {
            _logger.LogWarning("UpdateVivienda: Forbidden, user doesn't own this condominium.");
            return StatusCode(403, new { error = "No tienes permiso sobre viviendas de otro condominio" });
        }

        var (vivienda, error) = await _supabaseService.UpdateViviendaAsync(id, dto);
        if (error != null)
        {
            if (error.Contains("Ya existe una vivienda registrada con ese número de casa"))
            {
                _logger.LogWarning("UpdateVivienda: Conflict, {Error}", error);
                return Conflict(new { error });
            }

            if (error == "Vivienda no encontrada o no se pudo actualizar")
            {
                _logger.LogWarning("UpdateVivienda: Not found, {Error}", error);
                return NotFound(new { error });
            }

            _logger.LogWarning("UpdateVivienda: Bad request, {Error}", error);
            return BadRequest(new { error });
        }

        return Ok(new
        {
            id = vivienda!.Id,
            numeroCasa = vivienda.NumeroCasa,
            tipo = vivienda.Tipo,
            creadoEn = vivienda.CreadoEn
        });
    }

    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [HttpDelete("{id}")]
    public async Task<IActionResult> DeleteVivienda(int id)
    {
        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var currentVivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (currentVivienda == null)
        {
            _logger.LogWarning("DeleteVivienda: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        if (currentVivienda.CondominioId != condominioId)
        {
            _logger.LogWarning("DeleteVivienda: Forbidden, user doesn't own this condominium.");
            return StatusCode(403, new { error = "No tienes permiso sobre viviendas de otro condominio" });
        }

        var success = await _supabaseService.DeleteViviendaAsync(id);
        if (!success)
        {
            _logger.LogWarning("DeleteVivienda: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        return NoContent();
    }

    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [HttpPost("{id}/residentes")]
    public async Task<IActionResult> AssignResidente(int id, [FromBody] AsignarResidenteRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var currentVivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (currentVivienda == null)
        {
            _logger.LogWarning("AssignResidente: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        if (currentVivienda.CondominioId != condominioId)
        {
            _logger.LogWarning("AssignResidente: Forbidden, user doesn't own this condominium.");
            return StatusCode(403, new { error = "No tienes permiso sobre viviendas de otro condominio" });
        }

        var (data, error) = await _supabaseService.AssignResidenteAsync(id, dto);
        if (data == null)
        {
            if (error != null && error.Contains("El residente ya está asignado"))
            {
                _logger.LogWarning("AssignResidente: Conflict, {Error}", error);
                return Conflict(new { error });
            }
            if (error != null && error.Contains("no encontrad"))
            {
                _logger.LogWarning("AssignResidente: Not found, {Error}", error);
                return NotFound(new { error });
            }
            
            _logger.LogWarning("AssignResidente: Bad request, {Error}", error);
            return BadRequest(new { error });
        }

        return StatusCode(201, data);
    }

    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [HttpDelete("{id}/residentes/{usuarioId}")]
    public async Task<IActionResult> RemoveResidente(int id, Guid usuarioId)
    {
        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var currentVivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (currentVivienda == null)
        {
            _logger.LogWarning("RemoveResidente: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        if (currentVivienda.CondominioId != condominioId)
        {
            _logger.LogWarning("RemoveResidente: Forbidden, user doesn't own this condominium.");
            return StatusCode(403, new { error = "No tienes permiso sobre viviendas de otro condominio" });
        }

        var success = await _supabaseService.RemoveResidenteAsync(id, usuarioId);
        if (!success)
        {
            _logger.LogWarning("RemoveResidente: Asignación not found for vivienda {Id} and user {UserId}.", id, usuarioId);
            return NotFound(new { error = "Asignación no encontrada" });
        }

        return NoContent();
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [HttpGet("mis-viviendas")]
    public async Task<IActionResult> GetMisViviendas()
    {
        var accessToken = HttpContext.Request.Headers["Authorization"]
            .ToString().Replace("Bearer ", "");

        if (string.IsNullOrEmpty(accessToken))
        {
            _logger.LogWarning("GetMisViviendas: Unauthorized, missing token.");
            return Unauthorized(new { error = "Token invalido o ausente" });
        }

        var viviendas = await _supabaseService.GetMisViviendasAsync(accessToken);
        
        var result = viviendas.Select(v => new
        {
            viviendaId = v.ViviendaId,
            numeroCasa = v.NumeroCasa,
            tipo = v.Tipo,
            activo = v.Activo,
            creadoEn = v.CreadoEn
        });

        return Ok(result);
    }

    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [HttpGet("{id}/residentes")]
    public async Task<IActionResult> GetResidentes(int id)
    {
        var (adminError, condominioId) = await ValidateAdminAsync();
        if (adminError != null)
            return adminError;

        var currentVivienda = await _supabaseService.GetViviendaByIdAsync(id);
        if (currentVivienda == null)
        {
            _logger.LogWarning("GetResidentes: Vivienda {Id} not found.", id);
            return NotFound(new { error = "Vivienda no encontrada" });
        }

        if (currentVivienda.CondominioId != condominioId)
        {
            _logger.LogWarning("GetResidentes: Forbidden, user doesn't own this condominium.");
            return StatusCode(403, new { error = "No tienes permiso sobre viviendas de otro condominio" });
        }

        var residentes = await _supabaseService.GetResidentesByViviendaIdAsync(id);
        return Ok(residentes);
    }
}
