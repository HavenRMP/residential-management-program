using System.Text.Json.Serialization;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Utils;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación del servicio de gestión de cargos residenciales.
/// </summary>
public class CargosService : ICargosService
{
    private readonly ISupabaseRestClient _supabaseClient;
    private readonly IUserContextService _userContextService;
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly ILogger<CargosService> _logger;

    public CargosService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        ILogger<CargosService> logger)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
        _logger = logger;
    }

    public async Task<CargoResponse> CrearCargoAsync(CrearCargoRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        // 1. Validaciones de campos
        if (request.ViviendaId <= 0)
        {
            throw new ArgumentException("El id de la vivienda es obligatorio y debe ser mayor a cero.", nameof(request.ViviendaId));
        }

        if (request.Monto <= 0)
        {
            throw new ArgumentException("El monto debe ser mayor a cero.", nameof(request.Monto));
        }

        if (decimal.Round(request.Monto, 2) != request.Monto)
        {
            throw new ArgumentException("El monto no puede tener más de dos decimales.", nameof(request.Monto));
        }

        if (string.IsNullOrWhiteSpace(request.Concepto))
        {
            throw new ArgumentException("El concepto es obligatorio.", nameof(request.Concepto));
        }

        var conceptoLimpio = request.Concepto.Trim();
        if (conceptoLimpio.Length > 200)
        {
            throw new ArgumentException("El concepto no puede exceder 200 caracteres.", nameof(request.Concepto));
        }

        if (!Enum.IsDefined(typeof(TipoCargo), request.Tipo))
        {
            throw new ArgumentException("El tipo de cargo especificado no es válido.", nameof(request.Tipo));
        }

        if (request.FechaVencimiento == default)
        {
            throw new ArgumentException("La fecha de vencimiento es obligatoria.", nameof(request.FechaVencimiento));
        }

        // Validación de periodo según tipo
        DateOnly? periodoFinal = null;
        if (request.Tipo is TipoCargo.Renta or TipoCargo.Mantenimiento)
        {
            if (string.IsNullOrWhiteSpace(request.Periodo))
            {
                throw new ArgumentException($"El periodo es obligatorio para cargos de tipo {request.Tipo}.", nameof(request.Periodo));
            }
        }

        if (!string.IsNullOrWhiteSpace(request.Periodo))
        {
            if (!PeriodoHelper.TryParse(request.Periodo, out var periodoParsed, out var errorPeriodo))
            {
                throw new ArgumentException(errorPeriodo, nameof(request.Periodo));
            }
            periodoFinal = periodoParsed;
        }

        // Validación de responsable de pago
        if (request.ResponsablePago.HasValue && !Enum.IsDefined(typeof(ResponsablePago), request.ResponsablePago.Value))
        {
            throw new ArgumentException("El responsable de pago especificado no es válido.", nameof(request.ResponsablePago));
        }

        // 2. Validación de pertenencia de vivienda al condominio del admin
        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El administrador no tiene un condominio asignado en su contexto.");
        }

        var existeVivienda = await _viviendasLookupService.ExisteViviendaEnCondominioAsync(request.ViviendaId, condominioId);
        if (!existeVivienda)
        {
            _logger.LogWarning(
                "La vivienda {ViviendaId} no existe en el condominio {CondominioId}", 
                request.ViviendaId, 
                condominioId);
            throw new KeyNotFoundException("Vivienda no encontrada.");
        }

        // 3. Preparación de inserción en tabla 'cargos'
        var cargoInsert = new CargoInsert
        {
            CondominioId = condominioId,
            ViviendaId = request.ViviendaId,
            PlantillaId = null,
            Tipo = request.Tipo,
            Concepto = conceptoLimpio,
            Monto = request.Monto,
            Periodo = periodoFinal,
            FechaVencimiento = request.FechaVencimiento,
            ResponsablePago = request.ResponsablePago,
            CreadoPor = _userContextService.UserId
        };

        // 4. Inserción directa en tabla 'cargos' con x-actor-id
        var insertado = await _supabaseClient.InsertSingleAsync<CargoIdResult>(
            "cargos", 
            cargoInsert, 
            actorId: _userContextService.UserId);

        // 5. Relectura de vista 'vw_cargos' por id para obtener campos calculados
        var cargoView = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>(
            "vw_cargos", 
            $"id=eq.{insertado.Id}");

        if (cargoView == null)
        {
            _logger.LogError("No se pudo re-leer el cargo recién creado con ID {CargoId} desde 'vw_cargos'", insertado.Id);
            throw new InvalidOperationException("No se pudo recuperar el cargo recién creado desde la vista 'vw_cargos'.");
        }

        return cargoView.ToResponse();
    }

    public async Task<RespuestaPaginadaDto<CargoResponse>> ListarCargosAsync(ConsultaCargosFiltrosDto filtros)
    {
        ArgumentNullException.ThrowIfNull(filtros);

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario no tiene un condominio asignado en su contexto.");
        }

        // Validación de rango de fechas de vencimiento
        if (filtros.VencimientoDesde.HasValue && filtros.VencimientoHasta.HasValue && filtros.VencimientoDesde > filtros.VencimientoHasta)
        {
            throw new ArgumentException("La fecha de vencimiento inicial (desde) no puede ser mayor que la final (hasta).", nameof(filtros.VencimientoDesde));
        }

        // Validación de periodo
        DateOnly? periodoDate = null;
        if (!string.IsNullOrWhiteSpace(filtros.Periodo))
        {
            if (!PeriodoHelper.TryParse(filtros.Periodo, out var parsed, out var errorPeriodo))
            {
                throw new ArgumentException(errorPeriodo, nameof(filtros.Periodo));
            }
            periodoDate = parsed;
        }

        var esAdmin = _userContextService.EsAdmin;
        List<int>? viviendasAFiltar = null;

        if (esAdmin)
        {
            // Regla 1: Admin siempre filtra por su condominio_id.
            // Si manda usuario_id, se resuelve con P6 (método 1) a una lista de viviendas y se filtra con "in".
            if (filtros.UsuarioId.HasValue)
            {
                var viviendasUsuario = await _viviendasLookupService.GetViviendaIdsPorUsuarioTitularAsync(filtros.UsuarioId.Value);
                if (viviendasUsuario == null || viviendasUsuario.Count == 0)
                {
                    // Regla 3: Si la lista de viviendas resulta vacía, responde página vacía sin consultar con un "in" vacío.
                    return RespuestaPaginadaDto<CargoResponse>.CrearVacia(filtros);
                }

                if (filtros.ViviendaId.HasValue)
                {
                    if (!viviendasUsuario.Contains(filtros.ViviendaId.Value))
                    {
                        return RespuestaPaginadaDto<CargoResponse>.CrearVacia(filtros);
                    }
                    viviendasAFiltar = new List<int> { filtros.ViviendaId.Value };
                }
                else
                {
                    viviendasAFiltar = viviendasUsuario;
                }
            }
            else if (filtros.ViviendaId.HasValue)
            {
                viviendasAFiltar = new List<int> { filtros.ViviendaId.Value };
            }
        }
        else
        {
            // Regla 2: Inquilino: se resuelven sus viviendas con P6 (método 1) y se filtra con "in"
            // (restringido además por vivienda_id si lo manda y es suya; si manda una que no es suya, 403).
            // Si manda usuario_id distinto al suyo, 403.
            if (filtros.UsuarioId.HasValue && filtros.UsuarioId.Value != _userContextService.UserId)
            {
                throw new UnauthorizedAccessException("Los inquilinos no tienen permiso para consultar cargos de otros usuarios.");
            }

            var misViviendas = await _viviendasLookupService.GetViviendaIdsPorUsuarioTitularAsync(_userContextService.UserId);
            if (misViviendas == null || misViviendas.Count == 0)
            {
                // Regla 3: Si la lista de viviendas resulta vacía, responde página vacía sin consultar con un "in" vacío.
                return RespuestaPaginadaDto<CargoResponse>.CrearVacia(filtros);
            }

            if (filtros.ViviendaId.HasValue)
            {
                if (!misViviendas.Contains(filtros.ViviendaId.Value))
                {
                    throw new UnauthorizedAccessException("No tienes permiso para consultar cargos de una vivienda que no te pertenece.");
                }
                viviendasAFiltar = new List<int> { filtros.ViviendaId.Value };
            }
            else
            {
                viviendasAFiltar = misViviendas;
            }
        }

        // Construcción de filtros PostgREST
        var queryParams = new List<string>
        {
            $"condominio_id=eq.{condominioId}"
        };

        if (viviendasAFiltar != null)
        {
            if (viviendasAFiltar.Count == 1)
            {
                queryParams.Add($"vivienda_id=eq.{viviendasAFiltar[0]}");
            }
            else
            {
                queryParams.Add($"vivienda_id=in.({string.Join(",", viviendasAFiltar)})");
            }
        }

        if (filtros.Tipo.HasValue)
        {
            queryParams.Add($"tipo=eq.{filtros.Tipo.Value}");
        }

        if (filtros.Estado.HasValue)
        {
            queryParams.Add($"estado=eq.{filtros.Estado.Value}");
        }

        // Regla 4: El filtro vencido se traduce al filtro esta_vencido de la vista. NO filtrar en memoria ni calcular fechas en C#.
        if (filtros.Vencido.HasValue)
        {
            queryParams.Add($"esta_vencido=eq.{filtros.Vencido.Value.ToString().ToLowerInvariant()}");
        }

        if (periodoDate.HasValue)
        {
            queryParams.Add($"periodo=eq.{periodoDate.Value:yyyy-MM-dd}");
        }

        if (filtros.VencimientoDesde.HasValue)
        {
            queryParams.Add($"fecha_vencimiento=gte.{filtros.VencimientoDesde.Value:yyyy-MM-dd}");
        }

        if (filtros.VencimientoHasta.HasValue)
        {
            queryParams.Add($"fecha_vencimiento=lte.{filtros.VencimientoHasta.Value:yyyy-MM-dd}");
        }

        // Paginado y ordenado por fecha de vencimiento descendente
        queryParams.Add("order=fecha_vencimiento.desc,id.desc");

        var queryString = string.Join("&", queryParams);

        var (items, totalCount) = await _supabaseClient.GetPagedAsync<VwCargo>(
            "vw_cargos",
            filtros.ToSharedParams(),
            queryString);

        // Regla 5: Cada ítem usa CargoResponse (con estado_efectivo)
        var responseItems = items.ToResponseList();
        var total = totalCount ?? responseItems.Count;

        return RespuestaPaginadaDto<CargoResponse>.Crear(responseItems, total, filtros);
    }
}
