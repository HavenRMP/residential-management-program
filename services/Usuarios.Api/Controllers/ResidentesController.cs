using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Roles;
using HavenApi.Shared.Rpc;
using Usuarios.Api.Services;

namespace Usuarios.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class ResidentesController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<ResidentesController> _logger;

    public ResidentesController(ISupabaseService supabaseService, ILogger<ResidentesController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    [HttpDelete("{id:guid}/condominio")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RetirarResidenteDelCondominio(Guid id)
    {
        if (!User.TryGetUserId(out var adminId))
        {
            _logger.LogWarning("RetirarResidenteDelCondominio: Unauthorized, missing or invalid user ID.");
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.GetBearerToken();
        var adminUsuario = await _supabaseService.GetUsuarioByIdAsync(adminId, accessToken, adminId);

        if (adminUsuario == null)
        {
            _logger.LogWarning("RetirarResidenteDelCondominio: Requesting user {UserId} not found.", adminId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        if (!string.Equals(adminUsuario.EffectiveRol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase))
        {
            _logger.LogWarning("RetirarResidenteDelCondominio: Forbidden, user {UserId} is not an Admin.", adminId);
            return StatusCode(403, new { error = "Se requiere rol de administrador" });
        }

        if (adminUsuario.CondominioId == null)
        {
            _logger.LogWarning("RetirarResidenteDelCondominio: Admin {UserId} does not have a CondominioId.", adminId);
            return BadRequest(new { error = "El administrador no tiene un condominio asignado" });
        }

        try
        {
            var success = await _supabaseService.RetirarResidenteCondominioAsync(id, adminUsuario.CondominioId.Value, adminId);
            if (!success)
            {
                _logger.LogWarning("RetirarResidenteDelCondominio: Residente {ResidenteId} not found or could not be removed.", id);
                return NotFound(new { error = "Residente no encontrado" });
            }

            return NoContent();
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            _logger.LogWarning("RetirarResidenteDelCondominio: RPC Exception. Status {Status}, Error {Error}", status, mensaje);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
