using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

/// <summary>
/// Contrato del servicio de gestión de cargos residenciales.
/// </summary>
public interface ICargosService
{
    /// <summary>
    /// Crea un nuevo cargo manual para una vivienda del condominio del administrador autenticado.
    /// </summary>
    /// <param name="request">Datos del cargo a crear.</param>
    /// <returns>El cargo creado con sus campos calculados proyectados en <see cref="CargoResponse"/>.</returns>
    Task<CargoResponse> CrearCargoAsync(CrearCargoRequest request);

    /// <summary>
    /// Consulta el listado de cargos aplicando filtros por rol, pertenencia de vivienda y paginación.
    /// </summary>
    /// <param name="filtros">Filtros y parámetros de paginación.</param>
    /// <returns>Página con los cargos proyectados en <see cref="CargoResponse"/>.</returns>
    Task<RespuestaPaginadaDto<CargoResponse>> ListarCargosAsync(ConsultaCargosFiltrosDto filtros);

    /// <summary>
    /// Obtiene el detalle de un cargo específico con la lista de sus pagos asociados.
    /// Valida pertenencia de condominio (Admin) o titularidad de vivienda (Inquilino).
    /// </summary>
    /// <param name="id">ID único del cargo.</param>
    /// <returns>Detalle del cargo proyectado en <see cref="CargoDetalleResponse"/>.</returns>
    Task<CargoDetalleResponse> ObtenerDetalleCargoAsync(Guid id);
}
