using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Pagination;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class PagosConfirmacionAnulacionYConsultaTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public PagosConfirmacionAnulacionYConsultaTests(PagosApiFactory factory)
    {
        _factory = factory;
    }

    private static JsonElement CrearRpcConfirmarPagoResult(
        Guid pagoId,
        Guid cargoId,
        Guid condominioId,
        int viviendaId,
        decimal monto,
        bool incluirMovimientoSaldo = true,
        decimal saldoAFavor = 50m)
    {
        var pago = new Dictionary<string, object?>
        {
            ["id"] = pagoId,
            ["cargo_id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["monto"] = monto,
            ["monto_cubierto"] = monto,
            ["monto_excedente"] = 0m,
            ["estado"] = EstadoPago.Confirmado.ToString(),
            ["confirmado_por"] = Guid.NewGuid(),
            ["confirmado_en"] = DateTimeOffset.UtcNow
        };

        var cargo = new Dictionary<string, object?>
        {
            ["id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["monto"] = 1000m,
            ["monto_pagado_confirmado"] = monto,
            ["saldo_pendiente"] = Math.Max(0, 1000m - monto),
            ["estado"] = EstadoCargo.Pagado.ToString()
        };

        var root = new Dictionary<string, object?>
        {
            ["pago"] = pago,
            ["cargo"] = cargo,
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

    private static JsonElement CrearRpcAnularPagoResult(
        Guid pagoId,
        Guid reversaId,
        Guid cargoId,
        Guid condominioId,
        int viviendaId,
        decimal monto,
        string motivo)
    {
        var pagoAnulado = new Dictionary<string, object?>
        {
            ["id"] = pagoId,
            ["cargo_id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["monto"] = monto,
            ["monto_cubierto"] = monto,
            ["monto_excedente"] = 0m,
            ["estado"] = EstadoPago.Anulado.ToString(),
            ["motivo_anulacion"] = motivo,
            ["anulado_por"] = Guid.NewGuid(),
            ["anulado_en"] = DateTimeOffset.UtcNow
        };

        var pagoReversa = new Dictionary<string, object?>
        {
            ["id"] = reversaId,
            ["cargo_id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["monto"] = -monto,
            ["monto_cubierto"] = -monto,
            ["monto_excedente"] = 0m,
            ["estado"] = EstadoPago.Confirmado.ToString(),
            ["es_reversa"] = true,
            ["pago_original_id"] = pagoId,
            ["registrado_por"] = Guid.NewGuid(),
            ["creado_en"] = DateTimeOffset.UtcNow
        };

        var cargo = new Dictionary<string, object?>
        {
            ["id"] = cargoId,
            ["condominio_id"] = condominioId,
            ["vivienda_id"] = viviendaId,
            ["numero_casa"] = $"Casa {viviendaId}",
            ["tipo"] = TipoCargo.Mantenimiento.ToString(),
            ["concepto"] = "Cuota mensual",
            ["monto"] = monto,
            ["monto_pagado_confirmado"] = 0m,
            ["saldo_pendiente"] = monto,
            ["estado"] = EstadoCargo.Pendiente.ToString()
        };

        var root = new Dictionary<string, object?>
        {
            ["pago_anulado"] = pagoAnulado,
            ["pago_reversa"] = pagoReversa,
            ["cargo"] = cargo,
            ["saldo_a_favor"] = 0m
        };

        var json = JsonSerializer.Serialize(root);
        return JsonDocument.Parse(json).RootElement.Clone();
    }

    #region 1 a 4: Confirmar y Rechazar

    /// <summary>
    /// Caso 1: Admin confirma pago pendiente => 200 con pago, cargo, movimiento_saldo y saldo_a_favor.
    /// </summary>
    [Fact]
    public async Task ConfirmarPago_Admin_PagoPendiente_Retorna200OkConDetalles()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CargoId = cargoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            NumeroCasa = "Casa 10",
            Monto = 1000m,
            Estado = EstadoPago.PendienteConfirmacion
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var rpcResponse = CrearRpcConfirmarPagoResult(pagoId, cargoId, condominioId, 10, 1000m, incluirMovimientoSaldo: true, saldoAFavor: 50m);
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_confirmar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
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

        var response = await client.PostAsync($"/api/pagos/{pagoId}/confirmar", null);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<ConfirmarPagoResponse>();
        Assert.NotNull(body);
        Assert.NotNull(body.Pago);
        Assert.NotNull(body.Cargo);
        Assert.NotNull(body.MovimientoSaldo);
        Assert.Equal(50m, body.SaldoAFavor);
        Assert.Equal(EstadoPago.Confirmado, body.Pago.Estado);
    }

    /// <summary>
    /// Caso 2: Confirmar con la RPC respondiendo PG002 => 409. Con PG001 => 409.
    /// </summary>
    [Fact]
    public async Task ConfirmarPago_RpcRespondePG002OPG001_Retorna409Conflict()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            Estado = EstadoPago.PendienteConfirmacion
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        // 1. PG002
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_confirmar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG002", "El pago no está pendiente de confirmación"));

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

        var responsePG002 = await client.PostAsync($"/api/pagos/{pagoId}/confirmar", null);
        Assert.Equal(HttpStatusCode.Conflict, responsePG002.StatusCode);

        // 2. PG001
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_confirmar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG001", "El cargo está cancelado o el estado no permite la operación"));

        var responsePG001 = await client.PostAsync($"/api/pagos/{pagoId}/confirmar", null);
        Assert.Equal(HttpStatusCode.Conflict, responsePG001.StatusCode);
    }

    /// <summary>
    /// Caso 3: Rechazar con motivo => 200; sin motivo o motivo corto => 400. RPC respondiendo PG003 => 409.
    /// </summary>
    [Fact]
    public async Task RechazarPago_ConMotivo200_SinMotivoORechazoCorto400_RpcPG003Retorna409()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            NumeroCasa = "Casa 10",
            Monto = 500m,
            Estado = EstadoPago.PendienteConfirmacion
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var rpcResponse = JsonDocument.Parse(JsonSerializer.Serialize(new
        {
            pago = new
            {
                id = pagoId,
                condominio_id = condominioId,
                vivienda_id = 10,
                numero_casa = "Casa 10",
                monto = 500m,
                estado = "Rechazado",
                motivo_rechazo = "Comprobante ilegible"
            }
        })).RootElement.Clone();

        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_rechazar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
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

        // Motivo válido => 200
        var requestValido = new RechazarPagoRequest { Motivo = "Comprobante ilegible" };
        var response200 = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/rechazar", requestValido);
        Assert.Equal(HttpStatusCode.OK, response200.StatusCode);
        var body = await response200.Content.ReadFromJsonAsync<RechazarPagoResponse>();
        Assert.NotNull(body);
        Assert.Equal(EstadoPago.Rechazado, body.Pago.Estado);

        // Sin motivo => 400
        var requestVacio = new RechazarPagoRequest { Motivo = "" };
        var responseVacio = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/rechazar", requestVacio);
        Assert.Equal(HttpStatusCode.BadRequest, responseVacio.StatusCode);

        // Motivo corto (< 5 chars) => 400
        var requestCorto = new RechazarPagoRequest { Motivo = "no" };
        var responseCorto = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/rechazar", requestCorto);
        Assert.Equal(HttpStatusCode.BadRequest, responseCorto.StatusCode);

        // RPC PG003 => 409
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_rechazar_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG003", "El pago no se encuentra en estado PendienteConfirmacion para ser rechazado"));

        var responsePG003 = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/rechazar", requestValido);
        Assert.Equal(HttpStatusCode.Conflict, responsePG003.StatusCode);
    }

    /// <summary>
    /// Caso 4: Inquilino o subusuario => 403. Pago de otro condominio => 404 sin llamar a la RPC.
    /// </summary>
    [Fact]
    public async Task ConfirmarYRechazar_InquilinoOSubusuario403_PagoOtroCondominio404()
    {
        var pagoId = Guid.NewGuid();
        var clientInq = _factory.CreateClient();
        clientInq.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateInquilinoToken());

        var respConfInq = await clientInq.PostAsync($"/api/pagos/{pagoId}/confirmar", null);
        Assert.Equal(HttpStatusCode.Forbidden, respConfInq.StatusCode);

        var respRechInq = await clientInq.PostAsJsonAsync($"/api/pagos/{pagoId}/rechazar", new RechazarPagoRequest { Motivo = "Comprobante falso" });
        Assert.Equal(HttpStatusCode.Forbidden, respRechInq.StatusCode);

        // Pago de otro condominio para Admin => 404 sin llamar RPC
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var tokenAdmin = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = otroCondominioId,
            ViviendaId = 1,
            Estado = EstadoPago.PendienteConfirmacion
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var clientAdmin = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        clientAdmin.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);

        var respOtroCond = await clientAdmin.PostAsync($"/api/pagos/{pagoId}/confirmar", null);
        Assert.Equal(HttpStatusCode.NotFound, respOtroCond.StatusCode);
        mockSupabase.Verify(s => s.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    #endregion

    #region 5 a 8: Anular

    /// <summary>
    /// Caso 5: Admin anula pago confirmado con motivo => 200 con pago_anulado, pago_reversa, cargo, movimiento_saldo y saldo_a_favor.
    /// </summary>
    [Fact]
    public async Task AnularPago_Admin_PagoConfirmadoConMotivo_Retorna200OkConDetallesCompletos()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var reversaId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CargoId = cargoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            NumeroCasa = "Casa 10",
            Monto = 1000m,
            Estado = EstadoPago.Confirmado,
            EsReversa = false
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var rpcResponse = CrearRpcAnularPagoResult(pagoId, reversaId, cargoId, condominioId, 10, 1000m, "Error en el monto pagado");
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_anular_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
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

        var request = new AnularPagoRequest { Motivo = "Error en el monto pagado" };
        var response = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<AnularPagoResponse>();
        Assert.NotNull(body);
        Assert.NotNull(body.PagoAnulado);
        Assert.NotNull(body.PagoReversa);
        Assert.NotNull(body.Cargo);
        Assert.Equal(EstadoPago.Anulado, body.PagoAnulado.Estado);
        Assert.True(body.PagoReversa.EsReversa);
    }

    /// <summary>
    /// Caso 6: La RPC responde PG004 => 409. PG007 => 409 con mensaje que menciona revertir aplicaciones de saldo.
    /// </summary>
    [Fact]
    public async Task AnularPago_RpcPG004YPG007_Retorna409ConflictConMensajeEsperado()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            Estado = EstadoPago.Confirmado,
            EsReversa = false
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        // 1. PG004
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_anular_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG004", "Solo se pueden anular pagos confirmados"));

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

        var request = new AnularPagoRequest { Motivo = "Pago equivocado de cuota" };
        var responsePG004 = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", request);
        Assert.Equal(HttpStatusCode.Conflict, responsePG004.StatusCode);

        // 2. PG007
        mockSupabase
            .Setup(s => s.RpcAsync<JsonElement>("rpc_anular_pago", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG007", "Saldo a favor insuficiente"));

        var responsePG007 = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", request);
        Assert.Equal(HttpStatusCode.Conflict, responsePG007.StatusCode);
        var errPG007 = await responsePG007.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(errPG007);
        Assert.Contains("revertir", errPG007.Error, StringComparison.OrdinalIgnoreCase);
        Assert.Contains("aplicaciones de saldo", errPG007.Error, StringComparison.OrdinalIgnoreCase);
    }

    /// <summary>
    /// Caso 7: Intentar anular un registro con es_reversa verdadero => 409 sin llamar a la RPC.
    /// </summary>
    [Fact]
    public async Task AnularPago_EsReversaVerdadero_Retorna409SinLlamarRpc()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 10,
            Estado = EstadoPago.Confirmado,
            EsReversa = true // Registro de reversa
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

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

        var request = new AnularPagoRequest { Motivo = "Intento anular reversa" };
        var response = await client.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        mockSupabase.Verify(s => s.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    /// <summary>
    /// Caso 8: Sin motivo => 400. Inquilino => 403. Otro condominio => 404.
    /// </summary>
    [Fact]
    public async Task AnularPago_SinMotivo400_Inquilino403_OtroCondominio404()
    {
        var pagoId = Guid.NewGuid();

        // 1. Inquilino => 403
        var clientInq = _factory.CreateClient();
        clientInq.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", TestTokenGenerator.GenerateInquilinoToken());
        var respInq = await clientInq.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", new AnularPagoRequest { Motivo = "Quiero anular" });
        Assert.Equal(HttpStatusCode.Forbidden, respInq.StatusCode);

        // 2. Sin motivo => 400
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var tokenAdmin = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);
        var clientAdmin = _factory.CreateClient();
        clientAdmin.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);

        var respSinMotivo = await clientAdmin.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", new AnularPagoRequest { Motivo = "" });
        Assert.Equal(HttpStatusCode.BadRequest, respSinMotivo.StatusCode);

        // 3. Otro condominio => 404
        var otroCondominioId = Guid.NewGuid();
        var vwPagoOtroCond = new VwPago
        {
            Id = pagoId,
            CondominioId = otroCondominioId,
            ViviendaId = 1,
            Estado = EstadoPago.Confirmado
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPagoOtroCond);

        var clientOtroCond = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (descriptor != null) services.Remove(descriptor);
                services.AddScoped(_ => mockSupabase.Object);
            });
        }).CreateClient();

        clientOtroCond.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenAdmin);

        var respOtroCond = await clientOtroCond.PostAsJsonAsync($"/api/pagos/{pagoId}/anular", new AnularPagoRequest { Motivo = "Anular pago ajeno" });
        Assert.Equal(HttpStatusCode.NotFound, respOtroCond.StatusCode);
    }

    #endregion

    #region 9 a 14: Listar

    /// <summary>
    /// Caso 9: Admin siempre consulta con su condominio_id.
    /// </summary>
    [Fact]
    public async Task ListarPagos_Admin_SiempreFiltraPorSuCondominioId()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        string? queryStringCapturado = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetPagedAsync<VwPago>("vw_pagos", It.IsAny<PaginationParams>(), It.IsAny<string>()))
            .Callback<string, PaginationParams, string>((_, _, qs) => queryStringCapturado = qs)
            .ReturnsAsync((new List<VwPago>(), 0));

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

        var response = await client.GetAsync("/api/pagos");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryStringCapturado);
        Assert.Contains($"condominio_id=eq.{condominioId}", queryStringCapturado);
    }

    /// <summary>
    /// Caso 10: Inquilino solo recibe pagos de sus viviendas; con usuario_id ajeno => 403; con vivienda_id ajena => 403.
    /// </summary>
    [Fact]
    public async Task ListarPagos_Inquilino_SoloSusViviendas_UsuarioIdAjeno403_ViviendaAjena403()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int> { 10, 20 });

        string? queryStringCapturado = null;
        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetPagedAsync<VwPago>("vw_pagos", It.IsAny<PaginationParams>(), It.IsAny<string>()))
            .Callback<string, PaginationParams, string>((_, _, qs) => queryStringCapturado = qs)
            .ReturnsAsync((new List<VwPago>(), 0));

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

        // 1. Consulta normal => filtra por sus viviendas (in.(10,20))
        var response = await client.GetAsync("/api/pagos");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryStringCapturado);
        Assert.Contains("vivienda_id=in.(10,20)", queryStringCapturado);

        // 2. Consulta con usuario_id ajeno => 403
        var responseUsuarioAjeno = await client.GetAsync($"/api/pagos?usuario_id={Guid.NewGuid()}");
        Assert.Equal(HttpStatusCode.Forbidden, responseUsuarioAjeno.StatusCode);

        // 3. Consulta con vivienda_id ajena (no es 10 ni 20) => 403
        var responseViviendaAjena = await client.GetAsync("/api/pagos?vivienda_id=99");
        Assert.Equal(HttpStatusCode.Forbidden, responseViviendaAjena.StatusCode);
    }

    /// <summary>
    /// Caso 11: Lista de viviendas vacía => página vacía sin consultar la vista.
    /// </summary>
    [Fact]
    public async Task ListarPagos_ListaViviendasVacia_RetornaPaginaVaciaSinConsultarVista()
    {
        var inquilinoId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken(inquilinoId, condominioId);

        var mockViviendas = new Mock<IViviendasLookupService>();
        mockViviendas
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(inquilinoId))
            .ReturnsAsync(new List<int>()); // Vacía

        var mockSupabase = new Mock<ISupabaseRestClient>();

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

        var response = await client.GetAsync("/api/pagos");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var body = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<PagoResponse>>();
        Assert.NotNull(body);
        Assert.Empty(body.Items);
        Assert.Equal(0, body.Total);

        mockSupabase.Verify(s => s.GetPagedAsync<VwPago>(It.IsAny<string>(), It.IsAny<PaginationParams>(), It.IsAny<string>()), Times.Never);
    }

    /// <summary>
    /// Caso 12: Los filtros llegan al cliente como filtros de base (estado, método, origen, es_reversa, rango de fechas, cargo, vivienda).
    /// </summary>
    [Fact]
    public async Task ListarPagos_TodosLosFiltros_LleganAlClienteCorrectamente()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        string? queryStringCapturado = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetPagedAsync<VwPago>("vw_pagos", It.IsAny<PaginationParams>(), It.IsAny<string>()))
            .Callback<string, PaginationParams, string>((_, _, qs) => queryStringCapturado = qs)
            .ReturnsAsync((new List<VwPago>(), 0));

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

        var url = $"/api/pagos?cargo_id={cargoId}&vivienda_id=15&estado=Confirmado&metodo=Transferencia&origen=Admin&es_reversa=false&fecha_pago_desde=2026-10-01&fecha_pago_hasta=2026-10-31";
        var response = await client.GetAsync(url);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(queryStringCapturado);

        Assert.Contains($"condominio_id=eq.{condominioId}", queryStringCapturado);
        Assert.Contains("vivienda_id=eq.15", queryStringCapturado);
        Assert.Contains($"cargo_id=eq.{cargoId}", queryStringCapturado);
        Assert.Contains("estado=eq.Confirmado", queryStringCapturado);
        Assert.Contains("metodo=eq.Transferencia", queryStringCapturado);
        Assert.Contains("origen=eq.Admin", queryStringCapturado);
        Assert.Contains("es_reversa=eq.false", queryStringCapturado);
        Assert.Contains("fecha_pago=gte.2026-10-01", queryStringCapturado);
        Assert.Contains("fecha_pago=lte.2026-10-31", queryStringCapturado);
    }

    /// <summary>
    /// Caso 13: La paginación respeta default 20 y máximo 100.
    /// </summary>
    [Fact]
    public async Task ListarPagos_PaginacionRespetaDefault20YMaximo100()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        PaginationParams? paramsCapturados = null;

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetPagedAsync<VwPago>("vw_pagos", It.IsAny<PaginationParams>(), It.IsAny<string>()))
            .Callback<string, PaginationParams, string>((_, pp, _) => paramsCapturados = pp)
            .ReturnsAsync((new List<VwPago>(), 0));

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

        // 1. Sin parámetros => default 20
        var responseDefault = await client.GetAsync("/api/pagos");
        Assert.Equal(HttpStatusCode.OK, responseDefault.StatusCode);
        Assert.NotNull(paramsCapturados);
        Assert.Equal(1, paramsCapturados.Page);
        Assert.Equal(20, paramsCapturados.PageSize);

        // 2. Con tamanoPagina=200 => tope máximo 100
        var responseMax = await client.GetAsync("/api/pagos?tamanoPagina=200");
        Assert.Equal(HttpStatusCode.OK, responseMax.StatusCode);
        Assert.NotNull(paramsCapturados);
        Assert.Equal(100, paramsCapturados.PageSize);
    }

    /// <summary>
    /// Caso 14: Ningún ítem contiene comprobante_ruta ni comprobante_hash.
    /// </summary>
    [Fact]
    public async Task ListarPagos_NingunItemContieneRutaNiHash()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPagos = new List<VwPago>
        {
            new VwPago
            {
                Id = Guid.NewGuid(),
                CondominioId = condominioId,
                ViviendaId = 1,
                NumeroCasa = "Casa 1",
                Monto = 500m,
                Estado = EstadoPago.Confirmado,
                TieneComprobante = true,
                ComprobanteRuta = $"{condominioId}/1/2026/10/secreto.jpg",
                ComprobanteHash = "abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789"
            }
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetPagedAsync<VwPago>("vw_pagos", It.IsAny<PaginationParams>(), It.IsAny<string>()))
            .ReturnsAsync((vwPagos, 1));

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

        var response = await client.GetAsync("/api/pagos");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var rawJson = await response.Content.ReadAsStringAsync();
        using var jsonDoc = JsonDocument.Parse(rawJson);
        var items = jsonDoc.RootElement.GetProperty("items");

        foreach (var item in items.EnumerateArray())
        {
            Assert.False(item.TryGetProperty("comprobante_ruta", out _));
            Assert.False(item.TryGetProperty("comprobante_hash", out _));
        }
    }

    #endregion

    #region 15 a 17: Detalle y Comprobante

    /// <summary>
    /// Caso 15: Detalle de pago propio => 200. Ajeno => 404.
    /// </summary>
    [Fact]
    public async Task ObtenerDetallePago_Propio200_Ajeno404()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var pagoPropioId = Guid.NewGuid();
        var pagoAjenoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var vwPagoPropio = new VwPago
        {
            Id = pagoPropioId,
            CondominioId = condominioId,
            ViviendaId = 1,
            NumeroCasa = "Casa 1",
            Monto = 600m
        };

        var vwPagoAjeno = new VwPago
        {
            Id = pagoAjenoId,
            CondominioId = otroCondominioId,
            ViviendaId = 2,
            NumeroCasa = "Casa 2",
            Monto = 700m
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoPropioId}"))
            .ReturnsAsync(vwPagoPropio);
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoAjenoId}"))
            .ReturnsAsync(vwPagoAjeno);

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

        // Propio => 200
        var respPropio = await client.GetAsync($"/api/pagos/{pagoPropioId}");
        Assert.Equal(HttpStatusCode.OK, respPropio.StatusCode);

        // Ajeno => 404
        var respAjeno = await client.GetAsync($"/api/pagos/{pagoAjenoId}");
        Assert.Equal(HttpStatusCode.NotFound, respAjeno.StatusCode);
    }

    /// <summary>
    /// Caso 16: comprobante-url con comprobante => 200 con url y expira_en. Sin comprobante => 404. Pago ajeno => 404.
    /// </summary>
    [Fact]
    public async Task ObtenerComprobanteUrl_ConComprobante200_SinComprobante404_PagoAjeno404()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var pagoConCompId = Guid.NewGuid();
        var pagoSinCompId = Guid.NewGuid();
        var pagoAjenoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var ruta = $"{condominioId}/1/2026/10/comp.jpg";
        var expectedUrl = "https://mock.supabase.co/storage/v1/object/sign/comprobantes/comp.jpg?token=temp";

        var vwPagoConComp = new VwPago
        {
            Id = pagoConCompId,
            CondominioId = condominioId,
            ViviendaId = 1,
            TieneComprobante = true,
            ComprobanteRuta = ruta
        };

        var vwPagoSinComp = new VwPago
        {
            Id = pagoSinCompId,
            CondominioId = condominioId,
            ViviendaId = 1,
            TieneComprobante = false,
            ComprobanteRuta = null
        };

        var vwPagoAjeno = new VwPago
        {
            Id = pagoAjenoId,
            CondominioId = otroCondominioId,
            ViviendaId = 1,
            TieneComprobante = true,
            ComprobanteRuta = $"{otroCondominioId}/1/2026/10/otro.jpg"
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoConCompId}"))
            .ReturnsAsync(vwPagoConComp);
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoSinCompId}"))
            .ReturnsAsync(vwPagoSinComp);
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoAjenoId}"))
            .ReturnsAsync(vwPagoAjeno);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.CrearUrlFirmadaAsync(ruta, It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ReturnsAsync(expectedUrl);

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (dStorage != null) services.Remove(dStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // 1. Con comprobante => 200 con url y expira_en
        var respConComp = await client.GetAsync($"/api/pagos/{pagoConCompId}/comprobante-url");
        Assert.Equal(HttpStatusCode.OK, respConComp.StatusCode);
        var body = await respConComp.Content.ReadFromJsonAsync<ComprobanteUrlResponse>();
        Assert.NotNull(body);
        Assert.Equal(expectedUrl, body.Url);
        Assert.True(body.ExpiraEn > DateTimeOffset.UtcNow);

        // 2. Sin comprobante => 404
        var respSinComp = await client.GetAsync($"/api/pagos/{pagoSinCompId}/comprobante-url");
        Assert.Equal(HttpStatusCode.NotFound, respSinComp.StatusCode);

        // 3. Pago ajeno => 404
        var respAjeno = await client.GetAsync($"/api/pagos/{pagoAjenoId}/comprobante-url");
        Assert.Equal(HttpStatusCode.NotFound, respAjeno.StatusCode);
    }

    /// <summary>
    /// Caso 17: comprobante-url cuando Storage indica que el objeto no existe => 404 con el mensaje de depuración.
    /// </summary>
    [Fact]
    public async Task ObtenerComprobanteUrl_ObjetoNoExisteEnStorage_Retorna404ConMensajeDepurado()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var pagoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var ruta = $"{condominioId}/1/2026/10/depurado.jpg";
        var vwPago = new VwPago
        {
            Id = pagoId,
            CondominioId = condominioId,
            ViviendaId = 1,
            TieneComprobante = true,
            ComprobanteRuta = ruta
        };

        var mockSupabase = new Mock<ISupabaseRestClient>();
        mockSupabase
            .Setup(s => s.GetSingleOrDefaultAsync<VwPago>("vw_pagos", $"id=eq.{pagoId}"))
            .ReturnsAsync(vwPago);

        var mockStorage = new Mock<IComprobanteStorageService>();
        mockStorage
            .Setup(s => s.CrearUrlFirmadaAsync(ruta, It.IsAny<int?>(), It.IsAny<CancellationToken>()))
            .ThrowsAsync(new KeyNotFoundException("Object not found"));

        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var dSupabase = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
                if (dSupabase != null) services.Remove(dSupabase);
                services.AddScoped(_ => mockSupabase.Object);

                var dStorage = services.SingleOrDefault(d => d.ServiceType == typeof(IComprobanteStorageService));
                if (dStorage != null) services.Remove(dStorage);
                services.AddScoped(_ => mockStorage.Object);
            });
        }).CreateClient();

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/pagos/{pagoId}/comprobante-url");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal("Comprobante depurado por política de retención", err.Error);
    }

    #endregion
}
