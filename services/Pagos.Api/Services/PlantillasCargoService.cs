using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación del servicio de gestión de plantillas de cargo recurrente por vivienda.
/// </summary>
public class PlantillasCargoService : IPlantillasCargoService
{
    private readonly ISupabaseRestClient _supabaseClient;
    private readonly IUserContextService _userContextService;
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly ILogger<PlantillasCargoService> _logger;

    public PlantillasCargoService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        ILogger<PlantillasCargoService> logger)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
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
}
