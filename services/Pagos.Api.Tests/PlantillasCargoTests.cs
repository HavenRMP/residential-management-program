using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using HavenApi.Shared.Pagination;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Xunit;

namespace Pagos.Api.Tests;

public class PlantillasCargoTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public PlantillasCargoTests(PagosApiFactory factory)
    {
        _factory = factory;
        _factory.MockSupabaseRestClient.Reset();
    }

    [Fact]
    public async Task PostPlantillas_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento Mensual",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1500.50m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_ConRolInquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento Mensual",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1500.50m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-10)]
    [InlineData(100.555)]
    public async Task PostPlantillas_MontoInvalido_Retorna400BadRequest(decimal montoInvalido)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Cuota Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = montoInvalido,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_MontoIndividualInvalido_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Cuota Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1, Monto = -50m }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task PostPlantillas_ConceptoVacio_Retorna400BadRequest(string conceptoVacio)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = conceptoVacio,
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(32)]
    public async Task PostPlantillas_DiaVencimientoInvalido_Retorna400BadRequest(int dia)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = dia,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_VigenciaFinAnteriorAInicio_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 15,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            VigenciaFin = new DateOnly(2026, 10, 31),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_ViviendasVacia_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 15,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>()
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_ViviendasDuplicadas_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1000m,
            DiaVencimiento = 15,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 },
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PostPlantillas_ViviendaNoPerteneceACondominio_Retorna404NotFound()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Vivienda 1 existe, Vivienda 2 no existe en condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.Is<string>(q => q.Contains("id=eq.1"))))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>(
                "viviendas",
                It.Is<string>(q => q.Contains("id=eq.2"))))
            .ReturnsAsync((ViviendaItemDto?)null);

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1200m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(error);
        Assert.Contains("2", error.Error);
    }

    [Fact]
    public async Task PostPlantillas_PlantillaActivaYaExistente_Retorna409ConflictConViviendas()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Ambas viviendas pertenecen al condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // Coincidencia en vw_plantillas_cargo para vivienda 1
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("vivienda_id=in.(1,2)"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 1, Concepto = "Mantenimiento", Tipo = TipoCargo.Mantenimiento, Activa = true }
            });

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1200m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(error);
        Assert.Contains("1", error.Error);
    }

    [Fact]
    public async Task PostPlantillas_CondicionCarrera23505_Retorna409ConflictGenerico()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // No hay duplicados en el pre-chequeo
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>("vw_plantillas_cargo", It.IsAny<string>()))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        // Simula carrera en la BD lanzando 23505 en InsertManyAsync
        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyAsync<PlantillaInsertResult>("plantillas_cargo", It.IsAny<List<PlantillaCargoInsert>>(), It.IsAny<Guid?>()))
            .ThrowsAsync(new PostgrestException(
                409,
                "23505",
                "violates unique constraint idx_plantillas_vivienda_tipo_concepto_activa",
                constraintName: "idx_plantillas_vivienda_tipo_concepto_activa"));

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1200m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var error = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(error);
        Assert.NotEmpty(error.Error);
    }

    [Fact]
    public async Task PostPlantillas_Exitoso_CreaPlantillasYRetorna201()
    {
        _factory.MockSupabaseRestClient.Reset();

        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("viviendas", It.IsAny<string>()))
            .ReturnsAsync(new ViviendaItemDto { Id = 1 });

        // Pre-chequeo vacío
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var guid1 = Guid.NewGuid();
        var guid2 = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                It.IsAny<IEnumerable<object>>(),
                It.IsAny<Guid?>()))
            .ReturnsAsync(new List<PlantillaInsertResult>
            {
                new() { Id = guid1 },
                new() { Id = guid2 }
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.StartsWith("id=in."))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new()
                {
                    Id = guid1,
                    CondominioId = condominioId,
                    CondominioNombre = "Residencial Las Palmas",
                    ViviendaId = 1,
                    NumeroCasa = "101",
                    Tipo = TipoCargo.Mantenimiento,
                    Concepto = "Mantenimiento General",
                    Monto = 1500m,
                    DiaVencimiento = 10,
                    VigenciaInicio = new DateOnly(2026, 11, 1),
                    ResponsablePago = ResponsablePago.Propietario,
                    Activa = true,
                    CreadoPor = adminId,
                    CreadoEn = DateTimeOffset.UtcNow
                },
                new()
                {
                    Id = guid2,
                    CondominioId = condominioId,
                    CondominioNombre = "Residencial Las Palmas",
                    ViviendaId = 2,
                    NumeroCasa = "102",
                    Tipo = TipoCargo.Mantenimiento,
                    Concepto = "Mantenimiento General",
                    Monto = 2000m, // Monto sobreescrito
                    DiaVencimiento = 10,
                    VigenciaInicio = new DateOnly(2026, 11, 1),
                    ResponsablePago = ResponsablePago.Propietario,
                    Activa = true,
                    CreadoPor = adminId,
                    CreadoEn = DateTimeOffset.UtcNow
                }
            });

        var request = new CrearPlantillasCargoRequest
        {
            Concepto = "Mantenimiento General",
            Tipo = TipoCargo.Mantenimiento,
            Monto = 1500m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 11, 1),
            ResponsablePago = ResponsablePago.Propietario,
            Viviendas = new List<PlantillaViviendaItemDto>
            {
                new() { ViviendaId = 1 },
                new() { ViviendaId = 2, Monto = 2000m }
            }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo", request);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var plantillas = await response.Content.ReadFromJsonAsync<List<PlantillaResponse>>();
        Assert.NotNull(plantillas);
        Assert.Equal(2, plantillas.Count);
        Assert.Equal(1500m, plantillas[0].Monto);
        Assert.Equal(2000m, plantillas[1].Monto);
        Assert.True(plantillas[0].Activa);
        Assert.Equal("Residencial Las Palmas", plantillas[0].CondominioNombre);
    }

    [Fact]
    public async Task GetPlantillas_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/plantillas-cargo");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetPlantillas_Inquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/plantillas-cargo");
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task GetPlantillas_Admin_FiltraPorCondominioYRetornaPaginado200()
    {
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        var mockItems = new List<VwPlantillaCargo>
        {
            new()
            {
                Id = id,
                CondominioId = condominioId,
                CondominioNombre = "Residencial Las Palmas",
                ViviendaId = 1,
                NumeroCasa = "101",
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota Normal",
                Monto = 1500m,
                DiaVencimiento = 5,
                VigenciaInicio = new DateOnly(2026, 1, 1),
                Activa = true,
                CreadoPor = adminId,
                CreadoEn = DateTimeOffset.UtcNow
            }
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetPagedAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.IsAny<PaginationParams>(),
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}") && q.Contains("vivienda_id=eq.1") && q.Contains("activa=eq.true"))))
            .ReturnsAsync((mockItems, 1));

        var response = await client.GetAsync("/api/plantillas-cargo?vivienda_id=1&activa=true&pagina=1&tamano_pagina=20");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<RespuestaPaginadaDto<PlantillaResponse>>();
        Assert.NotNull(page);
        Assert.Single(page.Items);
        Assert.Equal(1, page.Total);
        Assert.Equal("101", page.Items[0].NumeroCasa);
        Assert.Equal("Cuota Normal", page.Items[0].Concepto);
    }
}
