using System.Text.RegularExpressions;

namespace Pagos.Api.Utils;

/// <summary>
/// Utilidad para conversión y validación bidireccional entre el formato de texto año-mes de la API (YYYY-MM)
/// y el tipo DateOnly de la base de datos (siempre en el primer día del mes).
/// </summary>
public static partial class PeriodoHelper
{
    private static readonly Regex RegexPeriodo = new(@"^(?<anio>\d{4})-(?<mes>0[1-9]|1[0-2])$", RegexOptions.Compiled);

    public const int AnioMinimo = 2000;
    public const int AnioMaximo = 2100;

    /// <summary>
    /// Intenta parsear un texto con formato 'YYYY-MM' al primer día del mes correspondiente.
    /// </summary>
    public static bool TryParse(string? textoPeriodo, out DateOnly periodo, out string? error)
    {
        periodo = default;
        error = null;

        if (string.IsNullOrWhiteSpace(textoPeriodo))
        {
            error = "El periodo es obligatorio y debe tener formato YYYY-MM (ej. 2026-10).";
            return false;
        }

        var match = RegexPeriodo.Match(textoPeriodo.Trim());
        if (!match.Success)
        {
            error = "El formato del periodo es inválido. Debe tener la estructura YYYY-MM (ej. 2026-10).";
            return false;
        }

        var anio = int.Parse(match.Groups["anio"].Value);
        var mes = int.Parse(match.Groups["mes"].Value);

        if (anio < AnioMinimo || anio > AnioMaximo)
        {
            error = $"El año {anio} está fuera del rango permitido ({AnioMinimo}-{AnioMaximo}).";
            return false;
        }

        periodo = new DateOnly(anio, mes, 1);
        return true;
    }

    /// <summary>
    /// Convierte un texto con formato 'YYYY-MM' al primer día del mes correspondiente (DateOnly).
    /// Lanza ArgumentException si el formato o el rango no son válidos.
    /// </summary>
    public static DateOnly ADateOnly(string textoPeriodo)
    {
        if (!TryParse(textoPeriodo, out var periodo, out var error))
        {
            throw new ArgumentException(error, nameof(textoPeriodo));
        }

        return periodo;
    }

    /// <summary>
    /// Convierte un DateOnly al formato de texto año-mes de la API (YYYY-MM).
    /// </summary>
    public static string ATexto(DateOnly fecha)
    {
        return fecha.ToString("yyyy-MM");
    }

    /// <summary>
    /// Convierte un DateOnly opcional al formato de texto año-mes de la API (YYYY-MM).
    /// </summary>
    public static string? ATextoOpcional(DateOnly? fecha)
    {
        return fecha?.ToString("yyyy-MM");
    }

    /// <summary>
    /// Crea un DateOnly en el primer día del mes validando el rango permitido.
    /// </summary>
    public static DateOnly DesdeAnioYMes(int anio, int mes)
    {
        if (anio < AnioMinimo || anio > AnioMaximo)
        {
            throw new ArgumentOutOfRangeException(nameof(anio), $"El año {anio} debe estar entre {AnioMinimo} y {AnioMaximo}.");
        }

        if (mes < 1 || mes > 12)
        {
            throw new ArgumentOutOfRangeException(nameof(mes), $"El mes {mes} debe estar entre 1 y 12.");
        }

        return new DateOnly(anio, mes, 1);
    }
}
