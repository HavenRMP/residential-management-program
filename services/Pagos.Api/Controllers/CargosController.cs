using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

namespace Pagos.Api.Controllers;

[Authorize(Policy = "AdminOInquilino")]
[ApiController]
[Route("api/[controller]")]
public class CargosController : ControllerBase
{
    private readonly ICargosService _cargosService;
    private readonly ILogger<CargosController> _logger;

    public CargosController(ICargosService cargosService, ILogger<CargosController> logger)
    {
        _cargosService = cargosService;
        _logger = logger;
    }

    /// <summary>
    /// Crea un nuevo cargo manual para una vivienda del condominio (exclusivo para Administrador).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost]
    [ProducesResponseType(typeof(CargoResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CrearCargo([FromBody] CrearCargoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var cargo = await _cargosService.CrearCargoAsync(request);
            return StatusCode(StatusCodes.Status201Created, cargo);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("CrearCargo recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("CrearCargo validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }

    /// <summary>
    /// Consulta el listado de cargos con filtros opcionales y paginación (Admin e Inquilino).
    /// </summary>
    [HttpGet]
    [ProducesResponseType(typeof(RespuestaPaginadaDto<CargoResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ListarCargos([FromQuery] ConsultaCargosFiltrosDto filtros)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var resultado = await _cargosService.ListarCargosAsync(filtros);
            return Ok(resultado);
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("ListarCargos acceso denegado: {Message}", ex.Message);
            return StatusCode(StatusCodes.Status403Forbidden, new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ListarCargos validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }

    /// <summary>
    /// Obtiene el detalle de un cargo específico incluyendo sus pagos asociados (Admin e Inquilino).
    /// </summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(CargoDetalleResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ObtenerDetalleCargo(Guid id)
    {
        try
        {
            var cargo = await _cargosService.ObtenerDetalleCargoAsync(id);
            return Ok(cargo);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ObtenerDetalleCargo no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ObtenerDetalleCargo argumento inválido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }

    /// <summary>
    /// Cancela un cargo existente especificando el motivo (Solo administradores).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost("{id:guid}/cancelar")]
    [ProducesResponseType(typeof(CargoResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CancelarCargo(Guid id, [FromBody] CancelarCargoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var cargo = await _cargosService.CancelarCargoAsync(id, request);
            return Ok(cargo);
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("CancelarCargo falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("CancelarCargo recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("CancelarCargo argumento inválido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }
}
