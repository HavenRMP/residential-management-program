using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
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

    [HttpGet("mis-visitas")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMisVisitas([FromQuery] PaginationParams paginacion, [FromQuery] string? estado = null)
    {
        var accessToken = HttpContext.Request.GetBearerToken();
        if (string.IsNullOrEmpty(accessToken))
        {
            return Unauthorized(new { error = "Token invalido o ausente" });
        }

        if (!string.IsNullOrEmpty(estado))
        {
            var validStates = new[] { "programada", "en_curso", "finalizada", "cancelada", "expirada" };
            if (!validStates.Contains(estado.ToLowerInvariant()))
            {
                return BadRequest(new { error = "El estado proporcionado no es válido" });
            }
            estado = estado.ToLowerInvariant();
        }

        var (items, totalCount) = await _supabaseService.GetMisVisitasAsync(accessToken, estado, paginacion);

        var resultList = items.Select(v => new
        {
            id = v.Id,
            viviendaId = v.ViviendaId,
            numeroCasa = v.NumeroCasa,
            nombreVisitante = v.NombreVisitante,
            apellidosVisitante = v.ApellidosVisitante,
            telefonoVisitante = v.TelefonoVisitante,
            motivo = v.Motivo,
            numAcompanantes = v.NumAcompanantes,
            vehiculoPlacas = v.VehiculoPlacas,
            notas = v.Notas,
            fechaLlegadaEsperada = v.FechaLlegadaEsperada,
            vigenciaHasta = v.VigenciaHasta,
            codigo = v.Codigo,
            estado = v.Estado,
            horaEntrada = v.HoraEntrada,
            horaSalida = v.HoraSalida,
            creadoPorNombre = v.CreadoPorNombre,
            creadoEn = v.CreadoEn
        }).Cast<object>().ToList();

        var pagedResult = HavenApi.Shared.Pagination.PagedResult<object>.Create(resultList, paginacion, totalCount);
        return Ok(pagedResult);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> UpdateVisita(Guid id, [FromBody] UpdateVisitaRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var result = await _supabaseService.UpdateVisitaAsync(id, userId, dto);
            
            return Ok(new
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
