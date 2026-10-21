using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

namespace Pagos.Api.Controllers;

[Authorize(Policy = "Admin")]
[ApiController]
[Route("api/plantillas-cargo")]
public class PlantillasCargoController : ControllerBase
{
    private readonly IPlantillasCargoService _plantillasCargoService;
    private readonly ILogger<PlantillasCargoController> _logger;

    public PlantillasCargoController(
        IPlantillasCargoService plantillasCargoService,
        ILogger<PlantillasCargoController> logger)
    {
        _plantillasCargoService = plantillasCargoService;
        _logger = logger;
    }

    /// <summary>
    /// Da de alta de forma masiva y atómica una plantilla de cargo recurrente por cada vivienda especificada (exclusivo para Administrador).
    /// </summary>
    [HttpPost]
    [ProducesResponseType(typeof(List<PlantillaResponse>), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CrearPlantillasMasivas([FromBody] CrearPlantillasCargoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var plantillas = await _plantillasCargoService.CrearPlantillasMasivasAsync(request);
            return StatusCode(StatusCodes.Status201Created, plantillas);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("CrearPlantillasMasivas recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("CrearPlantillasMasivas validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("CrearPlantillasMasivas conflicto o error en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Consulta el listado paginado de plantillas de cargo recurrente con filtros opcionales (exclusivo para Administrador).
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(RespuestaPaginadaDto<PlantillaResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ListarPlantillas([FromQuery] ConsultaPlantillasCargoFiltrosDto filtros)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var resultado = await _plantillasCargoService.ListarPlantillasAsync(filtros);
            return Ok(resultado);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ListarPlantillas validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }
}
