using System.Text.Json;
using Microsoft.Extensions.Options;
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
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly ILogger<PagosService> _logger;
    private readonly IComprobanteStorageService? _comprobanteStorageService;
    private readonly StorageOptions _storageOptions;
    private readonly TimeProvider _timeProvider;

    private static readonly TimeZoneInfo MexicoCityTimeZone = ObtenerZonaHorariaMexico();

    public PagosService(
        ISupabaseRestClient supabaseClient,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        ILogger<PagosService> logger,
        IComprobanteStorageService? comprobanteStorageService = null,
        IOptions<StorageOptions>? storageOptions = null,
        TimeProvider? timeProvider = null)
    {
        _supabaseClient = supabaseClient;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
        _logger = logger;
        _comprobanteStorageService = comprobanteStorageService;
        _storageOptions = storageOptions?.Value ?? new StorageOptions();
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

    public async Task<PagoResponse> ReportarPagoInquilinoAsync(ReportarPagoRequest request)
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

        // 4. Validación de referencia y banco de origen (obligatorios para Transferencia y Deposito)
        if (request.Metodo is MetodoPago.Transferencia or MetodoPago.Deposito)
        {
            if (string.IsNullOrWhiteSpace(request.Referencia))
            {
                throw new ArgumentException($"La referencia es obligatoria para pagos con método {request.Metodo}.", nameof(request.Referencia));
            }

            if (string.IsNullOrWhiteSpace(request.BancoOrigen))
            {
                throw new ArgumentException($"El banco de origen es obligatorio para pagos con método {request.Metodo}.", nameof(request.BancoOrigen));
            }
        }

        var referencia = string.IsNullOrWhiteSpace(request.Referencia) ? null : request.Referencia.Trim();
        var bancoOrigen = string.IsNullOrWhiteSpace(request.BancoOrigen) ? null : request.BancoOrigen.Trim();

        // 5. Validación de comprobante OBLIGATORIO (ruta + hash)
        var ruta = request.ObtenerComprobanteRuta()?.Trim();
        var hash = request.ObtenerComprobanteHash()?.Trim();

        if (string.IsNullOrWhiteSpace(ruta) || string.IsNullOrWhiteSpace(hash))
        {
            throw new ArgumentException("El comprobante (ruta y hash) es obligatorio.");
        }

        ComprobanteRutaHelper.ValidarRuta(ruta);

        if (hash.Length != 64 || !hash.All(Uri.IsHexDigit))
        {
            throw new ArgumentException("El hash del comprobante debe ser un valor hexadecimal de 64 caracteres.");
        }

        // 6. Leer cargo de vw_cargos y verificar que la vivienda pertenezca al usuario titular (P6 método 3)
        var condominioId = _userContextService.CondominioId;
        var cargo = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>(
            "vw_cargos",
            $"id=eq.{request.CargoId}");

        if (cargo == null || cargo.CondominioId != condominioId)
        {
            _logger.LogWarning("Cargo {CargoId} no encontrado o no pertenece al condominio {CondominioId}", request.CargoId, condominioId);
            throw new KeyNotFoundException("Cargo no encontrado.");
        }

        var esTitular = await _viviendasLookupService.EsResidenteTitularAsync(cargo.ViviendaId, _userContextService.UserId);
        if (!esTitular)
        {
            _logger.LogWarning("Inquilino {UserId} no es residente titular de la vivienda {ViviendaId} del cargo {CargoId}", _userContextService.UserId, cargo.ViviendaId, request.CargoId);
            throw new KeyNotFoundException("Cargo no encontrado.");
        }

        // 7. Validar que la ruta del comprobante corresponda a la vivienda y condominio del cargo (segmentos de la ruta)
        var segmentos = ruta.TrimStart('/').Split('/', StringSplitOptions.RemoveEmptyEntries);
        if (segmentos.Length < 2)
        {
            throw new ArgumentException("La ruta del comprobante no tiene los segmentos requeridos.");
        }

        if (!Guid.TryParse(segmentos[0], out var rutaCondominioId) || rutaCondominioId != cargo.CondominioId)
        {
            throw new ArgumentException("La ruta del comprobante no corresponde al condominio del cargo.");
        }

        if (!int.TryParse(segmentos[1], out var rutaViviendaId) || rutaViviendaId != cargo.ViviendaId)
        {
            throw new ArgumentException("La ruta del comprobante no corresponde a la vivienda del cargo.");
        }

        // 8. Validaciones de estado del cargo: Cancelado => 409, Pagado => 409
        if (cargo.Estado == EstadoCargo.Cancelado)
        {
            throw new PostgrestException(409, "PG001", "El cargo está cancelado o el estado no permite la operación");
        }

        if (cargo.Estado == EstadoCargo.Pagado)
        {
            throw new PostgrestException(409, "PG010", "El cargo ya está pagado");
        }

        // 9. Llamar a rpc_registrar_pago con p_origen = Inquilino, p_estado = PendienteConfirmacion
        var payload = new Dictionary<string, object?>
        {
            { "p_cargo_id", request.CargoId },
            { "p_monto", request.Monto },
            { "p_fecha_pago", request.FechaPago.ToString("yyyy-MM-dd") },
            { "p_metodo", request.Metodo.ToString() },
            { "p_origen", OrigenPago.Inquilino.ToString() },
            { "p_estado", EstadoPago.PendienteConfirmacion.ToString() },
            { "p_referencia", referencia },
            { "p_banco_origen", bancoOrigen },
            { "p_comprobante_ruta", ruta },
            { "p_comprobante_hash", hash.ToLowerInvariant() },
            { "p_actor_id", _userContextService.UserId }
        };

        var rpcResult = await _supabaseClient.RpcAsync<JsonElement>(
            "rpc_registrar_pago",
            payload,
            actorId: _userContextService.UserId);

        // 10. Responde 201 con el pago (PagoResponse)
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
            throw new InvalidOperationException("No se pudo obtener la información del pago reportado.");
        }

        return pagoResponse;
    }

    public async Task<ConfirmarPagoResponse> ConfirmarPagoAdminAsync(Guid id)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("El id del pago es obligatorio.", nameof(id));
        }

        // 1. Solo Admin. Primero lee el pago de vw_pagos por id y verifica que sea de su condominio; si no => 404.
        var condominioId = _userContextService.CondominioId;
        var pagoActual = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>(
            "vw_pagos",
            $"id=eq.{id}");

        if (pagoActual == null || pagoActual.CondominioId != condominioId)
        {
            _logger.LogWarning("Pago {PagoId} no encontrado o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException("Pago no encontrado.");
        }

        // 2. Llama a rpc_confirmar_pago(p_pago_id, p_actor_id).
        var payload = new Dictionary<string, object?>
        {
            { "p_pago_id", id },
            { "p_actor_id", _userContextService.UserId }
        };

        var rpcResult = await _supabaseClient.RpcAsync<JsonElement>(
            "rpc_confirmar_pago",
            payload,
            actorId: _userContextService.UserId);

        // 3. Responde 200 con { pago, cargo, movimiento_saldo (o null), saldo_a_favor }
        PagoResponse? pagoResponse = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("pago", out var pagoElem) && pagoElem.ValueKind == JsonValueKind.Object)
        {
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

        if (pagoResponse == null)
        {
            var vwPago = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{id}");
            if (vwPago != null)
            {
                pagoResponse = vwPago.ToResponse();
            }
        }

        if (pagoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del pago confirmado.");
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
            var vwCargo = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{pagoActual.CargoId}");
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
                _logger.LogWarning(ex, "No se pudo deserializar movimiento_saldo devuelto por rpc_confirmar_pago.");
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

        return new ConfirmarPagoResponse
        {
            Pago = pagoResponse,
            Cargo = cargoResponse,
            MovimientoSaldo = movimientoSaldo,
            SaldoAFavor = saldoAFavor
        };
    }

    public async Task<RechazarPagoResponse> RechazarPagoAdminAsync(Guid id, RechazarPagoRequest request)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("El id del pago es obligatorio.", nameof(id));
        }

        ArgumentNullException.ThrowIfNull(request);

        if (string.IsNullOrWhiteSpace(request.Motivo))
        {
            throw new ArgumentException("El motivo de rechazo es obligatorio.", nameof(request.Motivo));
        }

        var motivoLimpio = request.Motivo.Trim();
        if (motivoLimpio.Length < 5 || motivoLimpio.Length > 300)
        {
            throw new ArgumentException("El motivo debe tener entre 5 y 300 caracteres.", nameof(request.Motivo));
        }

        // 1. Solo Admin. Primero lee el pago de vw_pagos por id y verifica que sea de su condominio; si no => 404.
        var condominioId = _userContextService.CondominioId;
        var pagoActual = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>(
            "vw_pagos",
            $"id=eq.{id}");

        if (pagoActual == null || pagoActual.CondominioId != condominioId)
        {
            _logger.LogWarning("Pago {PagoId} no encontrado o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException("Pago no encontrado.");
        }

        // 2. Llama a rpc_rechazar_pago(p_pago_id, p_motivo, p_actor_id).
        var payload = new Dictionary<string, object?>
        {
            { "p_pago_id", id },
            { "p_motivo", motivoLimpio },
            { "p_actor_id", _userContextService.UserId }
        };

        var rpcResult = await _supabaseClient.RpcAsync<JsonElement>(
            "rpc_rechazar_pago",
            payload,
            actorId: _userContextService.UserId);

        // 3. Responde 200 con { pago }
        PagoResponse? pagoResponse = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("pago", out var pagoElem) && pagoElem.ValueKind == JsonValueKind.Object)
        {
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

        if (pagoResponse == null)
        {
            var vwPago = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{id}");
            if (vwPago != null)
            {
                pagoResponse = vwPago.ToResponse();
            }
        }

        if (pagoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del pago rechazado.");
        }

        return new RechazarPagoResponse
        {
            Pago = pagoResponse
        };
    }

    public async Task<AnularPagoResponse> AnularPagoAdminAsync(Guid id, AnularPagoRequest request)
    {
        if (id == Guid.Empty)
        {
            throw new ArgumentException("El id del pago es obligatorio.", nameof(id));
        }

        ArgumentNullException.ThrowIfNull(request);

        if (string.IsNullOrWhiteSpace(request.Motivo))
        {
            throw new ArgumentException("El motivo de anulación es obligatorio.", nameof(request.Motivo));
        }

        var motivoLimpio = request.Motivo.Trim();
        if (motivoLimpio.Length < 5 || motivoLimpio.Length > 300)
        {
            throw new ArgumentException("El motivo debe tener entre 5 y 300 caracteres.", nameof(request.Motivo));
        }

        // 1. Solo Admin. Primero lee el pago de vw_pagos por id y verifica que sea de su condominio; si no => 404.
        var condominioId = _userContextService.CondominioId;
        var pagoActual = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>(
            "vw_pagos",
            $"id=eq.{id}");

        if (pagoActual == null || pagoActual.CondominioId != condominioId)
        {
            _logger.LogWarning("Pago {PagoId} no encontrado o no pertenece al condominio {CondominioId}", id, condominioId);
            throw new KeyNotFoundException("Pago no encontrado.");
        }

        // No permitir anular un registro que sea una reversa (es_reversa verdadero) => 409
        if (pagoActual.EsReversa)
        {
            throw new PostgrestException(409, "PG009", "No se puede anular un registro que sea una reversa.");
        }

        // Pago no Confirmado => PG004 (409)
        if (pagoActual.Estado != EstadoPago.Confirmado)
        {
            throw new PostgrestException(409, "PG004", "Solo se pueden anular pagos confirmados");
        }

        // 2. Llama a rpc_anular_pago(p_pago_id, p_motivo, p_actor_id).
        var payload = new Dictionary<string, object?>
        {
            { "p_pago_id", id },
            { "p_motivo", motivoLimpio },
            { "p_actor_id", _userContextService.UserId }
        };

        JsonElement rpcResult;
        try
        {
            rpcResult = await _supabaseClient.RpcAsync<JsonElement>(
                "rpc_anular_pago",
                payload,
                actorId: _userContextService.UserId);
        }
        catch (PostgrestException ex) when (ex.Code == "PG007")
        {
            throw new PostgrestException(
                409,
                "PG007",
                "Saldo a favor insuficiente para revertir el abono del pago. Primero deben revertirse las aplicaciones de saldo hechas a otros cargos.");
        }

        // 3. Responde 200 con { pago_anulado, pago_reversa, cargo, movimiento_saldo (o null), saldo_a_favor }
        PagoResponse? pagoAnuladoResponse = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("pago_anulado", out var pagoAnuladoElem) && pagoAnuladoElem.ValueKind == JsonValueKind.Object)
        {
            try
            {
                var opt = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var vwPago = JsonSerializer.Deserialize<VwPago>(pagoAnuladoElem.GetRawText(), opt);
                if (vwPago != null && !string.IsNullOrEmpty(vwPago.NumeroCasa))
                {
                    pagoAnuladoResponse = vwPago.ToResponse();
                }
            }
            catch
            {
                // Releeremos de vw_pagos
            }
        }

        if (pagoAnuladoResponse == null)
        {
            var vwPago = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{id}");
            if (vwPago != null)
            {
                pagoAnuladoResponse = vwPago.ToResponse();
            }
        }

        if (pagoAnuladoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del pago anulado.");
        }

        // Pago reversa
        PagoResponse? pagoReversaResponse = null;
        Guid? reversaId = null;
        if (rpcResult.ValueKind == JsonValueKind.Object && rpcResult.TryGetProperty("pago_reversa", out var pagoReversaElem) && pagoReversaElem.ValueKind == JsonValueKind.Object)
        {
            if (pagoReversaElem.TryGetProperty("id", out var revIdProp))
            {
                if (revIdProp.ValueKind == JsonValueKind.String && Guid.TryParse(revIdProp.GetString(), out var idParsed))
                {
                    reversaId = idParsed;
                }
                else if (revIdProp.TryGetGuid(out var idGuid))
                {
                    reversaId = idGuid;
                }
            }

            try
            {
                var opt = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var vwPago = JsonSerializer.Deserialize<VwPago>(pagoReversaElem.GetRawText(), opt);
                if (vwPago != null && !string.IsNullOrEmpty(vwPago.NumeroCasa))
                {
                    pagoReversaResponse = vwPago.ToResponse();
                }
            }
            catch
            {
                // Releeremos de vw_pagos
            }
        }

        if (pagoReversaResponse == null && reversaId.HasValue)
        {
            var vwPagoRev = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{reversaId.Value}");
            if (vwPagoRev != null)
            {
                pagoReversaResponse = vwPagoRev.ToResponse();
            }
        }

        if (pagoReversaResponse == null)
        {
            var vwPagoRev = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"pago_original_id=eq.{id}&es_reversa=eq.true");
            if (vwPagoRev != null)
            {
                pagoReversaResponse = vwPagoRev.ToResponse();
            }
        }

        if (pagoReversaResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del pago de reversa.");
        }

        // Cargo
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
            var vwCargo = await _supabaseClient.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{pagoActual.CargoId}");
            if (vwCargo != null)
            {
                cargoResponse = vwCargo.ToResponse();
            }
        }

        if (cargoResponse == null)
        {
            throw new InvalidOperationException("No se pudo obtener la información del cargo actualizado tras anulación.");
        }

        // Movimiento saldo (o null)
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
                _logger.LogWarning(ex, "No se pudo deserializar movimiento_saldo devuelto por rpc_anular_pago.");
            }
        }

        // Saldo a favor
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

        return new AnularPagoResponse
        {
            PagoAnulado = pagoAnuladoResponse,
            PagoReversa = pagoReversaResponse,
            Cargo = cargoResponse,
            MovimientoSaldo = movimientoSaldo,
            SaldoAFavor = saldoAFavor
        };
    }

    public async Task<RespuestaPaginadaDto<PagoResponse>> ListarPagosAsync(ConsultaPagosFiltrosDto filtros)
    {
        ArgumentNullException.ThrowIfNull(filtros);

        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            throw new InvalidOperationException("El usuario no tiene un condominio asignado en su contexto.");
        }

        // Validación de rango de fechas de pago
        if (filtros.FechaPagoDesde.HasValue && filtros.FechaPagoHasta.HasValue && filtros.FechaPagoDesde > filtros.FechaPagoHasta)
        {
            throw new ArgumentException("La fecha de pago inicial (desde) no puede ser mayor que la final (hasta).", nameof(filtros.FechaPagoDesde));
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
                    // Regla 3: Si la lista de viviendas resulta vacía, responde página vacía sin consultar la vista.
                    return RespuestaPaginadaDto<PagoResponse>.CrearVacia(filtros);
                }

                if (filtros.ViviendaId.HasValue)
                {
                    if (!viviendasUsuario.Contains(filtros.ViviendaId.Value))
                    {
                        return RespuestaPaginadaDto<PagoResponse>.CrearVacia(filtros);
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
            // Regla 2: Inquilino: solo pagos de sus viviendas (P6, método 1 y filtro "in");
            // con usuario_id ajeno => 403; con vivienda_id ajena => 403.
            if (filtros.UsuarioId.HasValue && filtros.UsuarioId.Value != _userContextService.UserId)
            {
                throw new UnauthorizedAccessException("Los inquilinos no tienen permiso para consultar pagos de otros usuarios.");
            }

            var misViviendas = await _viviendasLookupService.GetViviendaIdsPorUsuarioTitularAsync(_userContextService.UserId);
            if (misViviendas == null || misViviendas.Count == 0)
            {
                // Regla 3: Si la lista de viviendas resulta vacía, responde página vacía sin consultar la vista.
                return RespuestaPaginadaDto<PagoResponse>.CrearVacia(filtros);
            }

            if (filtros.ViviendaId.HasValue)
            {
                if (!misViviendas.Contains(filtros.ViviendaId.Value))
                {
                    throw new UnauthorizedAccessException("No tienes permiso para consultar pagos de una vivienda que no te pertenece.");
                }
                viviendasAFiltar = new List<int> { filtros.ViviendaId.Value };
            }
            else
            {
                viviendasAFiltar = misViviendas;
            }
        }

        // Construcción de filtros PostgREST para vw_pagos
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

        if (filtros.CargoId.HasValue)
        {
            queryParams.Add($"cargo_id=eq.{filtros.CargoId.Value}");
        }

        if (filtros.Estado.HasValue)
        {
            queryParams.Add($"estado=eq.{filtros.Estado.Value}");
        }

        if (filtros.Metodo.HasValue)
        {
            queryParams.Add($"metodo=eq.{filtros.Metodo.Value}");
        }

        if (filtros.Origen.HasValue)
        {
            queryParams.Add($"origen=eq.{filtros.Origen.Value}");
        }

        if (filtros.EsReversa.HasValue)
        {
            queryParams.Add($"es_reversa=eq.{filtros.EsReversa.Value.ToString().ToLowerInvariant()}");
        }

        if (filtros.FechaPagoDesde.HasValue)
        {
            queryParams.Add($"fecha_pago=gte.{filtros.FechaPagoDesde.Value:yyyy-MM-dd}");
        }

        if (filtros.FechaPagoHasta.HasValue)
        {
            queryParams.Add($"fecha_pago=lte.{filtros.FechaPagoHasta.Value:yyyy-MM-dd}");
        }

        // Paginado, ordenado por fecha_pago descendente y luego creado_en descendente
        queryParams.Add("order=fecha_pago.desc,creado_en.desc");

        var queryString = string.Join("&", queryParams);

        var (items, totalCount) = await _supabaseClient.GetPagedAsync<VwPago>(
            "vw_pagos",
            filtros.ToSharedParams(),
            queryString);

        // Regla 5: Cada ítem usa PagoResponse. Sin comprobante_ruta ni comprobante_hash. Los registros de reversa se distinguen por es_reversa y pago_original_id.
        var responseItems = items.ToResponseList();
        var total = totalCount ?? responseItems.Count;

        return RespuestaPaginadaDto<PagoResponse>.Crear(responseItems, total, filtros);
    }

    /// <summary>
    /// Valida los permisos de acceso y obtiene el pago desde vw_pagos.
    /// Admin: solo pagos de su condominio. Inquilino: solo pagos de sus viviendas (P6, método 3).
    /// Si no corresponde o no existe => 404 (KeyNotFoundException).
    /// </summary>
    private async Task<VwPago> ValidarYObtenerPagoAsync(Guid id)
    {
        if (id == Guid.Empty)
        {
            throw new KeyNotFoundException("Pago no encontrado.");
        }

        var pago = await _supabaseClient.GetSingleOrDefaultAsync<VwPago>(
            "vw_pagos",
            $"id=eq.{id}");

        if (pago == null)
        {
            _logger.LogWarning("Pago {PagoId} no encontrado en vw_pagos.", id);
            throw new KeyNotFoundException("Pago no encontrado.");
        }

        var condominioId = _userContextService.CondominioId;

        if (_userContextService.EsAdmin)
        {
            if (pago.CondominioId != condominioId)
            {
                _logger.LogWarning("Admin {UserId} intentó acceder al pago {PagoId} perteneciente al condominio {PagoCondominioId} (condominio actual {CondominioId}).",
                    _userContextService.UserId, id, pago.CondominioId, condominioId);
                throw new KeyNotFoundException("Pago no encontrado.");
            }
        }
        else
        {
            if (pago.CondominioId != condominioId)
            {
                _logger.LogWarning("Inquilino {UserId} intentó acceder al pago {PagoId} perteneciente al condominio {PagoCondominioId} (condominio actual {CondominioId}).",
                    _userContextService.UserId, id, pago.CondominioId, condominioId);
                throw new KeyNotFoundException("Pago no encontrado.");
            }

            var esTitular = await _viviendasLookupService.EsResidenteTitularAsync(pago.ViviendaId, _userContextService.UserId);
            if (!esTitular)
            {
                _logger.LogWarning("Inquilino {UserId} intentó acceder al pago {PagoId} de la vivienda {ViviendaId} sin ser residente titular.",
                    _userContextService.UserId, id, pago.ViviendaId);
                throw new KeyNotFoundException("Pago no encontrado.");
            }
        }

        return pago;
    }

    public async Task<PagoResponse> ObtenerPagoPorIdAsync(Guid id)
    {
        var pago = await ValidarYObtenerPagoAsync(id);
        return pago.ToResponse();
    }

    public async Task<ComprobanteUrlResponse> ObtenerComprobanteUrlAsync(Guid id, CancellationToken cancellationToken = default)
    {
        var pago = await ValidarYObtenerPagoAsync(id);

        // Regla 2: si el pago no tiene comprobante (tiene_comprobante falso) => 404
        if (!pago.TieneComprobante || string.IsNullOrWhiteSpace(pago.ComprobanteRuta))
        {
            _logger.LogWarning("El pago {PagoId} no cuenta con comprobante asociado.", id);
            throw new KeyNotFoundException("El pago no tiene comprobante asociado.");
        }

        if (_comprobanteStorageService == null)
        {
            throw new InvalidOperationException("El servicio de almacenamiento de comprobantes no está configurado.");
        }

        int expiracionSegundos = _storageOptions.UrlExpiracionSegundos;
        var ahoraUtc = _timeProvider.GetUtcNow();
        var expiraEn = ahoraUtc.AddSeconds(expiracionSegundos);

        string urlFirmada;
        try
        {
            urlFirmada = await _comprobanteStorageService.CrearUrlFirmadaAsync(
                pago.ComprobanteRuta,
                expiracionSegundos,
                cancellationToken);
        }
        catch (KeyNotFoundException)
        {
            // Regla 2: Si el objeto ya no existe en Storage => 404 con el mensaje "Comprobante depurado por política de retención".
            _logger.LogWarning("Comprobante del pago {PagoId} en ruta {Ruta} no existe en Storage (depurado por política de retención).", id, pago.ComprobanteRuta);
            throw new KeyNotFoundException("Comprobante depurado por política de retención");
        }

        // Regla 3: NUNCA loguear la URL firmada completa.
        _logger.LogInformation("URL firmada de comprobante generada exitosamente para el pago {PagoId}.", id);

        return new ComprobanteUrlResponse
        {
            Url = urlFirmada,
            ExpiraEn = expiraEn
        };
    }
}
