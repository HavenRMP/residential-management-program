using System.ComponentModel.DataAnnotations;

namespace Reservas.Api.Options;

public class PushWorkerOptions
{
    public const string SectionName = "PushWorker";

    public bool Enabled { get; set; } = true;

    [Range(5, 600, ErrorMessage = "El intervalo debe estar entre 5 y 600 segundos.")]
    public int IntervalSeconds { get; set; } = 30;

    [Range(1, 200, ErrorMessage = "El tamaño de lote debe estar entre 1 y 200.")]
    public int BatchSize { get; set; } = 50;
}
