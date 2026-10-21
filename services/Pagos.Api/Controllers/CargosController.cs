using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

namespace Pagos.Api.Controllers;

[Authorize(Policy = "Admin")]
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
}
