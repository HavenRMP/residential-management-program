using System.Text.Json.Serialization;

namespace Pagos.Api.Clients;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MotivoConflicto
{
    Generico = 0,
    Desconocido = 0,

    PagoReferenciaDuplicada = 1,
    PagoDuplicadoReferencia = 1,
    idx_pagos_anti_duplicado_ref = 1,

    ComprobanteDuplicado = 2,
    PagoComprobanteDuplicado = 2,
    PagoDuplicadoHash = 2,
    idx_pagos_anti_duplicado_hash = 2,

    CargoPlantillaPeriodoDuplicado = 3,
    CargoDuplicadoPlantillaPeriodo = 3,
    uq_cargos_plantilla_periodo = 3,

    PlantillaActivaDuplicada = 4,
    PlantillaDuplicadaActiva = 4,
    idx_plantillas_vivienda_tipo_concepto_activa = 4
}
