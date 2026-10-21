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
}
