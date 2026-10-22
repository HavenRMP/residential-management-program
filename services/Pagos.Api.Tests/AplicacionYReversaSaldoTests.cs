using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Xunit;

namespace Pagos.Api.Tests;

/// <summary>
/// Pruebas de integración y unitarias para Aplicar y Revertir Saldo a Favor (U3 y U4) y el Traductor de Errores (U6).
/// </summary>
public class AplicacionYReversaSaldoTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public AplicacionYReversaSaldoTests(PagosApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseRestClient.Reset();
    }

    // =========================================================================
    // APLICAR SALDO A FAVOR (Casos 1 a 5)
    // =========================================================================

    // Caso 1: Admin aplica saldo a cargo de su condominio => 200 con movimiento, cargo y saldo_a_favor, y la RPC recibe p_actor_id del token.
    [Fact]
    public async Task Caso01_AplicarSaldo_AdminValido_Retorna200ConPayloadYRpcRecibeActorId()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                NumeroCasa = "101",
                CondominioNombre = "Haven Towers",
                Monto = 1000m,
                MontoPagadoConfirmado = 200m,
                SaldoPendiente = 800m,
                Estado = EstadoCargo.Pendiente
            });

        object? rpcPayloadCapturado = null;
        Guid? actorRpcCapturado = null;

        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{movimientoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""tipo"": ""Aplicacion"",
                ""monto"": 300.50,
                ""monto_con_signo"": -300.50,
                ""cargo_id"": ""{cargoId}"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T18:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""condominio_nombre"": ""Haven Towers"",
                ""vivienda_id"": 10,
                ""numero_casa"": ""101"",
                ""monto"": 1000.0,
                ""monto_pagado_confirmado"": 500.50,
                ""saldo_pendiente"": 499.50,
                ""estado"": ""Pendiente"",
                ""tipo"": ""Mantenimiento"",
                ""concepto"": ""Cuota octubre"",
                ""fecha_vencimiento"": ""2026-10-31""
            }},
            ""saldo_a_favor"": 199.50
        }}";

        using var jsonDoc = JsonDocument.Parse(jsonResponse);

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actor) =>
            {
                rpcPayloadCapturado = payload;
                actorRpcCapturado = actor;
            })
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new AplicarSaldoFavorRequest { Monto = 300.50m };
        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, actorRpcCapturado);

        var dict = Assert.IsAssignableFrom<IDictionary<string, object?>>(rpcPayloadCapturado);
        Assert.Equal(cargoId, dict["p_cargo_id"]);
        Assert.Equal(300.50m, dict["p_monto"]);
        Assert.Equal(adminId, dict["p_actor_id"]);

        var resultado = await response.Content.ReadFromJsonAsync<AplicarSaldoFavorResponse>();
        Assert.NotNull(resultado);
        Assert.NotNull(resultado.Movimiento);
        Assert.Equal(movimientoId, resultado.Movimiento.Id);
        Assert.NotNull(resultado.Cargo);
        Assert.Equal(cargoId, resultado.Cargo.Id);
        Assert.Equal(499.50m, resultado.Cargo.SaldoPendiente);
        Assert.Equal(199.50m, resultado.SaldoAFavor);
    }

    // Caso 2: Cargo de otro condominio => 404 sin llamar a la RPC.
    [Fact]
    public async Task Caso02_AplicarSaldo_CargoOtroCondominio_Retorna404SinLlamarRpc()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = otroCondominioId,
                ViviendaId = 15,
                NumeroCasa = "15-B",
                Monto = 1000m
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 100m });
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    // Caso 3: Inquilino o subusuario => 403.
    [Fact]
    public async Task Caso03_AplicarSaldo_InquilinoOSubusuario_Retorna403Forbidden()
    {
        var cargoId = Guid.NewGuid();
        var request = new AplicarSaldoFavorRequest { Monto = 100m };

        // 3.a Inquilino => 403
        var clientInquilino = _factory.CreateClient();
        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken();
        clientInquilino.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);
        var resInquilino = await clientInquilino.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", request);
        Assert.Equal(HttpStatusCode.Forbidden, resInquilino.StatusCode);

        // 3.b Subusuario => 403
        var clientSub = _factory.CreateClient();
        var tokenSub = TestTokenGenerator.GenerateSubusuarioToken();
        clientSub.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenSub);
        var resSub = await clientSub.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", request);
        Assert.Equal(HttpStatusCode.Forbidden, resSub.StatusCode);
    }

    // Caso 4: Monto cero, negativo o con 3 decimales => 400.
    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    [InlineData(-0.01)]
    [InlineData(100.123)]
    [InlineData(50.999)]
    public async Task Caso04_AplicarSaldo_MontoInvalido_Retorna400SinLlamarRpc(decimal montoInvalido)
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = montoInvalido });
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    // Caso 5: La RPC responde PG007 => 409 (saldo insuficiente). PG008 => 409. PG010 => 409. PG001 => 409.
    [Theory]
    [InlineData("PG007", "Saldo a favor insuficiente")]
    [InlineData("PG008", "El monto es inválido o mayor al saldo pendiente del cargo")]
    [InlineData("PG010", "El cargo ya está pagado")]
    [InlineData("PG001", "El cargo está cancelado o el estado no permite la operación")]
    public async Task Caso05_AplicarSaldo_RpcRespondeErroresDeNegocio_Retorna409Conflict(string sqlState, string mensajeEsperado)
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                NumeroCasa = "101",
                Monto = 1000m,
                SaldoPendiente = 500m,
                Estado = EstadoCargo.Pendiente
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_aplicar_saldo_favor", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, sqlState, mensajeEsperado));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/cargos/{cargoId}/aplicar-saldo", new AplicarSaldoFavorRequest { Monto = 500m });
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Equal(mensajeEsperado, err.Error);
    }

    // =========================================================================
    // REVERTIR APLICACIÓN DE SALDO (Casos 6 a 10)
    // =========================================================================

    // Caso 6: Admin revierte una Aplicacion de su condominio con motivo => 200.
    [Fact]
    public async Task Caso06_RevertirAplicacion_AdminValido_Retorna200ConReversoCargoYSaldo()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var reversoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 10,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 300m,
                CargoId = cargoId
            });

        object? rpcPayloadCapturado = null;
        Guid? actorRpcCapturado = null;

        var jsonResponse = $@"{{
            ""movimiento"": {{
                ""id"": ""{reversoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""vivienda_id"": 10,
                ""tipo"": ""ReversoAplicacion"",
                ""monto"": 300.0,
                ""monto_con_signo"": 300.0,
                ""cargo_id"": ""{cargoId}"",
                ""movimiento_origen_id"": ""{movimientoId}"",
                ""motivo"": ""Reversión por error administrativo"",
                ""creado_por"": ""{adminId}"",
                ""creado_en"": ""2026-10-21T19:00:00Z""
            }},
            ""cargo"": {{
                ""id"": ""{cargoId}"",
                ""condominio_id"": ""{condominioId}"",
                ""condominio_nombre"": ""Haven Towers"",
                ""vivienda_id"": 10,
                ""numero_casa"": ""101"",
                ""tipo"": ""Mantenimiento"",
                ""concepto"": ""Cuota octubre"",
                ""monto"": 1000.0,
                ""monto_pagado_confirmado"": 0.0,
                ""saldo_pendiente"": 1000.0,
                ""estado"": ""Pendiente"",
                ""fecha_vencimiento"": ""2026-10-31""
            }},
            ""saldo_a_favor"": 500.00
        }}";

        using var jsonDoc = JsonDocument.Parse(jsonResponse);

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_revertir_aplicacion_saldo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .Callback<string, object, Guid?>((_, payload, actor) =>
            {
                rpcPayloadCapturado = payload;
                actorRpcCapturado = actor;
            })
            .ReturnsAsync(jsonDoc.RootElement);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new RevertirAplicacionSaldoRequest { Motivo = "Reversión por error administrativo" };
        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.NotNull(rpcPayloadCapturado);
        Assert.Equal(adminId, actorRpcCapturado);

        var dict = Assert.IsAssignableFrom<IDictionary<string, object?>>(rpcPayloadCapturado);
        Assert.Equal(movimientoId, dict["p_movimiento_id"]);
        Assert.Equal("Reversión por error administrativo", dict["p_motivo"]);
        Assert.Equal(adminId, dict["p_actor_id"]);

        var resultado = await response.Content.ReadFromJsonAsync<RevertirAplicacionSaldoResponse>();
        Assert.NotNull(resultado);
        Assert.NotNull(resultado.Movimiento);
        Assert.Equal(reversoId, resultado.Movimiento.Id);
        Assert.Equal(TipoMovimientoSaldo.ReversoAplicacion, resultado.Movimiento.Tipo);
        Assert.NotNull(resultado.Cargo);
        Assert.Equal(cargoId, resultado.Cargo.Id);
        Assert.Equal(500.00m, resultado.SaldoAFavor);
    }

    // Caso 7: Movimiento de otro condominio => 404 sin llamar a la RPC.
    [Fact]
    public async Task Caso07_RevertirAplicacion_MovimientoOtroCondominio_Retorna404SinLlamarRpc()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = otroCondominioId,
                ViviendaId = 1,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 100m
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión de prueba"
        });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        _factory.MockSupabaseRestClient.Verify(
            c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    // Caso 8: Movimiento de tipo Abono, ReversoAbono o ReversoAplicacion => 409 sin llamar a la RPC.
    [Theory]
    [InlineData(TipoMovimientoSaldo.Abono)]
    [InlineData(TipoMovimientoSaldo.ReversoAbono)]
    [InlineData(TipoMovimientoSaldo.ReversoAplicacion)]
    public async Task Caso08_RevertirAplicacion_TipoNoAplicacion_Retorna409SinLlamarRpc(TipoMovimientoSaldo tipoInvalido)
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = tipoInvalido,
                Monto = 200m
            });

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Intento de reversa sobre movimiento inválido"
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        _factory.MockSupabaseRestClient.Verify(
            c => c.RpcAsync<JsonElement>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    // Caso 9: La RPC responde PG009 => 409.
    [Fact]
    public async Task Caso09_RevertirAplicacion_RpcRespondePG009_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var cargoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwMovimientoSaldoFavor>("vw_movimientos_saldo_favor", $"id=eq.{movimientoId}"))
            .ReturnsAsync(new VwMovimientoSaldoFavor
            {
                Id = movimientoId,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoMovimientoSaldo.Aplicacion,
                Monto = 200m,
                CargoId = cargoId
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.RpcAsync<JsonElement>("rpc_revertir_aplicacion_saldo", It.IsAny<object>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(409, "PG009", "El movimiento no se puede revertir"));

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión de prueba PG009"
        });

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    // Caso 10: Sin motivo o motivo corto => 400. Inquilino => 403.
    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("1234")] // 4 caracteres (mínimo 5)
    public async Task Caso10a_RevertirAplicacion_SinMotivoOMotivoCorto_Retorna400BadRequest(string motivoInvalido)
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = motivoInvalido
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Caso10b_RevertirAplicacion_Inquilino_Retorna403Forbidden()
    {
        var movimientoId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateInquilinoToken();

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsJsonAsync($"/api/saldos/movimientos/{movimientoId}/revertir", new RevertirAplicacionSaldoRequest
        {
            Motivo = "Reversión no autorizada"
        });

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }
}

