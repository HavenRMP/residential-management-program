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
}
