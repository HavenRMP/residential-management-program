using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Rpc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Visitas.Api.DTOs;
using Visitas.Api.Services;

namespace Visitas.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class VisitasController : ControllerBase
{
    private readonly ISupabaseService _supabaseService;
    private readonly ILogger<VisitasController> _logger;

    public VisitasController(ISupabaseService supabaseService, ILogger<VisitasController> logger)
    {
        _supabaseService = supabaseService;
        _logger = logger;
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CreateVisita([FromBody] CreateVisitaRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var result = await _supabaseService.CreateVisitaAsync(dto, userId);
            
            return StatusCode(201, new
            {
                id = result.Id,
                viviendaId = result.ViviendaId,
                numeroCasa = result.NumeroCasa,
                nombreVisitante = result.NombreVisitante,
                apellidosVisitante = result.ApellidosVisitante,
                telefonoVisitante = result.TelefonoVisitante,
                motivo = result.Motivo,
                numAcompanantes = result.NumAcompanantes,
                vehiculoPlacas = result.VehiculoPlacas,
                notas = result.Notas,
                fechaLlegadaEsperada = result.FechaLlegadaEsperada,
                vigenciaHasta = result.VigenciaHasta,
                codigo = result.Codigo,
                estado = result.Estado,
                creadoEn = result.CreadoEn
            });
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
