using System;
using System.Collections.Generic;

namespace HavenApi.Shared.Pagination;

/// <summary>
/// Resultado paginado genérico.
/// </summary>
/// <typeparam name="T">Tipo de los elementos de la lista.</typeparam>
public class PagedResult<T>
{
    /// <summary>
    /// Elementos de la página actual.
    /// </summary>
    public List<T> Items { get; set; } = new();

    /// <summary>
    /// Número de página actual.
    /// </summary>
    public int Page { get; set; }

    /// <summary>
    /// Tamaño de la página.
    /// </summary>
    public int PageSize { get; set; }

    /// <summary>
    /// Cantidad total de elementos en el origen de datos.
    /// </summary>
    public int? TotalCount { get; set; }

    /// <summary>
    /// Cantidad total de páginas calculadas.
    /// </summary>
    public int? TotalPages { get; set; }

    /// <summary>
    /// Crea una instancia de PagedResult a partir de los elementos, los parámetros de paginación y el conteo total.
    /// </summary>
    public static PagedResult<T> Create(List<T> items, PaginationParams parametros, int? totalCount)
    {
        int? totalPages = null;
        if (totalCount.HasValue)
        {
            totalPages = (int)Math.Ceiling(totalCount.Value / (double)parametros.PageSize);
        }

        return new PagedResult<T>
        {
            Items = items,
            Page = parametros.Page,
            PageSize = parametros.PageSize,
            TotalCount = totalCount,
            TotalPages = totalPages
        };
    }
}
