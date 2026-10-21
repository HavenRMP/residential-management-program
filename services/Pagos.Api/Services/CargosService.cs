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
}
