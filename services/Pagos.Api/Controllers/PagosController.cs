using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

namespace Pagos.Api.Controllers;

[Authorize(Policy = "AdminOInquilino")]
[ApiController]
[Route("api/[controller]")]
public class PagosController : ControllerBase
{
    private readonly IPagosService _pagosService;
    private readonly ILogger<PagosController> _logger;

    public PagosController(IPagosService pagosService, ILogger<PagosController> logger)
    {
        _pagosService = pagosService;
        _logger = logger;
    }

    /// <summary>
    /// Registra un pago directo realizado para un cargo del condominio (exclusivo para Administrador).
    /// El pago nace en estado Confirmado.
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost]
    [ProducesResponseType(typeof(RegistrarPagoResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegistrarPago([FromBody] RegistrarPagoAdminRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var resultado = await _pagosService.RegistrarPagoAdminAsync(request);
            return StatusCode(StatusCodes.Status201Created, resultado);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("RegistrarPago recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("RegistrarPago validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("RegistrarPago falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Reporta un pago realizado por un inquilino para un cargo de su vivienda.
    /// El pago nace en estado PendienteConfirmacion (exclusivo para Inquilino).
    /// </summary>
    [Authorize(Policy = "Inquilino")]
    [HttpPost("reportar")]
    [ProducesResponseType(typeof(PagoResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ReportarPago([FromBody] ReportarPagoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var pago = await _pagosService.ReportarPagoInquilinoAsync(request);
            return StatusCode(StatusCodes.Status201Created, pago);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ReportarPago recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ReportarPago validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("ReportarPago falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }
}
