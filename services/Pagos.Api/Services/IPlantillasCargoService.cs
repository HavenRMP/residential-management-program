using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

/// <summary>
/// Contrato para el servicio de gestión de plantillas de cargo recurrente por vivienda.
/// </summary>
public interface IPlantillasCargoService
{
    /// <summary>
    /// Da de alta de forma masiva y atómica una plantilla por cada vivienda indicada (exclusivo para Administrador).
    /// </summary>
    Task<List<PlantillaResponse>> CrearPlantillasMasivasAsync(CrearPlantillasCargoRequest request);

    /// <summary>
    /// Consulta el listado paginado de plantillas filtrando por el condominio del administrador.
    /// </summary>
    Task<RespuestaPaginadaDto<PlantillaResponse>> ListarPlantillasAsync(ConsultaPlantillasCargoFiltrosDto filtros);

    /// <summary>
    /// Actualiza los campos editables de una plantilla de cargo recurrente existente (exclusivo para Administrador).
    /// </summary>
    Task<PlantillaResponse> ActualizarPlantillaAsync(Guid id, ActualizarPlantillaCargoRequest request);

    /// <summary>
    /// Desactiva una plantilla de cargo activa existente (exclusivo para Administrador).
    /// </summary>
    Task<PlantillaResponse> DesactivarPlantillaAsync(Guid id);

    /// <summary>
    /// Activa una plantilla de cargo inactiva existente (exclusivo para Administrador).
    /// </summary>
    Task<PlantillaResponse> ActivarPlantillaAsync(Guid id);

    /// <summary>
    /// Genera de forma manual e idempotente un lote de cargos a partir de plantillas activas para un periodo determinado (exclusivo para Administrador).
    /// </summary>
    Task<GenerarCargosLoteResponse> GenerarCargosLoteAsync(GenerarCargosLoteRequest request);
}
