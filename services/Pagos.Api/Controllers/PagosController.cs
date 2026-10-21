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

    /// <summary>
    /// Confirma un pago reportado por un residente (exclusivo para Administrador).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost("{id:guid}/confirmar")]
    [ProducesResponseType(typeof(ConfirmarPagoResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> ConfirmarPago(Guid id)
    {
        try
        {
            var resultado = await _pagosService.ConfirmarPagoAdminAsync(id);
            return Ok(resultado);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ConfirmarPago recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ConfirmarPago validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("ConfirmarPago falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Rechaza un pago reportado por un residente especificando el motivo (exclusivo para Administrador).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost("{id:guid}/rechazar")]
    [ProducesResponseType(typeof(RechazarPagoResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RechazarPago(Guid id, [FromBody] RechazarPagoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var resultado = await _pagosService.RechazarPagoAdminAsync(id, request);
            return Ok(resultado);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("RechazarPago recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("RechazarPago validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("RechazarPago falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }

    /// <summary>
    /// Anula un pago confirmado generando una reversa (exclusivo para Administrador).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpPost("{id:guid}/anular")]
    [ProducesResponseType(typeof(AnularPagoResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status409Conflict)]
    public async Task<IActionResult> AnularPago(Guid id, [FromBody] AnularPagoRequest request)
    {
        if (!ModelState.IsValid)
        {
            return BadRequest(ModelState);
        }

        try
        {
            var resultado = await _pagosService.AnularPagoAdminAsync(id, request);
            return Ok(resultado);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("AnularPago recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("AnularPago validación fallida: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (PostgrestException ex)
        {
            _logger.LogWarning("AnularPago falló en base de datos: {Code} - {Message}", ex.Code, ex.MensajeUsuario);
            return StatusCode(ex.StatusCode, new ErrorResponseDto(ex.MensajeUsuario));
        }
    }
}
