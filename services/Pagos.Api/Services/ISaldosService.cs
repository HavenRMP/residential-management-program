using Pagos.Api.DTOs;

namespace Pagos.Api.Services;

/// <summary>
/// Contrato para el servicio de consulta de saldos por vivienda y por usuario.
/// </summary>
public interface ISaldosService
{
    /// <summary>
    /// Obtiene el saldo consolidado de una vivienda específica verificando permisos de acceso (Admin o Residente titular).
    /// </summary>
    Task<SaldoViviendaResponse> ObtenerSaldoPorViviendaAsync(int viviendaId);

    /// <summary>
    /// Obtiene la suma de saldos sobre las viviendas del usuario inquilino autenticado con su desglose por vivienda.
    /// </summary>
    Task<SaldoUsuarioResponse> ObtenerMiSaldoAsync();

    /// <summary>
    /// Obtiene la suma de saldos y desglose para un usuario dado, limitado exclusivamente a viviendas del condominio del administrador.
    /// </summary>
    Task<SaldoUsuarioResponse> ObtenerSaldoPorUsuarioAsync(Guid usuarioId);
}
