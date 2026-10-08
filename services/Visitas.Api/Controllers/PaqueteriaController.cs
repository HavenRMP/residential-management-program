using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Extensions;
using HavenApi.Shared.Pagination;
using HavenApi.Shared.Rpc;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using HavenApi.Shared.Roles;

namespace Visitas.Api.Controllers;

[Authorize]
[ApiController]
[Route("api/[controller]")]
public class PaqueteriaController : ControllerBase
{
    private readonly IPaqueteriaSupabaseService _paqueteriaService;
    private readonly ILogger<PaqueteriaController> _logger;

    public PaqueteriaController(IPaqueteriaSupabaseService paqueteriaService, ILogger<PaqueteriaController> logger)
    {
        _paqueteriaService = paqueteriaService;
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

        var (rolNombre, condominioId) = await _paqueteriaService.GetContextoUsuarioAsync(userId, accessToken);

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

    private static object ProyectarPaqueteCaseta(PaqueteCasetaDto p)
    {
        return new
        {
            id = p.Id,
            condominioId = p.CondominioId,
            viviendaId = p.ViviendaId,
            numeroCasa = p.NumeroCasa,
            servicioId = p.ServicioId,
            servicioNombre = p.ServicioNombre,
            destinatarioNombre = p.DestinatarioNombre,
            numeroGuia = p.NumeroGuia,
            descripcion = p.Descripcion,
            notas = p.Notas,
            fechaEsperadaDesde = p.FechaEsperadaDesde,
            fechaEsperadaHasta = p.FechaEsperadaHasta,
            estado = p.Estado,
            esInesperado = p.EsInesperado,
            ubicacionAlmacen = p.UbicacionAlmacen,
            recibidoEn = p.RecibidoEn,
            recibidoPorNombre = p.RecibidoPorNombre,
            entregadoEn = p.EntregadoEn,
            entregadoANombre = p.EntregadoANombre,
            creadoPorNombre = p.CreadoPorNombre,
            creadoEn = p.CreadoEn
        };
    }

    private static object ProyectarPaqueteHistorico(PaqueteHistoricoDto p)
    {
        return new
        {
            id = p.Id,
            condominioId = p.CondominioId,
            condominioNombre = p.CondominioNombre,
            viviendaId = p.ViviendaId,
            numeroCasa = p.NumeroCasa,
            servicioId = p.ServicioId,
            servicioNombre = p.ServicioNombre,
            destinatarioNombre = p.DestinatarioNombre,
            numeroGuia = p.NumeroGuia,
            descripcion = p.Descripcion,
            notas = p.Notas,
            fechaEsperadaDesde = p.FechaEsperadaDesde,
            fechaEsperadaHasta = p.FechaEsperadaHasta,
            estado = p.Estado,
            esInesperado = p.EsInesperado,
            ubicacionAlmacen = p.UbicacionAlmacen,
            recibidoEn = p.RecibidoEn,
            recibidoPor = p.RecibidoPor,
            recibidoPorNombre = p.RecibidoPorNombre,
            entregadoEn = p.EntregadoEn,
            entregadoANombre = p.EntregadoANombre,
            entregadoPor = p.EntregadoPor,
            entregadoPorNombre = p.EntregadoPorNombre,
            creadoPor = p.CreadoPor,
            creadoPorNombre = p.CreadoPorNombre,
            creadoEn = p.CreadoEn,
            actualizadoEn = p.ActualizadoEn
        };
    }

    private static object ProyectarPaquete(PaqueteDto p)
    {
        return new
        {
            id = p.Id,
            condominioId = p.CondominioId,
            condominioNombre = p.CondominioNombre,
            viviendaId = p.ViviendaId,
            numeroCasa = p.NumeroCasa,
            servicioId = p.ServicioId,
            servicioNombre = p.ServicioNombre,
            destinatarioNombre = p.DestinatarioNombre,
            numeroGuia = p.NumeroGuia,
            descripcion = p.Descripcion,
            notas = p.Notas,
            fechaEsperadaDesde = p.FechaEsperadaDesde,
            fechaEsperadaHasta = p.FechaEsperadaHasta,
            estado = p.Estado,
            esInesperado = p.EsInesperado,
            ubicacionAlmacen = p.UbicacionAlmacen,
            recibidoEn = p.RecibidoEn,
            recibidoPorNombre = p.RecibidoPorNombre,
            entregadoEn = p.EntregadoEn,
            entregadoANombre = p.EntregadoANombre,
            entregadoPorNombre = p.EntregadoPorNombre,
            creadoPor = p.CreadoPor,
            creadoEn = p.CreadoEn
        };
    }

    private static object ProyectarServicio(ServicioPaqueteriaDto s)
    {
        return new
        {
            id = s.Id,
            condominioId = s.CondominioId,
            nombre = s.Nombre,
            iconoUrl = s.IconoUrl,
            activo = s.Activo,
            esSistema = s.EsSistema,
            creadoEn = s.CreadoEn
        };
    }

    [HttpGet("servicios")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetServicios()
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        var accessToken = HttpContext.Request.GetBearerToken();
        var (rolNombre, condominioId) = await _paqueteriaService.GetContextoUsuarioAsync(userId, accessToken);

        if (rolNombre == null)
        {
            _logger.LogWarning("GetServicios: User {UserId} not found.", userId);
            return NotFound(new { error = "Usuario no encontrado en la tabla 'usuarios'" });
        }

        var servicios = await _paqueteriaService.GetServiciosPaqueteriaAsync(condominioId);
        return Ok(servicios.Select(ProyectarServicio));
    }

    [HttpPost]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> CreatePaquete([FromBody] CreatePaqueteEsperadoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        if (dto.FechaEsperadaHasta.HasValue && dto.FechaEsperadaHasta.Value < DateTimeOffset.UtcNow)
        {
            return BadRequest(new { error = "La fecha límite esperada ya ha pasado respecto a la fecha actual." });
        }

        try
        {
            var result = await _paqueteriaService.CreatePaqueteEsperadoAsync(dto, userId);
            return StatusCode(201, ProyectarPaquete(result));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("mis-paquetes")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<IActionResult> GetMisPaquetes([FromQuery] PaginationParams paginacion, [FromQuery] int? viviendaId = null, [FromQuery] string? estado = null)
    {
        var accessToken = HttpContext.Request.GetBearerToken();
        if (string.IsNullOrEmpty(accessToken))
        {
            return Unauthorized(new { error = "Token invalido o ausente" });
        }

        if (!string.IsNullOrEmpty(estado))
        {
            var validStates = new[] { 
                PaqueteEstados.Esperado, 
                PaqueteEstados.Recibido, 
                PaqueteEstados.Entregado, 
                PaqueteEstados.Cancelado, 
                PaqueteEstados.Vencido, 
                PaqueteEstados.Devuelto 
            };
            var estadoLower = estado.ToLowerInvariant();
            if (!validStates.Contains(estadoLower))
            {
                return BadRequest(new { error = "El estado proporcionado no es válido." });
            }
            estado = estadoLower;
        }

        var (items, totalCount) = await _paqueteriaService.GetMisPaquetesAsync(accessToken, viviendaId, estado, paginacion);

        var resultList = items.Select(ProyectarPaquete).Cast<object>().ToList();
        var pagedResult = PagedResult<object>.Create(resultList, paginacion, totalCount);
        
        return Ok(pagedResult);
    }

    [HttpPut("{id:guid}")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<IActionResult> UpdatePaquete(Guid id, [FromBody] UpdatePaqueteEsperadoRequestDto dto)
    {
        if (!ModelState.IsValid)
            return BadRequest(ModelState);

        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var result = await _paqueteriaService.UpdatePaqueteEsperadoAsync(id, userId, dto);
            return Ok(ProyectarPaquete(result));
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
    public async Task<IActionResult> CancelPaquete(Guid id, [FromBody] CancelPaqueteEsperadoRequestDto dto)
    {
        if (!User.TryGetUserId(out var userId))
        {
            return Unauthorized(new { error = "Token invalido: no contiene ID de usuario" });
        }

        try
        {
            var success = await _paqueteriaService.CancelPaqueteEsperadoAsync(id, userId, dto.Motivo);
            
            if (!success)
            {
                return NotFound(new { error = "Paquete no encontrado o no se pudo cancelar." });
            }

            return NoContent();
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpGet("esperados")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetEsperados([FromQuery] PaginationParams paginacion, [FromQuery] int? viviendaId = null)
    {
        var (roleError, condominioId, _) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null) return roleError;

        if (condominioId == null)
        {
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        var (items, totalCount) = await _paqueteriaService.GetPaquetesCasetaAsync(condominioId.Value, PaqueteEstados.Esperado, viviendaId, paginacion);
        var resultList = items.Select(ProyectarPaqueteCaseta).ToList();
        
        return Ok(PagedResult<object>.Create(resultList, paginacion, totalCount));
    }

    [HttpGet("inventario")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetInventario([FromQuery] PaginationParams paginacion, [FromQuery] int? viviendaId = null)
    {
        var (roleError, condominioId, _) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null) return roleError;

        if (condominioId == null)
        {
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        var (items, totalCount) = await _paqueteriaService.GetPaquetesCasetaAsync(condominioId.Value, PaqueteEstados.Recibido, viviendaId, paginacion);
        var resultList = items.Select(ProyectarPaqueteCaseta).ToList();
        
        return Ok(PagedResult<object>.Create(resultList, paginacion, totalCount));
    }

    [HttpPost("recepcion")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Recepcion([FromBody] RecibirPaqueteRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null) return roleError;

        try
        {
            var result = await _paqueteriaService.RecibirPaqueteAsync(dto, userId);
            return StatusCode(201, ProyectarPaqueteCaseta(result));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpPost("{id:guid}/entrega")]
    [ProducesResponseType(StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> Entrega(Guid id, [FromBody] EntregarPaqueteRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.PuedeConsultarDatosResidenciales(),
            "Se requiere rol de administrador o vigilancia"
        );

        if (roleError != null) return roleError;

        try
        {
            var result = await _paqueteriaService.EntregarPaqueteAsync(id, dto, userId);
            return Ok(ProyectarPaqueteCaseta(result));
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
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> GetHistorico(
        [FromQuery] PaginationParams paginacion,
        [FromQuery] DateTimeOffset? desde = null,
        [FromQuery] DateTimeOffset? hasta = null,
        [FromQuery] int? viviendaId = null,
        [FromQuery] string? estado = null)
    {
        var (roleError, condominioId, _) = await ValidateRoleAsync(
            r => r.EsAdministrador(),
            "Se requiere rol de administrador"
        );

        if (roleError != null) return roleError;

        if (desde.HasValue && hasta.HasValue && desde.Value > hasta.Value)
        {
            return BadRequest(new { error = "La fecha 'desde' no puede ser posterior a la fecha 'hasta'." });
        }

        if (!string.IsNullOrEmpty(estado))
        {
            var validStates = new[] { 
                PaqueteEstados.Esperado, 
                PaqueteEstados.Recibido, 
                PaqueteEstados.Entregado, 
                PaqueteEstados.Cancelado, 
                PaqueteEstados.Vencido, 
                PaqueteEstados.Devuelto 
            };
            if (!validStates.Contains(estado.ToLowerInvariant()))
            {
                return BadRequest(new { error = "El estado proporcionado no es válido." });
            }
        }

        if (condominioId == null)
        {
            return Ok(PagedResult<object>.Create(new List<object>(), paginacion, 0));
        }

        var (items, totalCount) = await _paqueteriaService.GetPaquetesHistoricoAsync(
            condominioId.Value, desde, hasta, viviendaId, estado, paginacion);

        var resultList = items.Select(ProyectarPaqueteHistorico).ToList();

        return Ok(PagedResult<object>.Create(resultList, paginacion, totalCount));
    }

    [HttpPost("servicios")]
    [ProducesResponseType(StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> CreateServicio([FromBody] CreateServicioPaqueteriaRequestDto dto)
    {
        if (!ModelState.IsValid) return BadRequest(ModelState);

        var (roleError, condominioId, userId) = await ValidateRoleAsync(
            r => r.EsAdministrador(),
            "Se requiere rol de administrador"
        );

        if (roleError != null) return roleError;

        if (condominioId == null)
        {
            return BadRequest(new { error = "El usuario no pertenece a un condominio para crear un servicio." });
        }

        try
        {
            var result = await _paqueteriaService.CreateServicioPaqueteriaAsync(condominioId.Value, dto, userId);
            return StatusCode(201, ProyectarServicio(result));
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }

    [HttpDelete("servicios/{id:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> DeleteServicio(int id)
    {
        var (roleError, _, userId) = await ValidateRoleAsync(
            r => r.EsAdministrador(),
            "Se requiere rol de administrador"
        );

        if (roleError != null) return roleError;

        try
        {
            var success = await _paqueteriaService.DeleteServicioPaqueteriaAsync(id, userId);
            if (!success)
            {
                return NotFound(new { error = "Servicio no encontrado o no se pudo desactivar." });
            }

            return NoContent();
        }
        catch (SupabaseRpcException ex)
        {
            var (status, mensaje) = RpcErrorMapper.Map(ex);
            return StatusCode(status, new { error = mensaje });
        }
    }
}
