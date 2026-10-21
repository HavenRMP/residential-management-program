using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class RegistroYReportePagosTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public RegistroYReportePagosTests(PagosApiFactory factory)
    {
        _factory = factory;
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

    private static DateOnly ObtenerHoyMexico()
    {
        var tz = ObtenerZonaHorariaMexico();
        return DateOnly.FromDateTime(TimeZoneInfo.ConvertTime(DateTimeOffset.UtcNow, tz).DateTime);
    }

    private static JsonElement CrearRpcRegistrarPagoResult(
        Guid pagoId,
        Guid cargoId,
        Guid condominioId,
        int viviendaId,
        decimal monto,
        MetodoPago metodo,
        EstadoPago estado,
        OrigenPago origen,
        bool incluirMovimientoSaldo = false,
        decimal saldoAFavor = 0m)
    {
        var pagoDict = new Dictionary<string, object?>
        {
            ["id"] = pagoId,
            ["cargo_id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["cargo_tipo"] = TipoCargo.Mantenimiento.ToString(),
            ["cargo_concepto"] = "Cuota mensual",
            ["monto"] = monto,
            ["monto_cubierto"] = monto,
            ["monto_excedente"] = 0m,
            ["fecha_pago"] = ObtenerHoyMexico().ToString("yyyy-MM-dd"),
            ["metodo"] = metodo.ToString(),
            ["estado"] = estado.ToString(),
            ["origen"] = origen.ToString(),
            ["tiene_comprobante"] = false,
            ["es_reversa"] = false,
            ["registrado_por"] = Guid.NewGuid(),
            ["creado_en"] = DateTimeOffset.UtcNow
        };

        var cargoDict = new Dictionary<string, object?>
        {
            ["id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["tipo"] = TipoCargo.Mantenimiento.ToString(),
            ["concepto"] = "Cuota mensual",
            ["monto"] = 1000m,
            ["monto_pagado_confirmado"] = monto,
            ["saldo_pendiente"] = Math.Max(0, 1000m - monto),
            ["estado"] = estado == EstadoPago.Confirmado ? EstadoCargo.Pagado.ToString() : EstadoCargo.Pendiente.ToString(),
            ["fecha_vencimiento"] = "2026-11-30",
            ["creado_por"] = Guid.NewGuid(),
            ["creado_en"] = DateTimeOffset.UtcNow
        };

        var root = new Dictionary<string, object?>
        {
            ["pago"] = pagoDict,
            ["cargo"] = cargoDict,
            ["saldo_a_favor"] = saldoAFavor
        };

        if (incluirMovimientoSaldo)
        {
            root["movimiento_saldo"] = new Dictionary<string, object?>
            {
                ["id"] = Guid.NewGuid(),
                ["condominio_id"] = condominioId,
                ["vivienda_id"] = viviendaId,
                ["monto"] = saldoAFavor,
                ["tipo"] = TipoMovimientoSaldo.Abono.ToString(),
                ["saldo_resultante"] = saldoAFavor,
                ["fecha"] = DateTimeOffset.UtcNow
            };
        }

        var json = JsonSerializer.Serialize(root);
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    #region Registro por Admin (Casos 1 al 11)

    /// <summary>
    /// Caso 1: Pago válido sobre cargo de su condominio => 201 y la RPC recibe p_origen Admin, p_estado Confirmado y p_actor_id del token.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_PagoValido_Retorna201YRpcRecibeParametrosCorrectos()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            NumeroCasa = "Casa 10",
            Monto = 1000m,
            SaldoPendiente = 1000m,
            Estado = EstadoCargo.Pendiente
        };

        Dictionary<string, object?>? rpcPayloadCapturado = null;
        Guid? actorIdCapturado = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var rpcResponse = CrearRpcRegistrarPagoResult(pagoId, cargoId, condominioId, 10, 1000m, MetodoPago.Transferencia, EstadoPago.Confirmado, OrigenPago.Admin);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actorId) =>
            {
                rpcPayloadCapturado = payload as Dictionary<string, object?>;
                actorIdCapturado = actorId;
            })
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 1000m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-12345",
            BancoOrigen = "STP"
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RegistrarPagoResponse>();
        Assert.NotNull(body);
        Assert.NotNull(body.Pago);
        Assert.Equal(pagoId, body.Pago.Id);

        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal("Admin", rpcPayloadCapturado["p_origen"]);
        Assert.Equal("Confirmado", rpcPayloadCapturado["p_estado"]);
        Assert.Equal(adminId, rpcPayloadCapturado["p_actor_id"]);
        Assert.Equal(adminId, actorIdCapturado);
    }

    /// <summary>
    /// Caso 2: Cargo de otro condominio => 404 sin llamar a la RPC.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_CargoOtroCondominio_Retorna404SinLlamarRpc()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = otroCondominioId, // Otro condominio
            ViviendaId = 10,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 500m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabase.Verify(s => s.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    /// <summary>
    /// Caso 3: Inquilino o subusuario => 403.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_InquilinoOSubusuario_Retorna403Forbidden()
    {
        var clientInquilino = _factory.CreateClient();
        clientInquilino.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateInquilinoToken());

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = Guid.NewGuid(),
            Monto = 200m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var responseInquilino = await clientInquilino.PostAsJsonAsync("/api/pagos", request);
        Assert.Equal(HttpStatusCode.Forbidden, responseInquilino.StatusCode);

        var clientSubusuario = _factory.CreateClient();
        clientSubusuario.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateSubusuarioToken());

        var responseSubusuario = await clientSubusuario.PostAsJsonAsync("/api/pagos", request);
        Assert.Equal(HttpStatusCode.Forbidden, responseSubusuario.StatusCode);
    }

    /// <summary>
    /// Caso 4: Monto cero, negativo o con 3 decimales => 400.
    /// </summary>
    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    [InlineData(100.123)]
    public async Task RegistrarPago_Admin_MontoInvalido_Retorna400BadRequest(decimal montoInvalido)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = Guid.NewGuid(),
            Monto = montoInvalido,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    /// <summary>
    /// Caso 5: Fecha de pago futura => 400. Fecha de hoy (America/Mexico_City) => 201.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_FechaFuturaRetorna400_FechaHoyRetorna201()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 5,
            NumeroCasa = "Casa 5",
            Monto = 500m,
            SaldoPendiente = 500m,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var rpcResponse = CrearRpcRegistrarPagoResult(pagoId, cargoId, condominioId, 5, 500m, MetodoPago.Efectivo, EstadoPago.Confirmado, OrigenPago.Admin);
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var hoyMexico = ObtenerHoyMexico();

        // 1. Fecha futura => 400
        var requestFutura = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 500m,
            FechaPago = hoyMexico.AddDays(1),
            Metodo = MetodoPago.Efectivo
        };

        var responseFutura = await client.PostAsJsonAsync("/api/pagos", requestFutura);
        Assert.Equal(HttpStatusCode.BadRequest, responseFutura.StatusCode);
        var errFutura = await responseFutura.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(errFutura);
        Assert.Contains("futura", errFutura.Error, StringComparison.OrdinalIgnoreCase);

        // 2. Fecha de hoy => 201
        var requestHoy = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 500m,
            FechaPago = hoyMexico,
            Metodo = MetodoPago.Efectivo
        };

        var responseHoy = await client.PostAsJsonAsync("/api/pagos", requestHoy);
        Assert.Equal(HttpStatusCode.Created, responseHoy.StatusCode);
    }

    /// <summary>
    /// Caso 6: Transferencia sin referencia => 400. Efectivo sin referencia => 201.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_TransferenciaSinReferencia400_EfectivoSinReferencia201()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 3,
            NumeroCasa = "Casa 3",
            Monto = 300m,
            SaldoPendiente = 300m,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var rpcResponse = CrearRpcRegistrarPagoResult(pagoId, cargoId, condominioId, 3, 300m, MetodoPago.Efectivo, EstadoPago.Confirmado, OrigenPago.Admin);
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Transferencia sin referencia => 400
        var requestTransferenciaSinRef = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 300m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = null
        };

        var responseTransf = await client.PostAsJsonAsync("/api/pagos", requestTransferenciaSinRef);
        Assert.Equal(HttpStatusCode.BadRequest, responseTransf.StatusCode);

        // Efectivo sin referencia => 201
        var requestEfectivoSinRef = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 300m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo,
            Referencia = null
        };

        var responseEfectivo = await client.PostAsJsonAsync("/api/pagos", requestEfectivoSinRef);
        Assert.Equal(HttpStatusCode.Created, responseEfectivo.StatusCode);
    }

    /// <summary>
    /// Caso 7: Cargo ya Pagado => 201 (el excedente va a saldo a favor); el test verifica que la respuesta devuelve movimiento_saldo.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_CargoYaPagadoConExcedente_Retorna201ConMovimientoSaldo()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "Casa 1",
            Monto = 1000m,
            MontoPagadoConfirmado = 1000m,
            SaldoPendiente = 0m,
            Estado = EstadoCargo.Pagado
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        // RPC devuelve excedente a favor de 200 y objeto movimiento_saldo
        var rpcResponse = CrearRpcRegistrarPagoResult(
            pagoId, cargoId, condominioId, 1, 200m, MetodoPago.Efectivo, EstadoPago.Confirmado, OrigenPago.Admin,
            incluirMovimientoSaldo: true, saldoAFavor: 200m);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 200m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RegistrarPagoResponse>();
        Assert.NotNull(body);
        Assert.NotNull(body.MovimientoSaldo);
        Assert.Equal(200m, body.SaldoAFavor);
    }

    /// <summary>
    /// Caso 8: La RPC responde PG001 (cargo cancelado) => 409.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_RpcRespondePG001_Retorna409Conflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG001", "El cargo está cancelado o el estado no permite la operación"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("cancelado", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 9: Comprobante con ruta de otro condominio => 400. Hash que no es de 64 caracteres hexadecimales => 400.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_ComprobanteRutaOtroCondominioOHashInvalido_Retorna400BadRequest()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1. Ruta con condominio ajeno => 400
        var requestRutaAjena = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo,
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{otroCondominioId}/1/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('a', 64)
            }
        };

        var responseRutaAjena = await client.PostAsJsonAsync("/api/pagos", requestRutaAjena);
        Assert.Equal(HttpStatusCode.BadRequest, responseRutaAjena.StatusCode);

        // 2. Hash inválido (menor a 64 chars o no hexadecimal) => 400
        var requestHashInvalido = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo,
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/1/2026/10/{Guid.NewGuid()}.jpg",
                Hash = "hash-demasiado-corto"
            }
        };

        var responseHashInvalido = await client.PostAsJsonAsync("/api/pagos", requestHashInvalido);
        Assert.Equal(HttpStatusCode.BadRequest, responseHashInvalido.StatusCode);
    }

    /// <summary>
    /// Caso 10: La RPC responde 23505 por idx_pagos_anti_duplicado_ref => 409 con el mensaje de referencia, monto y fecha repetidos.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_RpcResponde23505PorIdxRef_Retorna409ConMensajeEsperado()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "23505", "Ya existe un pago registrado con la misma referencia, monto y fecha.", motivoConflicto: MotivoConflicto.PagoDuplicadoReferencia, constraintName: "idx_pagos_anti_duplicado_ref"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-DUPLICADA"
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("misma referencia, monto y fecha", err.Error);
    }

    /// <summary>
    /// Caso 10b: La RPC responde 23505 por idx_pagos_anti_duplicado_hash => 409 con el mensaje de comprobante ya registrado.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_RpcResponde23505PorIdxHash_Retorna409ConMensajeEsperado()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "23505", "Este comprobante ya fue registrado anteriormente.", motivoConflicto: MotivoConflicto.ComprobanteDuplicado, constraintName: "idx_pagos_anti_duplicado_hash"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo,
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/1/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('f', 64)
            }
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("comprobante ya fue registrado", err.Error);
    }

    /// <summary>
    /// Caso 10c: La RPC responde 23505 con un nombre de índice desconocido => 409 con mensaje genérico.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_RpcResponde23505IndiceDesconocido_Retorna409ConMensajeGenerico()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            Estado = EstadoCargo.Pendiente
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "23505", "El registro ya existe.", motivoConflicto: MotivoConflicto.Generico, constraintName: "uq_otro_indice"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RegistrarPagoAdminRequest
        {
            CargoId = cargoId,
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo
        };

        var response = await client.PostAsJsonAsync("/api/pagos", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("El registro ya existe", err.Error);
    }

    /// <summary>
    /// Caso 11: registrado_por y p_actor_id salen del token aunque el body intente mandar otro usuario.
    /// </summary>
    [Fact]
    public async Task RegistrarPago_Admin_ActorIdSaleDelTokenAunqueBodyMandeOtro()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var usuarioFalso = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            NumeroCasa = "Casa 10",
            Monto = 800m,
            SaldoPendiente = 800m,
            Estado = EstadoCargo.Pendiente
        };

        Dictionary<string, object?>? rpcPayloadCapturado = null;
        Guid? actorIdCapturado = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var rpcResponse = CrearRpcRegistrarPagoResult(pagoId, cargoId, condominioId, 10, 800m, MetodoPago.Efectivo, EstadoPago.Confirmado, OrigenPago.Admin);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actorId) =>
            {
                rpcPayloadCapturado = payload as Dictionary<string, object?>;
                actorIdCapturado = actorId;
            })
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Mandamos JSON raw con campos extras como 'registrado_por' y 'actor_id'
        var jsonRaw = JsonSerializer.Serialize(new
        {
            cargo_id = cargoId,
            monto = 800m,
            fecha_pago = ObtenerHoyMexico().ToString("yyyy-MM-dd"),
            metodo = "Efectivo",
            registrado_por = usuarioFalso,
            actor_id = usuarioFalso
        });

        using var content = new StringContent(jsonRaw, System.Text.Encoding.UTF8, "application/json");
        var response = await client.PostAsync("/api/pagos", content);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, rpcPayloadCapturado["p_actor_id"]);
        Assert.NotEqual(usuarioFalso, rpcPayloadCapturado["p_actor_id"]);
        Assert.Equal(adminId, actorIdCapturado);
    }

    #endregion

    #region Reporte por Inquilino (Casos 12 al 17)

    /// <summary>
    /// Caso 12: Reporte válido => 201 y la RPC recibe p_origen Inquilino y p_estado PendienteConfirmacion.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Inquilino_ReporteValido_Retorna201YRpcRecibeParametrosCorrectos()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var rutaComprobante = $"{condominioId}/12/2026/10/{Guid.NewGuid()}.jpg";
        var hashComprobante = new string('a', 64);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 12,
            NumeroCasa = "Casa 12",
            Monto = 1500m,
            SaldoPendiente = 1500m,
            Estado = EstadoCargo.Pendiente
        };

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(12, inquilinoId))
            .ReturnsAsync(true); // P6 método 3: es titular

        Dictionary<string, object?>? rpcPayloadCapturado = null;
        Guid? actorIdCapturado = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var rpcResponse = CrearRpcRegistrarPagoResult(pagoId, cargoId, condominioId, 12, 1500m, MetodoPago.Transferencia, EstadoPago.PendienteConfirmacion, OrigenPago.Inquilino);

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_registrar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actorId) =>
            {
                rpcPayloadCapturado = payload as Dictionary<string, object?>;
                actorIdCapturado = actorId;
            })
            .ReturnsAsync(rpcResponse);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new ReportarPagoRequest
        {
            CargoId = cargoId,
            Monto = 1500m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "TR-INQ-001",
            BancoOrigen = "Santander",
            Comprobante = new ComprobantePagoDto
            {
                Ruta = rutaComprobante,
                Hash = hashComprobante
            }
        };

        var response = await client.PostAsJsonAsync("/api/pagos/reportar", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<PagoResponse>();
        Assert.NotNull(body);
        Assert.Equal(pagoId, body.Id);

        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal("Inquilino", rpcPayloadCapturado["p_origen"]);
        Assert.Equal("PendienteConfirmacion", rpcPayloadCapturado["p_estado"]);
        Assert.Equal(inquilinoId, rpcPayloadCapturado["p_actor_id"]);
        Assert.Equal(inquilinoId, actorIdCapturado);
    }

    /// <summary>
    /// Caso 13: Sin comprobante => 400. Transferencia sin banco_origen => 400.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Inquilino_SinComprobanteOSinBancoOrigen_Retorna400BadRequest()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1. Sin comprobante => 400
        var requestSinComprobante = new ReportarPagoRequest
        {
            CargoId = cargoId,
            Monto = 1000m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-123",
            BancoOrigen = "BBVA",
            Comprobante = null
        };

        var responseSinComp = await client.PostAsJsonAsync("/api/pagos/reportar", requestSinComprobante);
        Assert.Equal(HttpStatusCode.BadRequest, responseSinComp.StatusCode);

        // 2. Transferencia sin banco de origen => 400
        var requestSinBanco = new ReportarPagoRequest
        {
            CargoId = cargoId,
            Monto = 1000m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-123",
            BancoOrigen = null,
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/1/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('b', 64)
            }
        };

        var responseSinBanco = await client.PostAsJsonAsync("/api/pagos/reportar", requestSinBanco);
        Assert.Equal(HttpStatusCode.BadRequest, responseSinBanco.StatusCode);
    }

    /// <summary>
    /// Caso 14: Cargo de vivienda ajena => 404.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Inquilino_CargoViviendaAjena_Retorna404NotFound()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 88, // Vivienda ajena
            Estado = EstadoCargo.Pendiente
        };

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(88, inquilinoId))
            .ReturnsAsync(false); // No es titular

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new ReportarPagoRequest
        {
            CargoId = cargoId,
            Monto = 500m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-88",
            BancoOrigen = "HSBC",
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/88/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('c', 64)
            }
        };

        var response = await client.PostAsJsonAsync("/api/pagos/reportar", request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabase.Verify(s => s.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    /// <summary>
    /// Caso 15: Cargo Pagado => 409 sin llamar a la RPC. Cargo Cancelado => 409 sin llamar a la RPC.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Inquilino_CargoPagadoOCancelado_Retorna409ConflictSinLlamarRpc()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoPagadoId = Guid.NewGuid();
        var cargoCanceladoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(5, inquilinoId))
            .ReturnsAsync(true);

        var cargoPagado = new VwCargo
        {
            Id = cargoPagadoId,
            CondominioId = condominioId,
            ViviendaId = 5,
            Estado = EstadoCargo.Pagado
        };

        var cargoCancelado = new VwCargo
        {
            Id = cargoCanceladoId,
            CondominioId = condominioId,
            ViviendaId = 5,
            Estado = EstadoCargo.Cancelado
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoPagadoId}"))
            .ReturnsAsync(cargoPagado);
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoCanceladoId}"))
            .ReturnsAsync(cargoCancelado);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1. Cargo Pagado => 409
        var requestPagado = new ReportarPagoRequest
        {
            CargoId = cargoPagadoId,
            Monto = 500m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-PAGADO",
            BancoOrigen = "BBVA",
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/5/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('d', 64)
            }
        };

        var responsePagado = await client.PostAsJsonAsync("/api/pagos/reportar", requestPagado);
        Assert.Equal(HttpStatusCode.Conflict, responsePagado.StatusCode);

        // 2. Cargo Cancelado => 409
        var requestCancelado = new ReportarPagoRequest
        {
            CargoId = cargoCanceladoId,
            Monto = 500m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-CANCELADO",
            BancoOrigen = "BBVA",
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/5/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('e', 64)
            }
        };

        var responseCancelado = await client.PostAsJsonAsync("/api/pagos/reportar", requestCancelado);
        Assert.Equal(HttpStatusCode.Conflict, responseCancelado.StatusCode);

        // Verificar que la RPC NUNCA se llamó
        mockSupabase.Verify(s => s.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    /// <summary>
    /// Caso 16: Comprobante con ruta de otra vivienda => 400.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Inquilino_ComprobanteRutaOtraVivienda_Retorna400BadRequest()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = condominioId,
            ViviendaId = 15, // Cargo es de vivienda 15
            Estado = EstadoCargo.Pendiente
        };

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.EsResidenteTitularAsync(15, inquilinoId))
            .ReturnsAsync(true);

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dViviendas = services.SingleOrDefault(d => d.ServiceType == typeof(IViviendasLookupService));
                if (dViviendas != null) services.Remove(dViviendas);
                services.AddScoped(_ => mockViviendas.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Ruta apunta a vivienda 99 en vez de vivienda 15
        var request = new ReportarPagoRequest
        {
            CargoId = cargoId,
            Monto = 1000m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Transferencia,
            Referencia = "REF-RUTA-OTRA",
            BancoOrigen = "Santander",
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/99/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('a', 64)
            }
        };

        var response = await client.PostAsJsonAsync("/api/pagos/reportar", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("vivienda", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 17: Admin intentando usar el endpoint de reporte => 403.
    /// </summary>
    [Fact]
    public async Task ReportarPago_Admin_Retorna403Forbidden()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new ReportarPagoRequest
        {
            CargoId = Guid.NewGuid(),
            Monto = 100m,
            FechaPago = ObtenerHoyMexico(),
            Metodo = MetodoPago.Efectivo,
            Comprobante = new ComprobantePagoDto
            {
                Ruta = $"{condominioId}/1/2026/10/{Guid.NewGuid()}.jpg",
                Hash = new string('1', 64)
            }
        };

        var response = await client.PostAsJsonAsync("/api/pagos/reportar", request);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    #endregion
}