/// <summary>
/// Pruebas unitarias para el Traductor de Errores de PostgREST (Caso 11).
/// </summary>
public class PostgrestErrorTranslatorTests
{
    // Caso 11.a: Códigos PG001 a PG010 se traducen a 409 con su mensaje en español
    [Theory]
    [InlineData("PG001", "El cargo está cancelado o el estado no permite la operación")]
    [InlineData("PG002", "El pago no está pendiente de confirmación")]
    [InlineData("PG003", "El pago no se encuentra en estado PendienteConfirmacion para ser rechazado")]
    [InlineData("PG004", "Solo se pueden anular pagos confirmados")]
    [InlineData("PG005", "El cargo ya está cancelado")]
    [InlineData("PG006", "No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes")]
    [InlineData("PG007", "Saldo a favor insuficiente")]
    [InlineData("PG008", "El monto es inválido o mayor al saldo pendiente del cargo")]
    [InlineData("PG009", "El movimiento no se puede revertir")]
    [InlineData("PG010", "El cargo ya está pagado")]
    public void Traducir_CodigosPG001APG010_TraduceA409ConMensajeEspanol(string code, string mensajeEsperado)
    {
        var resultado = PostgrestErrorTranslator.Traducir(code);

        Assert.Equal(409, resultado.StatusCode);
        Assert.Equal(mensajeEsperado, resultado.MensajeUsuario);
    }

