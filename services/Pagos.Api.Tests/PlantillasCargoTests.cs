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
using Xunit;

namespace Pagos.Api.Tests;

/// <summary>
/// Clase auxiliar para congelar y manipular el tiempo en pruebas de generación de cargos.
/// </summary>
public class FakeTimeProvider : TimeProvider
{
    private DateTimeOffset _utcNow;

    public FakeTimeProvider(DateTimeOffset utcNow)
    {
        _utcNow = utcNow;
    }

    public override DateTimeOffset GetUtcNow() => _utcNow;

    public void SetUtcNow(DateTimeOffset utcNow) => _utcNow = utcNow;
}

public class PlantillasCargoTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public PlantillasCargoTests(PagosApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseRestClient.Reset();
    }

    private HttpClient CrearClienteConTiempo(DateTimeOffset utcNow, string? token = null)
    {
        var fakeTime = new FakeTimeProvider(utcNow);
        var client = _factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                var descriptors = services.Where(d => d.ServiceType == typeof(TimeProvider)).ToList();
                foreach (var d in descriptors)
                {
                    services.Remove(d);
                }
                services.AddSingleton<TimeProvider>(fakeTime);
            });
        }).CreateClient();

        if (!string.IsNullOrEmpty(token))
        {
            client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        }

        return client;
    }

    // =========================================================================
    // ALTA MASIVA Y LISTADO (Casos 1 al 8)
    // =========================================================================

    [Fact]
    public async Task Caso01_AdminCreaPlantillasPara3Viviendas_Retorna201YUnaSolaInsercionMasiva()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Las 3 viviendas pertenecen al condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // Pre-chequeo sin duplicados
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var id1 = Guid.NewGuid();
        var id2 = Guid.NewGuid();
        var id3 = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                It.Is<IEnumerable<object>>(data => data.Count() == 3),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult>
            {
                new() { Id = id1 },
                new() { Id = id2 },
                new() { Id = id3 }
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.StartsWith("id=in."))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = id1, CondominioId = condominioId, ViviendaId = 1, Monto = 1000m, Concepto = "Mantenimiento", Tipo = TipoCargo.Mantenimiento, Activa = true },
                new() { Id = id2, CondominioId = condominioId, ViviendaId = 2, Monto = 1000m, Concepto = "Mantenimiento", Tipo = TipoCargo.Mantenimiento, Activa = true },
                new() { Id = id3, CondominioId = condominioId, ViviendaId = 3, Monto = 1000m, Concepto = "Mantenimiento", Tipo = TipoCargo.Mantenimiento, Activa = true }
            });

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 },
                new() { ViviendaId = 3 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var creadas = await response.Content.ReadFromJsonAsync<List<PlantillaResponse>>();
        Assert.NotNull(creadas);
        Assert.Equal(3, creadas.Count);

        // Verifica que se realizó exactamente UNA sola inserción masiva
        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                It.IsAny<IEnumerable<object>>(),
                adminId),
            Times.Once);
    }

    [Fact]
    public async Task Caso02_MontoPorViviendaReemplazaAlComun()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var id1 = Guid.NewGuid();
        var id2 = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                It.Is<IEnumerable<object>>(data =>
                    data.Cast<PlantillaCargoInsert>().Any(p => p.ViviendaId == 1 && p.Monto == 1000m) &&
                    data.Cast<PlantillaCargoInsert>().Any(p => p.ViviendaId == 2 && p.Monto == 1500m)),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult>
            {
                new() { Id = id1 },
                new() { Id = id2 }
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.StartsWith("id=in."))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = id1, CondominioId = condominioId, ViviendaId = 1, Monto = 1000m, Activa = true },
                new() { Id = id2, CondominioId = condominioId, ViviendaId = 2, Monto = 1500m, Activa = true }
            });

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Cuota General",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m, // Monto común
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }, // Toma común 1000m
                new() { ViviendaId = 2, Monto = 1500m } // Reemplaza con 1500m
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);

        var creadas = await response.Content.ReadFromJsonAsync<List<PlantillaResponse>>();
        Assert.NotNull(creadas);
        Assert.Equal(1000m, creadas[0].Monto);
        Assert.Equal(1500m, creadas[1].Monto);
    }

    [Fact]
    public async Task Caso03_UnaViviendaDeOtroCondominio_Retorna404YNoInsertaNada()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Vivienda 1 existe en condominio, Vivienda 99 es de otro condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.Is<string>(q => q.Contains("id=eq.1"))))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.Is<string>(q => q.Contains("id=eq.99"))))
            .ReturnsAsync((ViviendaItemDto?)null);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 99 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("99", err.Error);

        // No se insertó nada
        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyAsync<PlantillaInsertResult>(It.IsAny<string>(), It.IsAny<IEnumerable<object>>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    [Fact]
    public async Task Caso04_ViviendaConPlantillaActivaMismoTipoYConcepto_Retorna409YNoInsertaNada()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // Coincidencia para vivienda 2
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("concepto=eq.Mantenimiento"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 2, Concepto = "Mantenimiento", Tipo = TipoCargo.Mantenimiento, Activa = true }
            });

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("2", err.Error);

        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyAsync<PlantillaInsertResult>(It.IsAny<string>(), It.IsAny<IEnumerable<object>>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    [Fact]
    public async Task Caso05_BaseResponde23505AlInsertar_Retorna409Generico()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // Pre-chequeo pasa limpio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        // Carrera en BD lanza 23505
        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                It.IsAny<IEnumerable<object>>(),
                adminId))
            .ThrowsAsync(new PostgrestException(409, "23505", "violates unique constraint"));

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.NotEmpty(err.Error);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-100)]
    [InlineData(500.123)]
    public async Task Caso06_MontoInvalido_Retorna400BadRequest(decimal montoInvalido)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = montoInvalido,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto> { new() { ViviendaId = 1 } }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Caso06_ListaVaciaRepetidosOMasDe200_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Lista vacía
        var reqVacia = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>()
        };
        var resVacia = await client.PostAsJsonAsync("/api/plantillas-cargo", reqVacia);
        Assert.Equal(HttpStatusCode.BadRequest, resVacia.StatusCode);

        // Repetidos
        var reqRepetidos = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 1 }
            }
        };
        var resRepetidos = await client.PostAsJsonAsync("/api/plantillas-cargo", reqRepetidos);
        Assert.Equal(HttpStatusCode.BadRequest, resRepetidos.StatusCode);

        // Más de 200 viviendas
        var reqExcedente = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = Enumerable.Range(1, 201).Select(i => new PlantillaViviendaItemDto { ViviendaId = i }).ToList()
        };
        var resExcedente = await client.PostAsJsonAsync("/api/plantillas-cargo", reqExcedente);
        Assert.Equal(HttpStatusCode.BadRequest, resExcedente.StatusCode);
    }

    [Fact]
    public async Task Caso06_VigenciaFinMenorAInicio_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            VigenciaFin = new DateOnly(2026, 10, 31),
            Viviendas = new List<PlantillaViviendaItemDto> { new() { ViviendaId = 1 } }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task Caso07_InquilinoYSubusuario_Retornan403Forbidden()
    {
        var client = _factory.CreateClient();

        var tokenInquilino = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenInquilino);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto> { new() { ViviendaId = 1 } }
        };

        var resInquilino = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Forbidden, resInquilino.StatusCode);

        var tokenSubusuario = TestTokenGenerator.GenerateSubusuarioToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", tokenSubusuario);

        var resSubusuario = await client.PostAsJsonAsync("/api/plantillas-cargo", request);
        Assert.Equal(HttpStatusCode.Forbidden, resSubusuario.StatusCode);
    }

    [Fact]
    public async Task Caso08_ListadoSiempreFiltraPorCondominioDelAdmin()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync((new List<VwPlantillaCargo>(), 0));

        var response = await client.GetAsync("/api/plantillas-cargo");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        _factory.MockSupabaseRestClient.Verify(
            c => c.GetPagedAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))),
            Times.Once);
    }

    // =========================================================================
    // EDICIÓN (Casos 9 al 11)
    // =========================================================================

    [Fact]
    public async Task Caso09_EditarMonto_Retorna200YEnviaModificadoPorDelToken_CambiarViviendaNoTieneEfecto()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        var plantillaOriginal = new VwPlantillaCargo
        {
            Id = id,
            CondominioId = condominioId,
            ViviendaId = 1,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Inicial",
            Monto = 1000m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            Activa = true
        };

        var plantillaActualizada = new VwPlantillaCargo
        {
            Id = id,
            CondominioId = condominioId,
            ViviendaId = 1, // La vivienda permanece inalterada
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Inicial",
            Monto = 1350m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            Activa = true,
            ModificadoPor = adminId,
            ModificadoEn = DateTimeOffset.UtcNow
        };

        var calls = 0;
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>("vw_plantillas_cargo", $"id=eq.{id}"))
            .ReturnsAsync(() => calls++ == 0 ? plantillaOriginal : plantillaActualizada);

        _factory.MockSupabaseRestClient
            .Setup(c => c.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                It.IsAny<object>(),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult> { new() { Id = id } });

        // Enviar json que intenta cambiar vivienda_id y tipo (no están en el DTO)
        var jsonConCamposExtras = new
        {
            concepto = "Cuota Inicial",
            monto = 1350m,
            dia_vencimiento = 5,
            vivienda_id = 999, // Intentar cambiar vivienda
            tipo = "Multa"     // Intentar cambiar tipo
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", jsonConCamposExtras);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<PlantillaResponse>();
        Assert.NotNull(body);
        Assert.Equal(1350m, body.Monto);
        Assert.Equal(1, body.ViviendaId); // No cambió la vivienda
        Assert.Equal(TipoCargo.Mantenimiento, body.Tipo); // No cambió el tipo

        // Verifica que el patch envió el actorId correspondiente al token
        _factory.MockSupabaseRestClient.Verify(
            c => c.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                It.IsAny<object>(),
                adminId),
            Times.Once);
    }

    [Fact]
    public async Task Caso10_DesactivarYReactivar_ReactivarConOtraActivaEquivalenteRetorna409()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();

        // 1. Desactivar exitoso
        var callsDesactivar = 0;
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>("vw_plantillas_cargo", $"id=eq.{id}"))
            .ReturnsAsync(() => new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Activa = callsDesactivar++ == 0
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.PatchAsync<PlantillaInsertResult>("plantillas_cargo", $"id=eq.{id}", It.IsAny<object>(), adminId))
            .ReturnsAsync(new List<PlantillaInsertResult> { new() { Id = id } });

        var resDesactivar = await client.PostAsync($"/api/plantillas-cargo/{id}/desactivar", null);
        Assert.Equal(HttpStatusCode.OK, resDesactivar.StatusCode);

        // 2. Reactivar cuando choca con otra activa equivalente (23505) => 409
        _factory.MockSupabaseRestClient.Reset();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>("vw_plantillas_cargo", $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Activa = false
            });

        // Pre-chequeo encuentra otra plantilla activa equivalente
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("concepto=eq.Cuota"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 1, Concepto = "Cuota", Tipo = TipoCargo.Mantenimiento, Activa = true }
            });

        var resReactivarConflicto = await client.PostAsync($"/api/plantillas-cargo/{id}/activar", null);
        Assert.Equal(HttpStatusCode.Conflict, resReactivarConflicto.StatusCode);
    }

    [Fact]
    public async Task Caso11_PlantillaDeOtroCondominio_Retorna404()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>("vw_plantillas_cargo", $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = otroCondominioId, // Otro condominio
                Activa = true
            });

        // PUT => 404
        var resPut = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo",
            Monto = 1000m,
            DiaVencimiento = 5
        });
        Assert.Equal(HttpStatusCode.NotFound, resPut.StatusCode);

        // Desactivar => 404
        var resDesactivar = await client.PostAsync($"/api/plantillas-cargo/{id}/desactivar", null);
        Assert.Equal(HttpStatusCode.NotFound, resDesactivar.StatusCode);

        // Activar => 404
        var resActivar = await client.PostAsync($"/api/plantillas-cargo/{id}/activar", null);
        Assert.Equal(HttpStatusCode.NotFound, resActivar.StatusCode);
    }

    // =========================================================================
    // GENERACIÓN (con TimeProvider falso) (Casos 12 al 19)
    // =========================================================================

    [Fact]
    public async Task Caso12_DiaVencimiento31_FebreroNoBisiesto28_Bisiesto29_Abril30()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var plantillaId = Guid.NewGuid();
        var plantilla = new VwPlantillaCargo
        {
            Id = plantillaId,
            CondominioId = condominioId,
            ViviendaId = 1,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Mensual",
            Monto = 1200m,
            DiaVencimiento = 31, // Día 31
            VigenciaInicio = new DateOnly(2020, 1, 1),
            Activa = true
        };

        // 1. Febrero no bisiesto (2026) => 28
        // Configuramos TimeProvider congelado en 2026-02-01
        var clientNoBisiesto = CrearClienteConTiempo(new DateTimeOffset(2026, 2, 1, 12, 0, 0, TimeSpan.Zero), token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo> { plantilla });

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.Is<IEnumerable<object>>(data => data.Cast<CargoInsert>().Any(c => c.FechaVencimiento == new DateOnly(2026, 2, 28))),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 1, Monto = 1200m, FechaVencimiento = new DateOnly(2026, 2, 28) }
            });

        var res2026 = await clientNoBisiesto.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-02" });
        Assert.Equal(HttpStatusCode.OK, res2026.StatusCode);
        var body2026 = await res2026.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(body2026);
        Assert.Equal(new DateOnly(2026, 2, 28), body2026.Cargos[0].FechaVencimiento);

        // 2. Febrero bisiesto (2024) => 29
        var clientBisiesto = CrearClienteConTiempo(new DateTimeOffset(2024, 2, 1, 12, 0, 0, TimeSpan.Zero), token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.Is<IEnumerable<object>>(data => data.Cast<CargoInsert>().Any(c => c.FechaVencimiento == new DateOnly(2024, 2, 29))),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 1, Monto = 1200m, FechaVencimiento = new DateOnly(2024, 2, 29) }
            });

        var res2024 = await clientBisiesto.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2024-02" });
        Assert.Equal(HttpStatusCode.OK, res2024.StatusCode);
        var body2024 = await res2024.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(body2024);
        Assert.Equal(new DateOnly(2024, 2, 29), body2024.Cargos[0].FechaVencimiento);

        // 3. Abril (mes de 30 días) => 30
        var clientAbril = CrearClienteConTiempo(new DateTimeOffset(2026, 4, 1, 12, 0, 0, TimeSpan.Zero), token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.Is<IEnumerable<object>>(data => data.Cast<CargoInsert>().Any(c => c.FechaVencimiento == new DateOnly(2026, 4, 30))),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 1, Monto = 1200m, FechaVencimiento = new DateOnly(2026, 4, 30) }
            });

        var resAbril = await clientAbril.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-04" });
        Assert.Equal(HttpStatusCode.OK, resAbril.StatusCode);
        var bodyAbril = await resAbril.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(bodyAbril);
        Assert.Equal(new DateOnly(2026, 4, 30), bodyAbril.Cargos[0].FechaVencimiento);
    }

    [Fact]
    public async Task Caso13_PlantillaFueraDeVigencia_OmitidaYContadaComoTal()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = CrearClienteConTiempo(new DateTimeOffset(2026, 6, 1, 12, 0, 0, TimeSpan.Zero), token);

        var plantillaExpirada = new VwPlantillaCargo
        {
            Id = Guid.NewGuid(),
            CondominioId = condominioId,
            ViviendaId = 1,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Expirada",
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            VigenciaFin = new DateOnly(2026, 4, 30), // Venció antes de junio 2026
            Activa = true
        };

        var plantillaFutura = new VwPlantillaCargo
        {
            Id = Guid.NewGuid(),
            CondominioId = condominioId,
            ViviendaId = 2,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Futura",
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 7, 1), // Inicia después de junio 2026
            Activa = true
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo> { plantillaExpirada, plantillaFutura });

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-06" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Equal(0, result.OmitidosPorYaExistir);
        Assert.Equal(2, result.OmitidosPorVigencia); // Ambas fuera de vigencia
        Assert.Empty(result.Cargos);
    }

    [Fact]
    public async Task Caso14_PlantillaInactivaNoGenera()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = CrearClienteConTiempo(new DateTimeOffset(2026, 6, 1, 12, 0, 0, TimeSpan.Zero), token);

        var plantillaInactiva = new VwPlantillaCargo
        {
            Id = Guid.NewGuid(),
            CondominioId = condominioId,
            ViviendaId = 1,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Inactiva",
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            Activa = false // Inactiva
        };

        // Si se pide por filtro explícito una inactiva
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}") && q.Contains($"id=in.({plantillaInactiva.Id})"))))
            .ReturnsAsync(new List<VwPlantillaCargo> { plantillaInactiva });

        var request = new GenerarCargosLoteRequest
        {
            Periodo = "2026-06",
            PlantillaIds = new List<Guid> { plantillaInactiva.Id }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Empty(result.Cargos);

        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(It.IsAny<string>(), It.IsAny<IEnumerable<object>>(), It.IsAny<string>(), It.IsAny<Guid?>()),
            Times.Never);
    }

    [Fact]
    public async Task Caso15_SegundaEjecucionMismoPeriodo_InsercionDevuelveCeroFilas_TodasContadasComoYaExistentes()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = CrearClienteConTiempo(new DateTimeOffset(2026, 10, 1, 12, 0, 0, TimeSpan.Zero), token);

        var plantillas = new List<VwPlantillaCargo>
        {
            new() { Id = Guid.NewGuid(), CondominioId = condominioId, ViviendaId = 1, Tipo = TipoCargo.Mantenimiento, Concepto = "Cuota", Monto = 1000m, DiaVencimiento = 5, VigenciaInicio = new DateOnly(2026, 1, 1), Activa = true },
            new() { Id = Guid.NewGuid(), CondominioId = condominioId, ViviendaId = 2, Tipo = TipoCargo.Mantenimiento, Concepto = "Cuota", Monto = 1000m, DiaVencimiento = 5, VigenciaInicio = new DateOnly(2026, 1, 1), Activa = true }
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(plantillas);

        // La base de datos ignora duplicados y devuelve lista vacía
        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.IsAny<IEnumerable<object>>(),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>());

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-10" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Equal(2, result.OmitidosPorYaExistir); // 2 candidatas - 0 creados = 2 omitidos por ya existir
        Assert.Equal(0, result.OmitidosPorVigencia);
        Assert.Empty(result.Cargos);
    }

    [Fact]
    public async Task Caso16_PeriodoConMasDe3MesesAnticipacionRetorna400_PeriodoPasadoPermitido()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        // Fijamos fecha actual en México: 2026-10-15
        var fechaFija = new DateTimeOffset(2026, 10, 15, 12, 0, 0, TimeSpan.FromHours(-6));
        var client = CrearClienteConTiempo(fechaFija, token);

        // Periodo futuro: 2026-10 + 3 meses = 2027-01. 2027-02 es más de 3 meses => 400
        var resFuturoExcedido = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2027-02" });
        Assert.Equal(HttpStatusCode.BadRequest, resFuturoExcedido.StatusCode);

        var err = await resFuturoExcedido.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("anticipación", err.Error, StringComparison.OrdinalIgnoreCase);

        // Periodo dentro de 3 meses: 2027-01 => permitido (200)
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.IsAny<string>()))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var resDentroLimite = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2027-01" });
        Assert.Equal(HttpStatusCode.OK, resDentroLimite.StatusCode);

        // Periodo pasado: 2025-01 => permitido (200)
        var resPasado = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2025-01" });
        Assert.Equal(HttpStatusCode.OK, resPasado.StatusCode);
    }

    [Fact]
    public async Task Caso17_FiltroConPlantillaDeOtroCondominio_Retorna404()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var idPropio = Guid.NewGuid();
        var idAjeno = Guid.NewGuid();

        // El query con condominio_id=eq.{condominioId} solo devuelve la propia
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = idPropio, CondominioId = condominioId, Activa = true }
            });

        var request = new GenerarCargosLoteRequest
        {
            Periodo = "2026-11",
            PlantillaIds = new List<Guid> { idPropio, idAjeno }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains(idAjeno.ToString(), err.Error);
    }

    [Fact]
    public async Task Caso18_CargosGeneradosHeredanCamposDePlantillaYLiganPeriodoAlPrimerDiaDelMes()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var fechaFija = new DateTimeOffset(2026, 10, 1, 12, 0, 0, TimeSpan.Zero);
        var client = CrearClienteConTiempo(fechaFija, token);

        var plantillaId = Guid.NewGuid();
        var plantilla = new VwPlantillaCargo
        {
            Id = plantillaId,
            CondominioId = condominioId,
            ViviendaId = 42,
            Tipo = TipoCargo.Servicio,
            Concepto = "Vigilancia Especial",
            Monto = 850.50m,
            DiaVencimiento = 12,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            ResponsablePago = ResponsablePago.Residente,
            Activa = true
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo> { plantilla });

        List<CargoInsert>? cargosCapturados = null;

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.IsAny<IEnumerable<object>>(),
                "plantilla_id,periodo",
                adminId))
            .Callback<string, IEnumerable<object>, string, Guid?>((table, data, onConflict, actor) =>
            {
                cargosCapturados = data.Cast<CargoInsert>().ToList();
            })
            .ReturnsAsync(new List<CargoCreadoItemResponse>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 42, Monto = 850.50m, FechaVencimiento = new DateOnly(2026, 11, 12) }
            });

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-11" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        Assert.NotNull(cargosCapturados);
        Assert.Single(cargosCapturados);

        var cargo = cargosCapturados[0];
        Assert.Equal(condominioId, cargo.CondominioId);
        Assert.Equal(42, cargo.ViviendaId);
        Assert.Equal(plantillaId, cargo.PlantillaId);
        Assert.Equal(TipoCargo.Servicio, cargo.Tipo);
        Assert.Equal("Vigilancia Especial", cargo.Concepto);
        Assert.Equal(850.50m, cargo.Monto);
        Assert.Equal(ResponsablePago.Residente, cargo.ResponsablePago);
        Assert.Equal(new DateOnly(2026, 11, 1), cargo.Periodo); // Primer día del mes
        Assert.Equal(new DateOnly(2026, 11, 12), cargo.FechaVencimiento);
        Assert.Equal(adminId, cargo.CreadoPor);
    }

    [Fact]
    public async Task Caso19_SinCandidatasVigentes_Retorna200ConCerosYSinLlamarAlInsert()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = CrearClienteConTiempo(new DateTimeOffset(2026, 10, 1, 12, 0, 0, TimeSpan.Zero), token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", new GenerarCargosLoteRequest { Periodo = "2026-11" });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Equal(0, result.OmitidosPorYaExistir);
        Assert.Equal(0, result.OmitidosPorVigencia);
        Assert.Empty(result.Cargos);

        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                It.IsAny<string>(),
                It.IsAny<IEnumerable<object>>(),
                It.IsAny<string>(),
                It.IsAny<Guid?>()),
            Times.Never);
    }
}
