using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Pagos.Api.DTOs;
using Pagos.Api.Services;
using Pagos.Api.Utils;

namespace Pagos.Api.Controllers;

[ApiController]
[Route("api/comprobantes")]
[Authorize(Policy = "AdminOInquilino")]
public class ComprobantesController : ControllerBase
{
    private const long MaxFileSizeBytes = 5 * 1024 * 1024; // 5 MB

    // Tope del cuerpo HTTP completo. Es mayor que MaxFileSizeBytes para que el overhead
    // multipart no rechace archivos válidos y para que los archivos de 5-10 MB lleguen
    // al controlador y reciban 413 con mensaje claro (si el cuerpo excede el tope, ASP.NET responde 400 genérico).
    private const long MaxRequestBodyBytes = 10 * 1024 * 1024; // 10 MB

    private readonly IComprobanteProcessor _comprobanteProcessor;
    private readonly IComprobanteStorageService _comprobanteStorageService;
    private readonly IUserContextService _userContextService;
    private readonly IViviendasLookupService _viviendasLookupService;
    private readonly ILogger<ComprobantesController> _logger;

    public ComprobantesController(
        IComprobanteProcessor comprobanteProcessor,
        IComprobanteStorageService comprobanteStorageService,
        IUserContextService userContextService,
        IViviendasLookupService viviendasLookupService,
        ILogger<ComprobantesController> logger)
    {
        _comprobanteProcessor = comprobanteProcessor;
        _comprobanteStorageService = comprobanteStorageService;
        _userContextService = userContextService;
        _viviendasLookupService = viviendasLookupService;
        _logger = logger;
    }

    /// <summary>
    /// Sube y procesa un archivo de comprobante de pago (JPG, PNG o PDF) en el bucket privado de Storage.
    /// </summary>
    /// <param name="request">Datos multipart/form-data con el archivo y el id de la vivienda.</param>
    /// <param name="cancellationToken">Token de cancelación.</param>
    [HttpPost]
    [Consumes("multipart/form-data")]
    [RequestSizeLimit(MaxRequestBodyBytes)]
    [RequestFormLimits(MultipartBodyLengthLimit = MaxRequestBodyBytes)]
    [ProducesResponseType(typeof(ComprobanteSubidoResponse), StatusCodes.Status201Created)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    [ProducesResponseType(StatusCodes.Status403Forbidden)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status404NotFound)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status413PayloadTooLarge)]
    [ProducesResponseType(typeof(ErrorResponseDto), StatusCodes.Status502BadGateway)]
    public async Task<IActionResult> SubirComprobante(
        [FromForm] SubirComprobanteRequest request,
        CancellationToken cancellationToken)
    {
        if (request.Archivo == null || request.Archivo.Length == 0)
        {
            return BadRequest(new ErrorResponseDto("El archivo de comprobante es obligatorio."));
        }

        // Regla 2: Limitar el tamaño por encima de 5 MB => 413
        if (request.Archivo.Length > MaxFileSizeBytes)
        {
            return StatusCode(StatusCodes.Status413PayloadTooLarge, new ErrorResponseDto("El archivo supera el tamaño máximo permitido de 5 MB."));
        }

        if (request.ViviendaId <= 0)
        {
            return BadRequest(new ErrorResponseDto("El identificador de vivienda debe ser mayor a cero."));
        }

        // Regla 1: Roles Admin e Inquilino.
        // Admin: la vivienda debe ser de su condominio (P6, método 2).
        // Inquilino: debe ser residente titular de esa vivienda (P6, método 3).
        // Si no corresponde => 404.
        var condominioId = _userContextService.CondominioId;
        if (condominioId == Guid.Empty)
        {
            return StatusCode(StatusCodes.Status403Forbidden, new ErrorResponseDto("No se encontró un condominio asociado en el contexto de usuario."));
        }

        if (_userContextService.EsAdmin)
        {
            var existe = await _viviendasLookupService.ExisteViviendaEnCondominioAsync(request.ViviendaId, condominioId);
            if (!existe)
            {
                _logger.LogWarning("Admin {UserId} intentó subir comprobante para vivienda {ViviendaId} que no pertenece a condominio {CondominioId}",
                    _userContextService.UserId, request.ViviendaId, condominioId);
                return NotFound(new ErrorResponseDto("Vivienda no encontrada."));
            }
        }
        else
        {
            var esTitular = await _viviendasLookupService.EsResidenteTitularAsync(request.ViviendaId, _userContextService.UserId);
            if (!esTitular)
            {
                _logger.LogWarning("Inquilino {UserId} intentó subir comprobante para vivienda {ViviendaId} de la que no es titular",
                    _userContextService.UserId, request.ViviendaId);
                return NotFound(new ErrorResponseDto("Vivienda no encontrada."));
            }
        }

        // Regla 3: Flujo: validar y procesar (R1) -> construir ruta con el condominio de la vivienda -> subir (R2) -> devolver 201
        ComprobanteProcesadoResult procesado;
        try
        {
            using var stream = request.Archivo.OpenReadStream();
            procesado = await _comprobanteProcessor.ProcesarAsync(stream, request.Archivo.FileName, cancellationToken);
        }
        catch (ArgumentException ex)
        {
            // Regla 5: Si el procesamiento rechaza el archivo => 400 con el mensaje de R1
            _logger.LogWarning("Comprobante rechazado por validación de contenido: {Message}", ex.Message);
            return BadRequest(new ErrorResponseDto(ex.Message));
        }

        var ahora = DateTime.UtcNow;
        var ruta = ComprobanteRutaHelper.ConstruirRuta(
            condominioId,
            request.ViviendaId,
            ahora.Year,
            ahora.Month,
            procesado.ExtensionFinal);

        try
        {
            await _comprobanteStorageService.SubirAsync(
                procesado.BytesFinales,
                procesado.ContentTypeFinal,
                ruta,
                cancellationToken);
        }
        catch (Exception ex)
        {
            // Regla 5: Si Storage falla => 502 con mensaje genérico (sin filtrar detalles internos)
            _logger.LogError(ex, "Error al almacenar el comprobante en Supabase Storage en la ruta {Ruta}", ruta);
            return StatusCode(StatusCodes.Status502BadGateway, new ErrorResponseDto("Error al comunicar con el servicio de almacenamiento de comprobantes."));
        }

        var response = new ComprobanteSubidoResponse
        {
            Ruta = ruta,
            Hash = procesado.HashOriginal,
            TamanoBytes = procesado.TamanoFinal,
            ContentType = procesado.ContentTypeFinal
        };

        return StatusCode(StatusCodes.Status201Created, response);
    }
}
