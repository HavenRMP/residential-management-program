using Microsoft.AspNetCore.Mvc;

namespace HavenApi.Shared.Pagination;


public class PaginationParams
{
    private int _page = 1;
    private int _pageSize = 20;


    [FromQuery(Name = "page")]
    public int Page
    {
        get => _page;
        set => _page = value < 1 ? 1 : value;
    }

    [FromQuery(Name = "pageSize")]
    public int PageSize
    {
        get => _pageSize;
        set => _pageSize = value < 1 ? 1 : (value > 100 ? 100 : value);
    }

    public (int Desde, int Hasta) ToRange()
    {
        int desde = (Page - 1) * PageSize;
        int hasta = desde + PageSize - 1;
        return (desde, hasta);
    }
}
