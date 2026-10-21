using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc;

namespace Pagos.Api.DTOs;

/// <summary>
/// Parámetros de consulta para endpoints con paginación.
/// Página por defecto: 1. Tamaño por defecto: 20 (máximo: 100).
/// </summary>
public class ParametrosPaginacionDto
{
    private int _pagina = 1;
    private int _tamanoPagina = 20;

    [FromQuery(Name = "page")]
    public int? PageAlias
    {
        get => _pagina;
        set
        {
            if (value.HasValue)
            {
                Pagina = value.Value;
            }
        }
    }

    [FromQuery(Name = "pageSize")]
    public int? PageSizeAlias
    {
        get => _tamanoPagina;
        set
        {
            if (value.HasValue)
            {
                TamanoPagina = value.Value;
            }
        }
    }

    [FromQuery(Name = "pagina")]
    public int Pagina
    {
        get => _pagina;
        set => _pagina = value < 1 ? 1 : value;
    }

    [FromQuery(Name = "tamanoPagina")]
    public int TamanoPagina
    {
        get => _tamanoPagina;
        set => _tamanoPagina = value < 1 ? 1 : (value > 100 ? 100 : value);
    }

    public (int Desde, int Hasta) ToRange()
    {
        int desde = (Pagina - 1) * TamanoPagina;
        int hasta = desde + TamanoPagina - 1;
        return (desde, hasta);
    }

    public PaginationParams ToSharedParams()
    {
        return new PaginationParams
        {
            Page = Pagina,
            PageSize = TamanoPagina
        };
    }
}