    // Caso 11.b: PG000 se traduce a 404
    [Fact]
    public void Traducir_CodigoPG000_TraduceA404()
    {
        var resultado = PostgrestErrorTranslator.Traducir("PG000");

        Assert.Equal(404, resultado.StatusCode);
        Assert.Equal("El recurso solicitado no fue encontrado.", resultado.MensajeUsuario);
    }

    // Caso 11.c: 23505 se traduce a 409
    [Fact]
    public void Traducir_Codigo23505_TraduceA409()
    {
        var resultado = PostgrestErrorTranslator.Traducir("23505");

        Assert.Equal(409, resultado.StatusCode);
        Assert.False(string.IsNullOrWhiteSpace(resultado.MensajeUsuario));
    }

    // Caso 11.d: 23503, 23514, 23502 se traducen a 400
    [Theory]
    [InlineData("23503")]
    [InlineData("23514")]
    [InlineData("23502")]
    public void Traducir_CodigosValidacion_TraduceA400(string code)
    {
        var resultado = PostgrestErrorTranslator.Traducir(code);

        Assert.Equal(400, resultado.StatusCode);
    }

    // Caso 11.e: Código desconocido se traduce a 500 sin detalles
    [Theory]
    [InlineData("UNKNOWN")]
    [InlineData("99999")]
    [InlineData("XYZ12")]
    [InlineData("")]
    [InlineData(null)]
    public void Traducir_CodigoDesconocido_TraduceA500SinDetalles(string? codeDesconocido)
    {
        var resultado = PostgrestErrorTranslator.Traducir(codeDesconocido, details: "información interna sensible");

        Assert.Equal(500, resultado.StatusCode);
        Assert.Equal("Ocurrió un error interno en el servidor.", resultado.MensajeUsuario);
    }
}
