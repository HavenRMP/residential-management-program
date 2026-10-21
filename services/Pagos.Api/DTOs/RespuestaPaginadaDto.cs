using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO genérico de respuesta paginada.
/// </summary>
/// <typeparam name="T">Tipo del elemento en la lista.</typeparam>
public class RespuestaPaginadaDto<T>
{
    [JsonPropertyName("items")]
    public List<T> Items { get; set; } = new();

    [JsonPropertyName("total")]
    public int Total { get; set; }

    [JsonPropertyName("pagina")]
    public int Pagina { get; set; }

    [JsonPropertyName("tamanoPagina")]
    public int TamanoPagina { get; set; }

    [JsonPropertyName("totalCount")]
    public int TotalCount => Total;

    [JsonPropertyName("page")]
    public int Page => Pagina;

    [JsonPropertyName("pageSize")]
    public int PageSize => TamanoPagina;

    [JsonPropertyName("totalPages")]
    public int TotalPages => TamanoPagina > 0 ? (int)Math.Ceiling(Total / (double)TamanoPagina) : 0;

    public RespuestaPaginadaDto() { }

    public RespuestaPaginadaDto(List<T> items, int total, int pagina, int tamanoPagina)
    {
        Items = items ?? new List<T>();
        Total = total;
        Pagina = pagina;
        TamanoPagina = tamanoPagina;
    }

    public static RespuestaPaginadaDto<T> Crear(List<T> items, int total, ParametrosPaginacionDto parametros)
    {
        return new RespuestaPaginadaDto<T>(items, total, parametros.Pagina, parametros.TamanoPagina);
    }

    public static RespuestaPaginadaDto<T> CrearVacia(ParametrosPaginacionDto parametros)
    {
        return new RespuestaPaginadaDto<T>(new List<T>(), 0, parametros.Pagina, parametros.TamanoPagina);
    }
}
