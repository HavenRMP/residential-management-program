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

    /// <summary>
    /// Actualiza los campos editables de una plantilla de cargo recurrente (exclusivo para Administrador).
    /// </summary>
    [HttpPut("{id:guid}")]
    [ProducesResponseType(typeof(PlantillaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ActualizarPlantilla(Guid id, [FromBody] ActualizarPlantillaCargoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var plantilla = await _plantillasCargoService.ActualizarPlantillaAsync(id, request);
            return Ok(plantilla);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ActualizarPlantilla recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ActualizarPlantilla validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("ActualizarPlantilla conflicto o error en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Desactiva una plantilla de cargo activa existente (exclusivo para Administrador).
    /// </summary>
    [HttpPost("{id:guid}/desactivar")]
    [ProducesResponseType(typeof(PlantillaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> DesactivarPlantilla(Guid id)
    {
        try
        {
            var plantilla = await _plantillasCargoService.DesactivarPlantillaAsync(id);
            return Ok(plantilla);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("DesactivarPlantilla recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("DesactivarPlantilla conflicto o error en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Activa una plantilla de cargo inactiva existente (exclusivo para Administrador).
    /// </summary>
    [HttpPost("{id:guid}/activar")]
    [ProducesResponseType(typeof(PlantillaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ActivarPlantilla(Guid id)
    {
        try
        {
            var plantilla = await _plantillasCargoService.ActivarPlantillaAsync(id);
            return Ok(plantilla);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ActivarPlantilla recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("ActivarPlantilla conflicto o error en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }
}
