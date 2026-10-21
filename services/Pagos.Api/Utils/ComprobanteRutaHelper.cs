namespace Pagos.Api.Utils;

/// <summary>
/// Utilitario para construir y validar rutas de comprobantes de pago dentro de Supabase Storage.
/// </summary>
public static class ComprobanteRutaHelper
{
    /// <summary>
    /// Construye una ruta con el formato: condominio_id/vivienda_id/año/mes/guid.extensión (guid nuevo por archivo).
    /// </summary>
    public static string ConstruirRuta(Guid condominioId, int viviendaId, int anio, int mes, string extension)
    {
        if (condominioId == Guid.Empty)
        {
            throw new ArgumentException("El id del condominio es obligatorio para construir la ruta.", nameof(condominioId));
        }

        if (viviendaId <= 0)
        {
            throw new ArgumentException("El id de la vivienda debe ser mayor a cero.", nameof(viviendaId));
        }

        if (anio < 2000 || anio > 2100)
        {
            throw new ArgumentOutOfRangeException(nameof(anio), "El año especificado está fuera de un rango válido.");
        }

        if (mes < 1 || mes > 12)
        {
            throw new ArgumentOutOfRangeException(nameof(mes), "El mes debe estar comprendido entre 1 y 12.");
        }

        if (string.IsNullOrWhiteSpace(extension))
        {
            throw new ArgumentException("La extensión del archivo es obligatoria.", nameof(extension));
        }

        var extensionLimpia = extension.Trim().TrimStart('.').ToLowerInvariant();
        if (string.IsNullOrWhiteSpace(extensionLimpia))
        {
            throw new ArgumentException("La extensión del archivo no puede estar vacía.", nameof(extension));
        }

        var archivoId = Guid.NewGuid();
        return $"{condominioId}/{viviendaId}/{anio}/{mes:D2}/{archivoId}.{extensionLimpia}";
    }

    /// <summary>
    /// Valida que la ruta de objeto no contenga caracteres de escape, barras iniciales o formatos inválidos.
    /// </summary>
    public static void ValidarRuta(string ruta)
    {
        if (string.IsNullOrWhiteSpace(ruta))
        {
            throw new ArgumentException("La ruta del objeto no puede estar vacía.", nameof(ruta));
        }

        if (ruta.StartsWith('/') || ruta.StartsWith('\\'))
        {
            throw new ArgumentException("La ruta del objeto no puede iniciar con barra.", nameof(ruta));
        }

        if (ruta.Contains(".."))
        {
            throw new ArgumentException("La ruta del objeto no puede contener segmentos de escape '..'.", nameof(ruta));
        }

        if (ruta.Contains('\\'))
        {
            throw new ArgumentException("La ruta del objeto no puede contener barras invertidas.", nameof(ruta));
        }
    }
}
