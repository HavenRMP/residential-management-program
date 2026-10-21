using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Models;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación del servicio de consulta de saldos consolidados por vivienda y por usuario.
/// </summary>
public class SaldosService : ISaldosService
{
    private readonly ISupabaseRestClient _supabaseClient;
    private readonly IUserContextService _userContextService;
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly ILogger<SaldosService> _logger;

    public SaldosService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        ILogger<SaldosService> logger)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
        _logger = logger;
    }

    public async Task<SaldoViviendaResponse> ObtenerSaldoPorViviendaAsync(int viviendaId)
    {
        if (viviendaId <= 0)
        {
            throw new ArgumentException("El identificador de vivienda debe ser mayor a cero.", nameof(viviendaId));
        }

        // 1. Regla 1: Validar pertenencia según rol
        if (_userContextService.EsAdmin)
        {
            var condominioId = _userContextService.CondominioId;
            if (condominioId == Guid.Empty)
            {
                throw new InvalidOperationException("El administrador no cuenta con un condominio asociado.");
            }

            var existeEnCondominio = await _viviendasLookupService.ExisteViviendaEnCondominioAsync(viviendaId, condominioId);
            if (!existeEnCondominio)
            {
                _logger.LogWarning("Admin intentó consultar vivienda {ViviendaId} que no pertenece a su condominio {CondominioId}", viviendaId, condominioId);
                throw new KeyNotFoundException($"Vivienda {viviendaId} no encontrada en el condominio.");
            }
        }
        else if (_userContextService.EsInquilino)
        {
            var userId = _userContextService.UserId;
            var esTitular = await _viviendasLookupService.EsResidenteTitularAsync(viviendaId, userId);
            if (!esTitular)
            {
                _logger.LogWarning("Inquilino {UserId} intentó consultar vivienda {ViviendaId} de la que no es residente titular", userId, viviendaId);
                throw new KeyNotFoundException($"Vivienda {viviendaId} no encontrada para el residente.");
            }
        }
        else
        {
            throw new UnauthorizedAccessException("El rol del usuario no tiene permisos para consultar saldos de viviendas.");
        }

        // 2. Consulta de la vista 'v_saldo_vivienda'
        var registro = await _supabaseClient.GetSingleOrDefaultAsync<VSaldoVivienda>(
            "v_saldo_vivienda",
            $"vivienda_id=eq.{viviendaId}");

        if (registro == null)
        {
            _logger.LogWarning("No se encontró registro en 'v_saldo_vivienda' para la vivienda {ViviendaId}", viviendaId);
            throw new KeyNotFoundException($"No se encontró información de saldo para la vivienda {viviendaId}.");
        }

        return registro.ToResponse();
    }

    public async Task<SaldoUsuarioResponse> ObtenerMiSaldoAsync()
    {
        var userId = _userContextService.UserId;
        if (userId == Guid.Empty)
        {
            throw new InvalidOperationException("No se pudo determinar la identidad del usuario actual.");
        }

        // 1. Regla 2: Resolver viviendas del usuario inquilino (P6 Método 1)
        var viviendaIds = await _viviendasLookupService.GetViviendaIdsPorUsuarioTitularAsync(userId);

        // 2. Regla 3: Usuario sin viviendas => 200 con ceros y desglose vacío, sin consultar la vista
        if (viviendaIds == null || viviendaIds.Count == 0)
        {
            return SaldoUsuarioResponse.CrearVacio();
        }

        // 3. Regla 2: Consultar la vista con "in" sobre las viviendas
        var idsDistintos = viviendaIds.Distinct().ToList();
        var idsQuery = string.Join(",", idsDistintos);

        var registros = await _supabaseClient.GetAsync<VSaldoVivienda>(
            "v_saldo_vivienda",
            $"vivienda_id=in.({idsQuery})") ?? new List<VSaldoVivienda>();

        // 4. Sumar los totales en memoria sobre las pocas filas del usuario
        return ConsolidarSaldos(registros);
    }

    public async Task<SaldoUsuarioResponse> ObtenerSaldoPorUsuarioAsync(Guid usuarioId)
    {
        if (usuarioId == Guid.Empty)
        {
            throw new ArgumentException("El identificador de usuario es obligatorio.", nameof(usuarioId));
        }

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El administrador no cuenta con un condominio asociado.");
        }

        // 1. Regla 2: Resolver viviendas del usuario especificado (P6 Método 1)
        var viviendaIds = await _viviendasLookupService.GetViviendaIdsPorUsuarioTitularAsync(usuarioId);

        // 2. Regla 3: Usuario sin viviendas => 200 con ceros y desglose vacío, sin consultar la vista
        if (viviendaIds == null || viviendaIds.Count == 0)
        {
            return SaldoUsuarioResponse.CrearVacio();
        }

        // 3. Regla 3: Solo contar viviendas del condominio del admin (filtrar por condominio_id además del "in")
        var idsDistintos = viviendaIds.Distinct().ToList();
        var idsQuery = string.Join(",", idsDistintos);

        var registros = await _supabaseClient.GetAsync<VSaldoVivienda>(
            "v_saldo_vivienda",
            $"condominio_id=eq.{condominioId}&vivienda_id=in.({idsQuery})") ?? new List<VSaldoVivienda>();

        return ConsolidarSaldos(registros);
    }

    private static SaldoUsuarioResponse ConsolidarSaldos(List<VSaldoVivienda> registros)
    {
        if (registros.Count == 0)
        {
            return SaldoUsuarioResponse.CrearVacio();
        }

        return new SaldoUsuarioResponse
        {
            TotalPendiente = registros.Sum(r => r.TotalPendiente),
            TotalVencido = registros.Sum(r => r.TotalVencido),
            TotalCargosAbiertos = registros.Sum(r => r.TotalCargosAbiertos),
            SaldoAFavor = registros.Sum(r => r.SaldoAFavor),
            Viviendas = registros.ToResponseList()
        };
    }
}
