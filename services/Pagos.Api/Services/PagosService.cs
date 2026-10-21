using System.Text.Json;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Utils;

namespace Pagos.Api.Services;

/// <summary>
/// Implementación del servicio de gestión de pagos residenciales.
/// </summary>
public class PagosService : IPagosService
{
    private readonly ISupabaseRestClient _supabaseClient;
    private readonly IUserContextService _userContextService;
    private readonly ILogger<PagosService> _logger;
    private readonly TimeProvider _timeProvider;

    private static readonly TimeZoneInfo MexicoCityTimeZone = ObtenerZonaHorariaMexico();

    public PagosService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        ILogger<PagosService> logger,
        TimeProvider? timeProvider = null)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _logger = logger;
        _timeProvider = timeProvider ?? TimeProvider.System;
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

    public async Task<RegistrarPagoResponse> RegistrarPagoAdminAsync(RegistrarPagoAdminRequest request)
    {
        ArgumentNullException.ThrowIfNull(request);

        if (request.CargoId == Guid.Empty)
        {
            throw new ArgumentException("El id del cargo es obligatorio.", nameof(request.CargoId));
        }

        // 1. Validaciones de monto
        if (request.Monto <= 0)
        {
            throw new ArgumentException("El monto debe ser mayor a cero.", nameof(request.Monto));
        }

        if (decimal.Round(request.Monto, 2) != request.Monto)
        {
            throw new ArgumentException("El monto no puede tener más de dos decimales.", nameof(request.Monto));
        }

        // 2. Validaciones de fecha de pago (no futura en America/Mexico_City)
        if (request.FechaPago == default)
        {
            throw new ArgumentException("La fecha de pago es obligatoria.", nameof(request.FechaPago));
        }

        var ahoraUtc = _timeProvider.GetUtcNow();
        var ahoraMexico = TimeZoneInfo.ConvertTime(ahoraUtc, MexicoCityTimeZone);
        var hoyMexico = DateOnly.FromDateTime(ahoraMexico.DateTime);

        if (request.FechaPago > hoyMexico)
        {
            throw new ArgumentException("La fecha de pago no puede ser futura.", nameof(request.FechaPago));
        }

        // 3. Validación de método de pago
        if (!Enum.IsDefined(typeof(MetodoPago), request.Metodo))
        {
            throw new ArgumentException("El método de pago especificado no es válido.", nameof(request.Metodo));
        }

        // 4. Validación de referencia obligatoria para Transferencia y Deposito
        if (request.Metodo is MetodoPago.Transferencia or MetodoPago.Deposito)
        {
            if (string.IsNullOrWhiteSpace(request.Referencia))
            {
                throw new ArgumentException($"La referencia es obligatoria para pagos con método {request.Metodo}.", nameof(request.Referencia));
            }
        }

        var referencia = string.IsNullOrWhiteSpace(request.Referencia) ? null : request.Referencia.Trim();
        var bancoOrigen = string.IsNullOrWhiteSpace(request.BancoOrigen) ? null : request.BancoOrigen.Trim();

        var condominioId = _userContextService.CondominioId;

        // 5. Validación de comprobante si viene especificado
        var ruta = request.ObtenerComprobanteRuta()?.Trim();
        var hash = request.ObtenerComprobanteHash()?.Trim();

        string? comprobanteRutaFinal = null;
        string? comprobanteHashFinal = null;

        bool tieneRuta = !string.IsNullOrWhiteSpace(ruta);
        bool tieneHash = !string.IsNullOrWhiteSpace(hash);

        if (tieneRuta || tieneHash)
        {
            if (!tieneRuta || !tieneHash)
            {
                throw new ArgumentException("Si se envía comprobante, tanto la ruta como el hash son obligatorios.");
            }

            ComprobanteRutaHelper.ValidarRuta(ruta!);

            var segmentos = ruta!.TrimStart('/').Split('/', StringSplitOptions.RemoveEmptyEntries);
            if (segmentos.Length == 0 || !Guid.TryParse(segmentos[0], out var rutaCondominioId) || rutaCondominioId != condominioId)
            {
                throw new ArgumentException("El comprobante no pertenece al condominio del administrador.");
            }

            if (hash!.Length != 64 || !hash.All(Uri.IsHexDigit))
            {
                throw new ArgumentException("El hash del comprobante debe ser un valor hexadecimal de 64 caracteres.");
            }

            comprobanteRutaFinal = ruta;
            comprobanteHashFinal = hash.ToLowerInvariant();
        }

        // 6. Verificar que el cargo existe en vw_cargos y pertenece al condominio del admin
        var cargoActual = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>(
            "vw_cargos",
            $"id=eq.{request.CargoId}");

        if (cargoActual == null || cargoActual.CondominioId != condominioId)
        {
            _logger.LogWarning("Cargo {CargoId} no encontrado o no pertenece al condominio {CondominioId}", request.CargoId, condominioId);
            throw new KeyNotFoundException("Cargo no encontrado.");
        }

        // 7. Llamar a la RPC rpc_registrar_pago
        var payload = new Dictionary<string, object?>
        {
            { "p_cargo_id", request.CargoId },
            { "p_monto", request.Monto },
            { "p_fecha_pago", request.FechaPago.ToString("yyyy-MM-dd") },
            { "p_metodo", request.Metodo.ToString() },
            { "p_origen", OrigenPago.Admin.ToString() },
            { "p_estado", EstadoPago.Confirmado.ToString() },
            { "p_referencia", referencia },
            { "p_banco_origen", bancoOrigen },
            { "p_comprobante_ruta", comprobanteRutaFinal },
            { "p_comprobante_hash", comprobanteHashFinal },
            { "p_actor_id", _userContextService.UserId }
        };

        var rpcResult = await _supabaseClient.RpcAsync<JsonElement>(
            "rpc_registrar_pago",
            payload,
            actorId: _userContextService.UserId);

        // 8. Procesar respuesta: pago, cargo, movimiento_saldo y saldo_a_favor
        PagoResponse? pagoResponse = null;
        Guid? pagoId = null;

        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("pago", out var pagoElem) && pagoElem.ValueKind == JsonValueKind.Object)
        {
            if (pagoElem.TryGetProperty("id", out var idProp))
            {
                if (idProp.ValueKind == JsonValueKind.String && Guid.TryParse(idProp.GetString(), out var idParsed))
                {
                    pagoId = idParsed;
                }
                else if (idProp.TryGetGuid(out var idGuid))
                {
                    pagoId = idGuid;
                }
            }

            try
            {
                var opt = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var vwPago = JsonSerializer.Deserialize<VwPago>(pagoElem.GetRawText(), opt);
                if (vwPago != null && !string.IsNullOrEmpty(vwPago.NumeroCasa))
                {
                    pagoResponse = vwPago.ToResponse();
                }
            }
            catch
            {
                // Releeremos de vw_pagos
            }
        }

        if (pagoResponse == null && pagoId.HasValue)
        {
            var vwPago = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId.Value}");
            if (vwPago != null)
            {
                pagoResponse = vwPago.ToResponse();
            }
        }

        if (pagoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del pago registrado.");
        }

        CargoResponse? cargoResponse = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("cargo", out var cargoElem) && cargoElem.ValueKind == JsonValueKind.Object)
        {
            try
            {
                var opt = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var vwCargo = JsonSerializer.Deserialize<VwCargo>(cargoElem.GetRawText(), opt);
                if (vwCargo != null && !string.IsNullOrEmpty(vwCargo.NumeroCasa))
                {
                    cargoResponse = vwCargo.ToResponse();
                }
            }
            catch
            {
                // Releeremos de vw_cargos
            }
        }

        if (cargoResponse == null)
        {
            var vwCargo = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{request.CargoId}");
            if (vwCargo != null)
            {
                cargoResponse = vwCargo.ToResponse();
            }
        }

        if (cargoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del cargo actualizado.");
        }

        MovimientoSaldoResponse? movimientoSaldo = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && 
            rpcResult.TryGetProperty("movimiento_saldo", out var movElem) && 
            movElem.ValueKind == JsonValueKind.Object)
        {
            try
            {
                var opt = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                movimientoSaldo = JsonSerializer.Deserialize<MovimientoSaldoResponse>(movElem.GetRawText(), opt);
            }
            catch (Exception ex)
            {
                _logger.LogWarning(ex, "No se pudo deserializar movimiento_saldo devuelto por rpc_registrar_pago.");
            }
        }

        decimal saldoAFavor = 0m;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("saldo_a_favor", out var saldoElem))
        {
            if (saldoElem.ValueKind == JsonValueKind.Number)
            {
                saldoAFavor = saldoElem.GetDecimal();
            }
            else if (decimal.TryParse(saldoElem.GetString(), out var parsedSaldo))
            {
                saldoAFavor = parsedSaldo;
            }
        }

        return new RegistrarPagoResponse
        {
            Pago = pagoResponse,
            Cargo = cargoResponse,
            MovimientoSaldo = movimientoSaldo,
            SaldoAFavor = saldoAFavor
        };
    }
}
