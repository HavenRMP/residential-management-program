using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Utils;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación del servicio de gestión de plantillas de cargo recurrente por vivienda.
/// </summary>
public class PlantillasCargoService : IPlantillasCargoService
{
    private readonly ISupabaseRestClient _supabaseClient;
    private readonly IUserContextService _userContextService;
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly TimeProvider _timeProvider;
    private readonly IConfiguration _configuration;
    private readonly ILogger<PlantillasCargoService> _logger;

    public PlantillasCargoService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        TimeProvider timeProvider,
        IConfiguration configuration,
        ILogger<PlantillasCargoService> logger)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
        _timeProvider = timeProvider;
        _configuration = configuration;
        _logger = logger;
    }

    public async Task<List<PlantillaResponse>> CrearPlantillasMasivasAsync(CrearPlantillasCargoRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        // 1. Validaciones básicas de campos
        if (string.IsNullOrWhiteSpace(request.Concepto))
        {
            throw new ArgumentException("El concepto es obligatorio.", nameof(request.Concepto));
        }

        var conceptoLimpio = request.Concepto.Trim();
        if (conceptoLimpio.Length < 1 || conceptoLimpio.Length > 200)
        {
            throw new ArgumentException("El concepto debe tener entre 1 y 200 caracteres.", nameof(request.Concepto));
        }

        if (request.Monto <= 0)
        {
            throw new ArgumentException("El monto debe ser mayor a cero.", nameof(request.Monto));
        }

        if (decimal.Round(request.Monto, 2) != request.Monto)
        {
            throw new ArgumentException("El monto común no puede tener más de dos decimales.", nameof(request.Monto));
        }

        if (request.DiaVencimiento < 1 || request.DiaVencimiento > 31)
        {
            throw new ArgumentException("El día de vencimiento debe estar entre 1 y 31.", nameof(request.DiaVencimiento));
        }

        if (request.VigenciaInicio == default)
        {
            throw new ArgumentException("La fecha de inicio de vigencia es obligatoria.", nameof(request.VigenciaInicio));
        }

        if (request.VigenciaFin.HasValue && request.VigenciaFin.Value < request.VigenciaInicio)
        {
            throw new ArgumentException("La fecha de fin de vigencia no puede ser anterior a la fecha de inicio.", nameof(request.VigenciaFin));
        }

        if (!Enum.IsDefined(typeof(TipoCargo), request.Tipo))
        {
            throw new ArgumentException("El tipo de cargo especificado no es válido.", nameof(request.Tipo));
        }

        if (request.ResponsablePago.HasValue && !Enum.IsDefined(typeof(ResponsablePago), request.ResponsablePago.Value))
        {
            throw new ArgumentException("El responsable de pago especificado no es válido.", nameof(request.ResponsablePago));
        }

        if (request.Viviendas == null || request.Viviendas.Count < 1 || request.Viviendas.Count > 200)
        {
            throw new ArgumentException("La lista de viviendas debe contener entre 1 y 200 elementos.", nameof(request.Viviendas));
        }

        var viviendasIds = request.Viviendas.Select(v => v.ViviendaId).ToList();
        if (viviendasIds.Distinct().Count() != viviendasIds.Count)
        {
            throw new ArgumentException("La lista de viviendas contiene identificadores duplicados.", nameof(request.Viviendas));
        }

        foreach (var v in request.Viviendas)
        {
            if (v.ViviendaId <= 0)
            {
                throw new ArgumentException("El identificador de vivienda debe ser mayor a cero.", nameof(request.Viviendas));
            }

            if (v.Monto.HasValue)
            {
                if (v.Monto.Value <= 0)
                {
                    throw new ArgumentException($"El monto específico para la vivienda {v.ViviendaId} debe ser mayor a cero.", nameof(request.Viviendas));
                }

                if (decimal.Round(v.Monto.Value, 2) != v.Monto.Value)
                {
                    throw new ArgumentException($"El monto específico para la vivienda {v.ViviendaId} no puede tener más de dos decimales.", nameof(request.Viviendas));
                }
            }
        }

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        // 2. Todas las viviendas deben ser del condominio del admin (P6, método 2); si alguna no => 404 indicando cuáles, y no se crea nada.
        var viviendasNoEncontradas = new List<int>();
        foreach (var item in request.Viviendas)
        {
            var existe = await _viviendasLookupService.ExisteViviendaEnCondominioAsync(item.ViviendaId, condominioId);
            if (!existe)
            {
                viviendasNoEncontradas.Add(item.ViviendaId);
            }
        }

        if (viviendasNoEncontradas.Count > 0)
        {
            var idsNoValidos = string.Join(", ", viviendasNoEncontradas);
            _logger.LogWarning("Admin intentó crear plantillas para viviendas {Viviendas} que no pertenecen al condominio {CondominioId}", idsNoValidos, condominioId);
            throw new KeyNotFoundException($"Las siguientes viviendas no pertenecen al condominio o no existen: {idsNoValidos}.");
        }

        // 3. Antes de insertar, consulta vw_plantillas_cargo con "in" sobre esas viviendas, activa verdadera y mismo tipo y concepto.
        // Si hay coincidencias => 409 indicando cuáles viviendas, y no se crea nada.
        var listaIdsParaQuery = string.Join(",", viviendasIds);
        var queryExistentes = $"condominio_id=eq.{condominioId}&activa=eq.true&tipo=eq.{request.Tipo}&concepto=eq.{Uri.EscapeDataString(conceptoLimpio)}&vivienda_id=in.({listaIdsParaQuery})";
        var existentes = await _supabaseClient.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", queryExistentes);

        if (existentes != null && existentes.Count > 0)
        {
            var viviendasDuplicadas = existentes.Select(e => e.ViviendaId).Distinct().ToList();
            var idsDuplicados = string.Join(", ", viviendasDuplicadas);
            _logger.LogWarning("Ya existen plantillas activas con tipo {Tipo} y concepto '{Concepto}' para las viviendas {Viviendas}", request.Tipo, conceptoLimpio, idsDuplicados);
            throw new PostgrestException(
                409,
                "23505",
                $"Ya existen plantillas activas con el mismo tipo y concepto para las viviendas: {idsDuplicados}.",
                motivoConflicto: MotivoConflicto.PlantillaActivaDuplicada,
                constraintName: "idx_plantillas_vivienda_tipo_concepto_activa");
        }

        // 4. Preparar entidades para inserción masiva
        // condominio_id y creado_por del token. Header x-actor-id. Nacen activas (default de la base).
        var listaInserts = request.Viviendas.Select(v => new PlantillaCargoInsert
        {
            CondominioId = condominioId,
            ViviendaId = v.ViviendaId,
            Tipo = request.Tipo,
            Concepto = conceptoLimpio,
            Monto = v.Monto ?? request.Monto,
            DiaVencimiento = request.DiaVencimiento,
            VigenciaInicio = request.VigenciaInicio,
            VigenciaFin = request.VigenciaFin,
            ResponsablePago = request.ResponsablePago,
            Activa = true,
            CreadoPor = _userContextService.UserId
        }).ToList();

        List<PlantillaInsertResult>? insertados;
        try
        {
            insertados = await _supabaseClient.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                listaInserts,
                actorId: _userContextService.UserId);
        }
        catch (PostgrestException ex) when (ex.Code == "23505" || ex.StatusCode == 409)
        {
            _logger.LogWarning(ex, "Condición de carrera al insertar plantillas de cargo: violación de unicidad 23505.");
            throw new PostgrestException(
                409,
                "23505",
                "Ya existe una plantilla activa para una o más de las viviendas indicadas.",
                ex.Details,
                MotivoConflicto.PlantillaActivaDuplicada,
                ex.ConstraintName);
        }

        if (insertados == null || insertados.Count == 0)
        {
            throw new InvalidOperationException("No se pudieron insertar las plantillas de cargo.");
        }

        // 5. Relectura de 'vw_plantillas_cargo' por los ids insertados para obtener campos calculados (condominio_nombre, numero_casa, etc.)
        var idsInsertados = string.Join(",", insertados.Select(i => i.Id));
        var plantillasCreadas = await _supabaseClient.GetAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=in.({idsInsertados})&order=vivienda_id.asc");

        if (plantillasCreadas == null || plantillasCreadas.Count == 0)
        {
            _logger.LogWarning("No se pudieron re-leer las plantillas recién creadas con IDs {Ids} desde 'vw_plantillas_cargo'.", idsInsertados);
            throw new InvalidOperationException("No se pudieron recuperar las plantillas recién creadas desde la vista 'vw_plantillas_cargo'.");
        }

        return plantillasCreadas.ToResponseList();
    }

    public async Task<RespuestaPaginadaDto<PlantillaResponse>> ListarPlantillasAsync(ConsultaPlantillasCargoFiltrosDto filtros)
    {
        ArgumentNullException.ThrowIfNull(filtros);

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        var queryParams = new List<string>
        {
            $"condominio_id=eq.{condominioId}"
        };

        if (filtros.ViviendaId.HasValue)
        {
            queryParams.Add($"vivienda_id=eq.{filtros.ViviendaId.Value}");
        }

        if (filtros.Tipo.HasValue)
        {
            queryParams.Add($"tipo=eq.{filtros.Tipo.Value}");
        }

        if (filtros.Activa.HasValue)
        {
            queryParams.Add($"activa=eq.{filtros.Activa.Value.ToString().ToLowerInvariant()}");
        }

        queryParams.Add("order=vivienda_id.asc,creado_en.desc");

        var queryString = string.Join("&", queryParams);

        var (items, totalCount) = await _supabaseClient.GetPagedAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            filtros.ToSharedParams(),
            queryString);

        var responseItems = items.ToResponseList();
        var total = totalCount ?? responseItems.Count;

        return RespuestaPaginadaDto<PlantillaResponse>.Crear(responseItems, total, filtros);
    }

    public async Task<PlantillaResponse> ActualizarPlantillaAsync(Guid id, ActualizarPlantillaCargoRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        // 1. Validaciones de campos editables
        if (string.IsNullOrWhiteSpace(request.Concepto))
        {
            throw new ArgumentException("El concepto es obligatorio.", nameof(request.Concepto));
        }

        var conceptoLimpio = request.Concepto.Trim();
        if (conceptoLimpio.Length < 1 || conceptoLimpio.Length > 200)
        {
            throw new ArgumentException("El concepto debe tener entre 1 y 200 caracteres.", nameof(request.Concepto));
        }

        if (request.Monto <= 0)
        {
            throw new ArgumentException("El monto debe ser mayor a cero.", nameof(request.Monto));
        }

        if (decimal.Round(request.Monto, 2) != request.Monto)
        {
            throw new ArgumentException("El monto no puede tener más de dos decimales.", nameof(request.Monto));
        }

        if (request.DiaVencimiento < 1 || request.DiaVencimiento > 31)
        {
            throw new ArgumentException("El día de vencimiento debe estar entre 1 y 31.", nameof(request.DiaVencimiento));
        }

        if (request.ResponsablePago.HasValue && !Enum.IsDefined(typeof(ResponsablePago), request.ResponsablePago.Value))
        {
            throw new ArgumentException("El responsable de pago especificado no es válido.", nameof(request.ResponsablePago));
        }

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        // 2. Regla 1: Leer plantilla de vw_plantillas_cargo y verificar condominio
        var plantilla = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (plantilla == null || plantilla.CondominioId != condominioId)
        {
            _logger.LogWarning("Plantilla {Id} no encontrada o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException($"La plantilla de cargo con id {id} no fue encontrada.");
        }

        // Validación de vigencia_fin contra vigencia_inicio de la plantilla
        if (request.VigenciaFin.HasValue && request.VigenciaFin.Value < plantilla.VigenciaInicio)
        {
            throw new ArgumentException("La fecha de fin de vigencia no puede ser anterior a la fecha de inicio.", nameof(request.VigenciaFin));
        }

        // 3. Regla 4: Si la plantilla está activa y cambió el concepto, verificar anti-duplicado
        if (plantilla.Activa && !string.Equals(plantilla.Concepto, conceptoLimpio, StringComparison.OrdinalIgnoreCase))
        {
            var queryDuplicado = $"condominio_id=eq.{condominioId}&vivienda_id=eq.{plantilla.ViviendaId}&activa=eq.true&tipo=eq.{plantilla.Tipo}&concepto=eq.{Uri.EscapeDataString(conceptoLimpio)}&id=neq.{id}";
            var existentes = await _supabaseClient.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", queryDuplicado);
            if (existentes != null && existentes.Count > 0)
            {
                throw new PostgrestException(
                    StatusCodes.Status409Conflict,
                    "23505",
                    "Ya existe una plantilla activa del mismo tipo y concepto para esta vivienda.",
                    motivoConflicto: MotivoConflicto.PlantillaActivaDuplicada,
                    constraintName: "idx_plantillas_vivienda_tipo_concepto_activa");
            }
        }

        // 4. Regla 6: PATCH directo sobre plantillas_cargo con header x-actor-id, modificado_por y modificado_en
        var patchData = new
        {
            monto = request.Monto,
            dia_vencimiento = request.DiaVencimiento,
            vigencia_fin = request.VigenciaFin,
            responsable_pago = request.ResponsablePago,
            concepto = conceptoLimpio,
            modificado_por = _userContextService.UserId,
            modificado_en = _timeProvider.GetUtcNow()
        };

        try
        {
            await _supabaseClient.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                patchData,
                actorId: _userContextService.UserId);
        }
        catch (PostgrestException ex) when (ex.Code == "23505" || ex.StatusCode == 409)
        {
            _logger.LogWarning(ex, "Conflicto 23505 al actualizar plantilla de cargo {Id}", id);
            throw new PostgrestException(
                StatusCodes.Status409Conflict,
                "23505",
                "Ya existe una plantilla activa del mismo tipo y concepto para esta vivienda.",
                ex.Details,
                MotivoConflicto.PlantillaActivaDuplicada,
                ex.ConstraintName);
        }

        // 5. Relectura desde vw_plantillas_cargo
        var actualizada = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (actualizada == null)
        {
            throw new InvalidOperationException($"No se pudo recuperar la plantilla de cargo {id} actualizada.");
        }

        return actualizada.ToResponse();
    }

    public async Task<PlantillaResponse> DesactivarPlantillaAsync(Guid id)
    {
        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        // 1. Regla 1: Leer plantilla y verificar condominio
        var plantilla = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (plantilla == null || plantilla.CondominioId != condominioId)
        {
            _logger.LogWarning("Plantilla {Id} no encontrada o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException($"La plantilla de cargo con id {id} no fue encontrada.");
        }

        // 2. Regla 5: Desactivar una plantilla ya inactiva => 409
        if (!plantilla.Activa)
        {
            _logger.LogWarning("Intento de desactivar plantilla {Id} que ya se encuentra desactivada.", id);
            throw new PostgrestException(
                StatusCodes.Status409Conflict,
                "409",
                "La plantilla de cargo ya se encuentra desactivada.");
        }

        // 3. Regla 6: PATCH directo sobre plantillas_cargo con x-actor-id, modificado_por y modificado_en
        var patchData = new
        {
            activa = false,
            modificado_por = _userContextService.UserId,
            modificado_en = _timeProvider.GetUtcNow()
        };

        await _supabaseClient.PatchAsync<PlantillaInsertResult>(
            "plantillas_cargo",
            $"id=eq.{id}",
            patchData,
            actorId: _userContextService.UserId);

        // 4. Relectura de vw_plantillas_cargo
        var actualizada = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (actualizada == null)
        {
            throw new InvalidOperationException($"No se pudo recuperar la plantilla de cargo {id} desactivada.");
        }

        return actualizada.ToResponse();
    }

    public async Task<PlantillaResponse> ActivarPlantillaAsync(Guid id)
    {
        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        // 1. Regla 1: Leer plantilla y verificar condominio
        var plantilla = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (plantilla == null || plantilla.CondominioId != condominioId)
        {
            _logger.LogWarning("Plantilla {Id} no encontrada o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException($"La plantilla de cargo con id {id} no fue encontrada.");
        }

        // 2. Regla 5: Activar una plantilla ya activa => 409
        if (plantilla.Activa)
        {
            _logger.LogWarning("Intento de activar plantilla {Id} que ya se encuentra activa.", id);
            throw new PostgrestException(
                StatusCodes.Status409Conflict,
                "409",
                "La plantilla de cargo ya se encuentra activa.");
        }

        // 3. Regla 4: Reactivar no debe chocar con otra plantilla activa del mismo tipo, concepto y vivienda
        var queryDuplicado = $"condominio_id=eq.{condominioId}&vivienda_id=eq.{plantilla.ViviendaId}&activa=eq.true&tipo=eq.{plantilla.Tipo}&concepto=eq.{Uri.EscapeDataString(plantilla.Concepto)}&id=neq.{id}";
        var existentes = await _supabaseClient.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", queryDuplicado);
        if (existentes != null && existentes.Count > 0)
        {
            throw new PostgrestException(
                StatusCodes.Status409Conflict,
                "23505",
                "Ya existe una plantilla activa del mismo tipo y concepto para esta vivienda.",
                motivoConflicto: MotivoConflicto.PlantillaActivaDuplicada,
                constraintName: "idx_plantillas_vivienda_tipo_concepto_activa");
        }

        // 4. Regla 6: PATCH directo sobre plantillas_cargo con x-actor-id, modificado_por y modificado_en
        var patchData = new
        {
            activa = true,
            modificado_por = _userContextService.UserId,
            modificado_en = _timeProvider.GetUtcNow()
        };

        try
        {
            await _supabaseClient.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                patchData,
                actorId: _userContextService.UserId);
        }
        catch (PostgrestException ex) when (ex.Code == "23505" || ex.StatusCode == 409)
        {
            _logger.LogWarning(ex, "Conflicto 23505 al activar plantilla de cargo {Id}", id);
            throw new PostgrestException(
                StatusCodes.Status409Conflict,
                "23505",
                "Ya existe una plantilla activa del mismo tipo y concepto para esta vivienda.",
                ex.Details,
                MotivoConflicto.PlantillaActivaDuplicada,
                ex.ConstraintName);
        }

        // 5. Relectura de vw_plantillas_cargo
        var actualizada = await _supabaseClient.GetSingleOrDefaultAsync<VwPlantillaCargo>(
            "vw_plantillas_cargo",
            $"id=eq.{id}");

        if (actualizada == null)
        {
            throw new InvalidOperationException($"No se pudo recuperar la plantilla de cargo {id} activada.");
        }

        return actualizada.ToResponse();
    }

    public async Task<GenerarCargosLoteResponse> GenerarCargosLoteAsync(GenerarCargosLoteRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        // 1. Validaciones de periodo
        if (string.IsNullOrWhiteSpace(request.Periodo))
        {
            throw new ArgumentException("El periodo es obligatorio.", nameof(request.Periodo));
        }

        if (!PeriodoHelper.TryParse(request.Periodo, out var periodoDate, out var errorPeriodo))
        {
            throw new ArgumentException(errorPeriodo, nameof(request.Periodo));
        }

        // Regla 5: Rechazar periodos con más de 3 meses de anticipación respecto a hoy en America/Mexico_City (límite configurable)
        var maxAnticipacion = _configuration.GetValue<int?>("Plantillas:MaxMesesAnticipacion") ?? 3;
        var tzMexico = ObtenerZonaHorariaMexico();
        var ahoraUtc = _timeProvider.GetUtcNow();
        var ahoraMexico = TimeZoneInfo.ConvertTimeFromUtc(ahoraUtc.UtcDateTime, tzMexico);
        var primerDiaMesHoy = new DateOnly(ahoraMexico.Year, ahoraMexico.Month, 1);
        var limiteFuturo = primerDiaMesHoy.AddMonths(maxAnticipacion);

        if (periodoDate > limiteFuturo)
        {
            throw new ArgumentException(
                $"El periodo {request.Periodo} excede el límite permitido de {maxAnticipacion} meses de anticipación respecto a la fecha actual.",
                nameof(request.Periodo));
        }

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario administrador no cuenta con un condominio asociado.");
        }

        // 2. Regla 1: Leer las plantillas candidatas de vw_plantillas_cargo
        List<VwPlantillaCargo> plantillasActivas;

        if (request.PlantillaIds != null && request.PlantillaIds.Count > 0)
        {
            var idsFiltro = request.PlantillaIds.Distinct().ToList();
            var idsQuery = string.Join(",", idsFiltro);

            // Regla 6: Si el filtro trae plantilla_ids que no son del condominio => 404
            var plantillasCondominio = await _supabaseClient.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"condominio_id=eq.{condominioId}&id=in.({idsQuery})");

            var encontradosIds = (plantillasCondominio ?? new List<VwPlantillaCargo>())
                .Select(p => p.Id)
                .ToHashSet();

            var idsFaltantes = idsFiltro.Where(id => !encontradosIds.Contains(id)).ToList();
            if (idsFaltantes.Count > 0)
            {
                var faltantesTexto = string.Join(", ", idsFaltantes);
                _logger.LogWarning("Plantillas {Ids} no encontradas en condominio {CondominioId}", faltantesTexto, condominioId);
                throw new KeyNotFoundException($"Las siguientes plantillas no pertenecen al condominio o no existen: {faltantesTexto}.");
            }

            plantillasActivas = plantillasCondominio!.Where(p => p.Activa).ToList();
        }
        else
        {
            var todasActivas = await _supabaseClient.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"condominio_id=eq.{condominioId}&activa=eq.true");

            plantillasActivas = todasActivas ?? new List<VwPlantillaCargo>();
        }

        // 3. Evaluar vigencia para el periodo
        // Solo se consideran las cuya vigencia cubra el periodo (vigencia_inicio <= último día del periodo y vigencia_fin nula o >= primer día del periodo)
        var anio = periodoDate.Year;
        var mes = periodoDate.Month;
        var primerDiaPeriodo = new DateOnly(anio, mes, 1);
        var diasEnMes = DateTime.DaysInMonth(anio, mes);
        var ultimoDiaPeriodo = new DateOnly(anio, mes, diasEnMes);

        var candidatasVigentes = new List<VwPlantillaCargo>();
        var omitidasPorVigencia = 0;

        foreach (var p in plantillasActivas)
        {
            var cubrePeriodo = p.VigenciaInicio <= ultimoDiaPeriodo &&
                               (!p.VigenciaFin.HasValue || p.VigenciaFin.Value >= primerDiaPeriodo);

            if (cubrePeriodo)
            {
                candidatasVigentes.Add(p);
            }
            else
            {
                omitidasPorVigencia++;
            }
        }

        // Regla 7: Si no hay ninguna candidata vigente, responde 200 con todos los conteos en cero y sin llamar al insert.
        if (candidatasVigentes.Count == 0)
        {
            return new GenerarCargosLoteResponse
            {
                Creados = 0,
                OmitidosPorYaExistir = 0,
                OmitidosPorVigencia = omitidasPorVigencia,
                Cargos = new List<CargoCreadoItemResponse>()
            };
        }

        // 4. Reglas 2 y 3: Construcción de cargos a insertar
        var cargosParaInsertar = candidatasVigentes.Select(p =>
        {
            var dia = Math.Min(p.DiaVencimiento, diasEnMes);
            var fechaVencimiento = new DateOnly(anio, mes, dia);

            return new CargoInsert
            {
                CondominioId = p.CondominioId,
                ViviendaId = p.ViviendaId,
                PlantillaId = p.Id,
                Tipo = p.Tipo,
                Concepto = p.Concepto,
                Monto = p.Monto,
                Periodo = primerDiaPeriodo,
                FechaVencimiento = fechaVencimiento,
                ResponsablePago = p.ResponsablePago,
                CreadoPor = _userContextService.UserId
            };
        }).ToList();

        // 5. Regla 4: Idempotencia con una sola inserción masiva on_conflict plantilla_id,periodo e ignorar duplicados
        var insertados = await _supabaseClient.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
            "cargos",
            cargosParaInsertar,
            "plantilla_id,periodo",
            actorId: _userContextService.UserId);

        var creadosCount = insertados.Count;
        var omitidosPorYaExistir = candidatasVigentes.Count - creadosCount;

        return new GenerarCargosLoteResponse
        {
            Creados = creadosCount,
            OmitidosPorYaExistir = omitidosPorYaExistir,
            OmitidosPorVigencia = omitidasPorVigencia,
            Cargos = insertados
        };
    }

    private static TimeZoneInfo ObtenerZonaHorariaMexico()
    {
        try
        {
            return TimeZoneInfo.FindSystemTimeZoneById("America/Mexico_City");
        }
        catch
        {
            try
            {
                return TimeZoneInfo.FindSystemTimeZoneById("Central Standard Time (Mexico)");
            }
            catch
            {
                return TimeZoneInfo.Local;
            }
        }
    }
}
