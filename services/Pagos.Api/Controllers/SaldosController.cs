using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

namespace Pagos.Api.Controllers;

[ApiController]
[Route("api/saldos")]
public class SaldosController : ControllerBase
{
    private readonly ISaldosService _saldosService;
    private readonly ILogger<SaldosController> _logger;

    public SaldosController(
        ISaldosService saldosService,
        ILogger<SaldosController> logger)
    {
        _saldosService = saldosService;
        _logger = logger;
    }

    /// <summary>
    /// Consulta el saldo consolidado de una vivienda específica (Admin de su condominio o Residente titular).
    /// </summary>
    [Authorize(Policy = "AdminOInquilino")]
    [HttpGet("viviendas/{viviendaId:int}")]
    [ProducesResponseType(typeof(SaldoViviendaResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ObtenerSaldoPorVivienda(int viviendaId)
    {
        try
        {
            var saldo = await _saldosService.ObtenerSaldoPorViviendaAsync(viviendaId);
            return Ok(saldo);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ObtenerSaldoPorVivienda recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ObtenerSaldoPorVivienda argumento inválido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("ObtenerSaldoPorVivienda acceso no autorizado: {Message}", ex.Message);
            return StatusCode(StatusCodes.Status403Forbidden, new ErrorResponseDto(ex.Message));
        }
    }

    /// <summary>
    /// Consulta la suma de saldos sobre todas las viviendas del usuario residente autenticado, con su desglose (exclusivo para Inquilino).
    /// </summary>
    [Authorize(Policy = "Inquilino")]
    [HttpGet("mi-saldo")]
    [ProducesResponseType(typeof(SaldoUsuarioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ObtenerMiSaldo()
    {
        var saldo = await _saldosService.ObtenerMiSaldoAsync();
        return Ok(saldo);
    }

    /// <summary>
    /// Consulta la suma de saldos y desglose para un usuario dado, limitado exclusivamente a viviendas del condominio del administrador (exclusivo para Admin).
    /// </summary>
    [Authorize(Policy = "Admin")]
    [HttpGet("usuarios/{usuarioId:guid}")]
    [ProducesResponseType(typeof(SaldoUsuarioResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> ObtenerSaldoPorUsuario(Guid usuarioId)
    {
        try
        {
            var saldo = await _saldosService.ObtenerSaldoPorUsuarioAsync(usuarioId);
            return Ok(saldo);
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ObtenerSaldoPorUsuario argumento inválido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
    }

    /// <summary>
    /// Consulta los movimientos de saldo a favor de una vivienda con filtros opcionales y paginación (Admin de su condominio o Residente titular).
    /// </summary>
    [Authorize(Policy = "AdminOInquilino")]
    [HttpGet("viviendas/{viviendaId:int}/movimientos")]
    [ProducesResponseType(typeof(RespuestaPaginadaDto<MovimientoSaldoResponse>), StatusCodes.Status200OK)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    public async Task<IActionResult> ListarMovimientosSaldoPorVivienda(
        int viviendaId,
        [FromQuery] ConsultaMovimientosSaldoFiltrosDto filtros)
    {
        try
        {
            var resultado = await _saldosService.ListarMovimientosSaldoPorViviendaAsync(viviendaId, filtros);
            return Ok(resultado);
        }
        catch (KeyNotFoundException ex)
        {
            _logger.LogWarning("ListarMovimientosSaldoPorVivienda recurso no encontrado: {Message}", ex.Message);
            return NotFound(new ErrorResponseDto(ex.Message));
        }
        catch (ArgumentException ex)
        {
            _logger.LogWarning("ListarMovimientosSaldoPorVivienda argumento inválido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }
        catch (UnauthorizedAccessException ex)
        {
            _logger.LogWarning("ListarMovimientosSaldoPorVivienda acceso no autorizado: {Message}", ex.Message);
            return StatusCode(StatusCodes.Status403Forbidden, new ErrorResponseDto(ex.Message));
        }
    }
}

