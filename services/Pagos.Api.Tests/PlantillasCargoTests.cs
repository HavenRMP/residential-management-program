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

    [Fact]
    public async Task PutPlantilla_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var id = Guid.NewGuid();
        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo Concepto",
            Monto = 1800m,
            DiaVencimiento = 15
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task PutPlantilla_Inquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo Concepto",
            Monto = 1800m,
            DiaVencimiento = 15
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task PutPlantilla_NoExisteOOtroCondominio_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        // Devuelve null o plantilla de otro condominio
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync((VwPlantillaCargo?)null);

        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo Concepto",
            Monto = 1800m,
            DiaVencimiento = 15
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task PutPlantilla_VigenciaFinAnteriorAInicio_Retorna400BadRequest()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                VigenciaInicio = new DateOnly(2026, 6, 1)
            });

        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo Concepto",
            Monto = 1800m,
            DiaVencimiento = 15,
            VigenciaFin = new DateOnly(2026, 5, 31) // Anterior a VigenciaInicio
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task PutPlantilla_CambioConceptoDuplicado_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                ViviendaId = 10,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Concepto Anterior",
                Activa = true,
                VigenciaInicio = new DateOnly(2026, 1, 1)
            });

        // Ya existe otra plantilla activa con el nuevo concepto
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("concepto=eq.Nuevo%20Concepto") && q.Contains("activa=eq.true"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 10, Concepto = "Nuevo Concepto", Activa = true }
            });

        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Nuevo Concepto",
            Monto = 1800m,
            DiaVencimiento = 15
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task PutPlantilla_Exitoso_ActualizaYRetorna200Ok()
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
            CondominioNombre = "Residencial Las Palmas",
            ViviendaId = 10,
            NumeroCasa = "10A",
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Inicial",
            Monto = 1500m,
            DiaVencimiento = 5,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            Activa = true,
            CreadoPor = adminId,
            CreadoEn = DateTimeOffset.UtcNow
        };

        var plantillaActualizada = new VwPlantillaCargo
        {
            Id = id,
            CondominioId = condominioId,
            CondominioNombre = "Residencial Las Palmas",
            ViviendaId = 10,
            NumeroCasa = "10A",
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota Actualizada",
            Monto = 1750m,
            DiaVencimiento = 15,
            VigenciaInicio = new DateOnly(2026, 1, 1),
            VigenciaFin = new DateOnly(2026, 12, 31),
            ResponsablePago = ResponsablePago.Propietario,
            Activa = true,
            CreadoPor = adminId,
            CreadoEn = DateTimeOffset.UtcNow,
            ModificadoPor = adminId,
            ModificadoEn = DateTimeOffset.UtcNow
        };

        var calls = 0;
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(() => calls++ == 0 ? plantillaOriginal : plantillaActualizada);

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("concepto=eq."))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        _factory.MockSupabaseRestClient
            .Setup(c => c.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                It.IsAny<object>(),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult> { new() { Id = id } });

        var request = new ActualizarPlantillaCargoRequest
        {
            Concepto = "Cuota Actualizada",
            Monto = 1750m,
            DiaVencimiento = 15,
            VigenciaFin = new DateOnly(2026, 12, 31),
            ResponsablePago = ResponsablePago.Propietario
        };

        var response = await client.PutAsJsonAsync($"/api/plantillas-cargo/{id}", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<PlantillaResponse>();
        Assert.NotNull(body);
        Assert.Equal("Cuota Actualizada", body.Concepto);
        Assert.Equal(1750m, body.Monto);
        Assert.Equal(15, body.DiaVencimiento);
        Assert.Equal(new DateOnly(2026, 12, 31), body.VigenciaFin);
        Assert.Equal(ResponsablePago.Propietario, body.ResponsablePago);
    }

    [Fact]
    public async Task DesactivarPlantilla_YaDesactivada_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                Activa = false // Ya está inactiva
            });

        var response = await client.PostAsync($"/api/plantillas-cargo/{id}/desactivar", null);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task DesactivarPlantilla_Exitoso_DesactivaYRetorna200Ok()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        var calls = 0;
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(() => new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                Activa = calls++ == 0, // Primero true, luego false
                Concepto = "Cuota Mantenimiento"
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                It.IsAny<object>(),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult> { new() { Id = id } });

        var response = await client.PostAsync($"/api/plantillas-cargo/{id}/desactivar", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<PlantillaResponse>();
        Assert.NotNull(body);
        Assert.False(body.Activa);
    }

    [Fact]
    public async Task ActivarPlantilla_YaActiva_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                Activa = true // Ya está activa
            });

        var response = await client.PostAsync($"/api/plantillas-cargo/{id}/activar", null);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task ActivarPlantilla_ChoqueUnicidad23505_Retorna409Conflict()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                ViviendaId = 5,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Activa = false
            });

        // Simula otra plantilla activa existente
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("concepto=eq.Cuota"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = Guid.NewGuid(), ViviendaId = 5, Tipo = TipoCargo.Mantenimiento, Concepto = "Cuota", Activa = true }
            });

        var response = await client.PostAsync($"/api/plantillas-cargo/{id}/activar", null);
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task ActivarPlantilla_Exitoso_ActivaYRetorna200Ok()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id = Guid.NewGuid();
        var calls = 0;
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                $"id=eq.{id}"))
            .ReturnsAsync(() => new VwPlantillaCargo
            {
                Id = id,
                CondominioId = condominioId,
                ViviendaId = 5,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Activa = calls++ != 0 // Primero false, luego true
            });

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains("activa=eq.true") && q.Contains("concepto=eq.Cuota"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        _factory.MockSupabaseRestClient
            .Setup(c => c.PatchAsync<PlantillaInsertResult>(
                "plantillas_cargo",
                $"id=eq.{id}",
                It.IsAny<object>(),
                adminId))
            .ReturnsAsync(new List<PlantillaInsertResult> { new() { Id = id } });

        var response = await client.PostAsync($"/api/plantillas-cargo/{id}/activar", null);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var body = await response.Content.ReadFromJsonAsync<PlantillaResponse>();
        Assert.NotNull(body);
        Assert.True(body.Activa);
    }

    [Fact]
    public async Task GenerarCargosLote_SinToken_Retorna401Unauthorized()
    {
        var client = _factory.CreateClient();
        var request = new GenerarCargosLoteRequest { Periodo = "2026-11" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GenerarCargosLote_Inquilino_Retorna403Forbidden()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateInquilinoToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new GenerarCargosLoteRequest { Periodo = "2026-11" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("2026")]
    [InlineData("2026-13")]
    [InlineData("2026-00")]
    [InlineData("noviembre-2026")]
    public async Task GenerarCargosLote_PeriodoInvalido_Retorna400BadRequest(string periodoInvalido)
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var request = new GenerarCargosLoteRequest { Periodo = periodoInvalido };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }

    [Fact]
    public async Task GenerarCargosLote_PeriodoMasDe3MesesAnticipacion_Retorna400BadRequest()
    {
        var client = _factory.CreateClient();
        var token = TestTokenGenerator.GenerateAdminToken();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Si hoy es alrededor de 2026-10, 2027-04 o superior excede 3 meses de anticipación
        var request = new GenerarCargosLoteRequest { Periodo = "2028-01" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains("anticipación", err.Error, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task GenerarCargosLote_PeriodoPasado_SePermiteYNoDaErrorDeAnticipacion()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Sin plantillas activas
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo>());

        var request = new GenerarCargosLoteRequest { Periodo = "2024-01" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
    }

    [Fact]
    public async Task GenerarCargosLote_FiltroPlantillaNoEsDeCondominio_Retorna404NotFound()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var id1 = Guid.NewGuid();
        var id2 = Guid.NewGuid();

        // Solo id1 pertenece al condominio, id2 no existe o es de otro
        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo>
            {
                new() { Id = id1, CondominioId = condominioId, Activa = true }
            });

        var request = new GenerarCargosLoteRequest
        {
            Periodo = "2026-11",
            PlantillaIds = new List<Guid> { id1, id2 }
        };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var err = await response.Content.ReadFromJsonAsync<ErrorResponseDto>();
        Assert.NotNull(err);
        Assert.Contains(id2.ToString(), err.Error);
    }

    [Fact]
    public async Task GenerarCargosLote_SinCandidatasVigentes_Retorna200ConConteosEnCeroSinInsert()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Plantilla cuya vigencia empieza después del periodo (ej. periodo 2026-05, inicio 2026-06-01)
        var plantilla = new VwPlantillaCargo
        {
            Id = Guid.NewGuid(),
            CondominioId = condominioId,
            ViviendaId = 1,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota",
            Monto = 1000m,
            DiaVencimiento = 10,
            VigenciaInicio = new DateOnly(2026, 6, 1),
            Activa = true
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(new List<VwPlantillaCargo> { plantilla });

        var request = new GenerarCargosLoteRequest { Periodo = "2026-05" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Equal(0, result.OmitidosPorYaExistir);
        Assert.Equal(1, result.OmitidosPorVigencia);
        Assert.Empty(result.Cargos);

        // Verifica que NUNCA se llamó a InsertManyIgnoreDuplicatesAsync
        _factory.MockSupabaseRestClient.Verify(
            c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                It.IsAny<string>(),
                It.IsAny<IEnumerable<object>>(),
                It.IsAny<string>(),
                It.IsAny<Guid?>()),
            Times.Never);
    }

    [Fact]
    public async Task GenerarCargosLote_ExitosoIdempotente_CalculaVencimientoCorrectoEInserta()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Plantilla con día 31 en febrero => fecha_vencimiento debe ser 28 (en 2026 no bisiesto)
        var plantilla1Id = Guid.NewGuid();
        var plantilla2Id = Guid.NewGuid();

        var plantillas = new List<VwPlantillaCargo>
        {
            new()
            {
                Id = plantilla1Id,
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota Febrero",
                Monto = 1200m,
                DiaVencimiento = 31, // Día 31
                VigenciaInicio = new DateOnly(2026, 1, 1),
                Activa = true
            },
            new()
            {
                Id = plantilla2Id,
                CondominioId = condominioId,
                ViviendaId = 2,
                Tipo = TipoCargo.Servicio,
                Concepto = "Consumo Agua",
                Monto = 500m,
                DiaVencimiento = 15,
                VigenciaInicio = new DateOnly(2026, 1, 1),
                Activa = true
            }
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(plantillas);

        var cargo1Id = Guid.NewGuid();
        var cargo2Id = Guid.NewGuid();

        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.Is<IEnumerable<object>>(data => data.Cast<CargoInsert>().Any(c => c.FechaVencimiento == new DateOnly(2026, 2, 28))),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>
            {
                new() { Id = cargo1Id, ViviendaId = 1, Monto = 1200m, FechaVencimiento = new DateOnly(2026, 2, 28) },
                new() { Id = cargo2Id, ViviendaId = 2, Monto = 500m, FechaVencimiento = new DateOnly(2026, 2, 15) }
            });

        var request = new GenerarCargosLoteRequest { Periodo = "2026-02" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(2, result.Creados);
        Assert.Equal(0, result.OmitidosPorYaExistir);
        Assert.Equal(0, result.OmitidosPorVigencia);
        Assert.Equal(2, result.Cargos.Count);
        Assert.Equal(new DateOnly(2026, 2, 28), result.Cargos[0].FechaVencimiento);
    }

    [Fact]
    public async Task GenerarCargosLote_CorrerSegundaVez_OmitidosPorYaExistirReflejaDuplicados()
    {
        _factory.MockSupabaseRestClient.Reset();
        var adminId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var token = TestTokenGenerator.GenerateAdminToken(adminId, condominioId);

        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var plantillas = new List<VwPlantillaCargo>
        {
            new()
            {
                Id = Guid.NewGuid(),
                CondominioId = condominioId,
                ViviendaId = 1,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Monto = 1000m,
                DiaVencimiento = 5,
                VigenciaInicio = new DateOnly(2026, 1, 1),
                Activa = true
            },
            new()
            {
                Id = Guid.NewGuid(),
                CondominioId = condominioId,
                ViviendaId = 2,
                Tipo = TipoCargo.Mantenimiento,
                Concepto = "Cuota",
                Monto = 1000m,
                DiaVencimiento = 5,
                VigenciaInicio = new DateOnly(2026, 1, 1),
                Activa = true
            }
        };

        _factory.MockSupabaseRestClient
            .Setup(c => c.GetAsync<VwPlantillaCargo>(
                "vw_plantillas_cargo",
                It.Is<string>(q => q.Contains($"condominio_id=eq.{condominioId}"))))
            .ReturnsAsync(plantillas);

        // En la segunda ejecución, la BD ignora duplicados y devuelve lista vacía (0 cargos nuevos insertados)
        _factory.MockSupabaseRestClient
            .Setup(c => c.InsertManyIgnoreDuplicatesAsync<CargoCreadoItemResponse>(
                "cargos",
                It.IsAny<IEnumerable<object>>(),
                "plantilla_id,periodo",
                adminId))
            .ReturnsAsync(new List<CargoCreadoItemResponse>());

        var request = new GenerarCargosLoteRequest { Periodo = "2026-10" };

        var response = await client.PostAsJsonAsync("/api/plantillas-cargo/generar", request);
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var result = await response.Content.ReadFromJsonAsync<GenerarCargosLoteResponse>();
        Assert.NotNull(result);
        Assert.Equal(0, result.Creados);
        Assert.Equal(2, result.OmitidosPorYaExistir); // 2 candidatas - 0 insertados = 2 omitidos por ya existir
        Assert.Equal(0, result.OmitidosPorVigencia);
        Assert.Empty(result.Cargos);
    }
}
