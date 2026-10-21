using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;

namespace Pagos.Api.DTOs;

/// <summary>
/// Modelo de petición multipart/form-data para subir un archivo de comprobante de pago.
/// </summary>
public class SubirComprobanteRequest
{
    /// <summary>
    /// Archivo del comprobante (JPG, PNG o PDF).
    /// </summary>
    [FromForm(Name = "archivo")]
    public IFormFile? Archivo { get; set; }

    /// <summary>
    /// Identificador entero de la vivienda a la que corresponde el comprobante.
    /// </summary>
    [FromForm(Name = "vivienda_id")]
    public int ViviendaId { get; set; }

    /// <summary>
    /// Alias camelCase para compatibilidad.
    /// </summary>
    [FromForm(Name = "viviendaId")]
    public int? ViviendaIdAlias
    {
        get => ViviendaId;
        set
        {
            if (value.HasValue && ViviendaId == 0)
            {
                ViviendaId = value.Value;
            }
        }
    }
}
