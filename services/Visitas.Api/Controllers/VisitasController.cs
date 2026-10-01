using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Roles;
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

    private async Task<(IActionResult? Error, Guid? CondominioId, Guid UserId)> ValidateRoleAsync(Func<string, bool> rolValidator, string errorMessage)
    {
        if (!User.TryGetUserId(out var userId))
        {
            _logger.LogWarning("ValidateRole: Unauthorized, missing or invalid user ID.");
            return (Unauthorized(new { error = "Token invalido: no contiene ID de usuario" }), null, Guid.Empty);
        }

        var accessToken = HttpContext.Request.GetBearerToken();

        var (rolNombre, condominioId) = await _supabaseService.GetContextoUsuarioAsync(userId, accessToken);

        if (rolNombre == null)
        {
            _logger.LogWarning("ValidateRole: User {UserId} not found.", userId);
            return (NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" }), null, userId);
        }

        if (!rolValidator(rolNombre))
        {
            _logger.LogWarning("ValidateRole: Forbidden, user {UserId} with role {RoleName} failed validation.", userId, rolNombre);
            return (StatusCode(403, new { error = errorMessage }), null, userId);
        }

        return (null, condominioId, userId);
    }

    private static object ProyectarVisitaVigilancia(VisitaDto v)
    {
        return new
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
            estado = v.Estado,
            horaEntrada = v.HoraEntrada,
            horaSalida = v.HoraSalida,
            creadoPorNombre = v.CreadoPorNombre
        };
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
            var expectedEnd = dto.FechaLlegadaEsperada;
            if (dto.HorasVigencia.HasValue)
            {
                expectedEnd = expectedEnd.AddHours(dto.HorasVigencia.Value);
            }

            if (expectedEnd < DateTimeOffset.UtcNow)
            {
                return BadRequest(new { error = "VI008: La visita ya expiró o su vigencia ha concluido respecto a la fecha actual." });
            }

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

    [HttpPost("{id:guid}/cancelar")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CancelVisita(Guid id)
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var success = await _supabaseService.CancelVisitaAsync(id, userId);
            
            if (!success)
            {
                return NotFound(new { error = "Visita no encontrada" });
            }

            return NoContent();
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("hoy")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetVisitasHoy([FromQuery] PaginationParams paginacion, [FromQuery] string? busqueda = null)
    {
        var (roleError, condominioId, _) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null)
            return roleError;

        if (condominioId == null)
        {
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        var (items, totalCount) = await _supabaseService.GetVisitasHoyAsync(condominioId.Value, paginacion, busqueda);
        
        var resultList = items.Select(ProyectarVisitaVigilancia).ToList();
        
        var pagedResult = PagedResult<object>.Create(resultList, paginacion, totalCount);
        return Ok(pagedResult);
    }

    [HttpGet("codigo/{codigo}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status410Gone)]
    public async Task<IActionResult> ValidarCodigo(string codigo)
    {
        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null)
            return roleError;

        if (string.IsNullOrWhiteSpace(codigo) || codigo.Length > 20)
        {
            return BadRequest(new { error = "El código proporcionado es inválido o excede la longitud permitida." });
        }

        try
        {
            var visita = await _supabaseService.ValidarCodigoAsync(codigo, userId);
            return Ok(ProyectarVisitaVigilancia(visita));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
    [HttpPost("{id:guid}/entrada")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    [ProducesResponseType(StatusCodes.Status410Gone)]
    public async Task<IActionResult> RegistrarEntrada(Guid id, [FromBody] RegistrarEntradaRequestDto? dto = null)
    {
        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.EsVigilancia(),
            "Se requiere rol de vigilancia para registrar entradas"
        );

        if (roleError != null)
            return roleError;

        try
        {
            var visita = await _supabaseService.RegistrarEntradaAsync(id, userId, dto?.VehiculoPlacas);
            return Ok(ProyectarVisitaVigilancia(visita));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
    [HttpPost("{id:guid}/salida")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> RegistrarSalida(Guid id)
    {
        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.EsVigilancia(),
            "Se requiere rol de vigilancia para registrar salidas"
        );

        if (roleError != null)
            return roleError;

        try
        {
            var visita = await _supabaseService.RegistrarSalidaAsync(id, userId);
            return Ok(ProyectarVisitaVigilancia(visita));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
    [HttpGet("historico")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    public async Task<IActionResult> GetVisitasHistorico(
        [FromQuery] PaginationParams paginacion,
        [FromQuery] DateTimeOffset? desde = null,
        [FromQuery] DateTimeOffset? hasta = null,
        [FromQuery] int? viviendaId = null,
        [FromQuery] string? estado = null)
    {
        var (roleError, condominioId, _) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia para consultar el histórico"
        );

        if (roleError != null)
            return roleError;

        if (desde.HasValue && hasta.HasValue && desde.Value > hasta.Value)
        {
            return BadRequest(new { error = "La fecha 'desde' no puede ser posterior a la fecha 'hasta'." });
        }

        if (!string.IsNullOrEmpty(estado))
        {
            var validStates = new[] { "programada", "en_curso", "finalizada", "cancelada", "expirada" };
            if (!validStates.Contains(estado.ToLowerInvariant()))
            {
                return BadRequest(new { error = "El estado proporcionado no es válido." });
            }
            estado = estado.ToLowerInvariant();
        }

        if (condominioId == null)
        {
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        var (items, totalCount) = await _supabaseService.GetVisitasHistoricoAsync(
            condominioId.Value, desde, hasta, viviendaId, estado, paginacion);

        var resultList = items.Select(ProyectarVisitaVigilancia).ToList();

        var pagedResult = PagedResult<object>.Create(resultList, paginacion, totalCount);
        return Ok(pagedResult);
    }
}
