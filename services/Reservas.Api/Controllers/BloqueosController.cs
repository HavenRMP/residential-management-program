using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Reservas.Api.DTOs;
using Reservas.Api.Services;
using System.Threading.Tasks;

namespace Reservas.Api.Controllers;

[ApiController]
[Route("api/admin/bloqueos")]
[Authorize]
public class BloqueosController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;

    public BloqueosController(ISupabaseService supabaseService)
    {
        _supabaseService = supabaseService;
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CrearBloqueo([FromBody] CrearBloqueoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
            return Unauthorized(new { error = "Token invalido" });

        var token = Request.GetBearerToken();
        if (string.IsNullOrEmpty(token)) return Unauthorized(new { error = "Token invalido" });

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, token);
        
        if (!condominioId.HasValue)
            return StatusCode(403, new { error = "El usuario no pertenece a un condominio" });

        if (!rolNombre.EsAdministrador())
            return StatusCode(403, new { error = "Se requiere rol de administrador" });

        try
        {
            var result = await _supabaseService.CrearBloqueoAsync(userId, dto.AreaId!.Value, dto.Inicio!.Value, dto.Fin!.Value, dto.Motivo);
            
            if (result == null)
                return BadRequest(new { error = "No se pudo crear el bloqueo" });

            var responseObj = new
            {
                bloqueoId = result.BloqueoId,
                areaId = result.AreaId,
                inicio = result.Inicio,
                fin = result.Fin,
                motivo = result.Motivo,
                reservasAfectadas = result.ReservasAfectadas
            };

            return StatusCode(StatusCodes.Status201Created, responseObj);
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = HavenApi.Shared.Rpc.RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
