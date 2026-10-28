"""Rutas de citas: consultas, procedimientos almacenados y eliminación."""

from contextlib import closing
from datetime import date
import logging
import re
from typing import Annotated

import pyodbc
from fastapi import APIRouter, HTTPException, Path, Query, status

from db import get_connection
from schemas import CitaCrear, CitaDetalle, CitaEstadoActualizar, CitaEstadoRespuesta, MensajeRespuesta


router = APIRouter(prefix="/citas", tags=["Citas"])
logger = logging.getLogger(__name__)

CONSULTAR_CITAS_SQL = """
SELECT
    c.id,
    c.id_paciente,
    CONCAT(p.Nombres, ' ', p.Apellidos) AS paciente,
    c.id_odonto AS id_odontologo,
    CONCAT(e.nombres, ' ', e.apellidos) AS odontologo,
    c.fecha,
    c.hora_inicio,
    c.hora_fin,
    c.id_consultorio,
    co.Nombre AS consultorio,
    c.id_estadoCita AS id_estado_cita,
    ec.nombre AS estado,
    c.motivo
FROM dbo.Cita AS c
INNER JOIN dbo.Paciente AS p ON p.Id_paciente = c.id_paciente
INNER JOIN dbo.Odontologo AS o ON o.Id_odonto = c.id_odonto
INNER JOIN dbo.Empleado AS e ON e.Id_empleado = o.id_empleado
INNER JOIN dbo.Consultorio AS co ON co.id = c.id_consultorio
INNER JOIN dbo.EstadoCita AS ec ON ec.id = c.id_estadoCita
"""
ORDEN_CITAS_SQL = "\nORDER BY c.fecha, c.hora_inicio, c.id;"

# El SQL es fijo. Los valores del usuario se envían aparte mediante los '?'.
REGISTRAR_CITA_SQL = """
EXEC dbo.SP_RegistrarCita
    @IdPaciente = ?, @IdOdontologo = ?, @IdConsultorio = ?,
    @IdEstadoCita = ?, @Fecha = ?, @HoraInicio = ?, @HoraFin = ?, @Motivo = ?;
"""
ACTUALIZAR_ESTADO_SQL = """
EXEC dbo.SP_ActualizarEstadoCita @IdCita = ?, @IdEstado = ?;
"""
ELIMINAR_CITA_SQL = "DELETE FROM dbo.Cita WHERE id = ?;"

# Cada procedimiento utiliza sus propios números de error: no son intercambiables.
ERRORES_REGISTRO = {
    50001: (422, "El paciente no existe"),
    50002: (422, "El odontologo no existe"),
    50003: (422, "El consultorio no existe"),
    50004: (422, "El estado de la cita no existe"),
    50005: (422, "El horario de la cita es incorrecto"),
    50006: (409, "El odontologo ya tiene una cita en ese horario"),
    50007: (409, "El consultorio ya esta ocupado en ese horario"),
}
ERRORES_ESTADO = {
    50001: (404, "La cita no existe"),
    50002: (422, "El estado no existe"),
}


def _ejecutar_sp(sql: str, parametros: tuple, errores: dict[int, tuple[int, str]]) -> None:
    """Consume toda la ejecución: un error también puede llegar en nextset()."""
    try:
        # db.py usa autocommit=True. BEGIN/COMMIT/ROLLBACK pertenecen al SP.
        with closing(get_connection()) as connection:
            with closing(connection.cursor()) as cursor:
                cursor.execute(sql, parametros)
                # El SP de actualización emite un conteo de filas. No devolvemos
                # éxito hasta que terminen también los resultados posteriores.
                while cursor.nextset():
                    pass
    except pyodbc.Error as error:
        state = str(error.args[0]) if error.args else ""
        state = state if re.fullmatch(r"[A-Z0-9]{5}", state) else "desconocido"
        # pyodbc incluye el número nativo entre paréntesis en el diagnóstico.
        codes = [int(code) for part in error.args for code in re.findall(r"\((\d+)\)", str(part))]
        # Registramos códigos; no registramos el JSON, credenciales ni SQL completo.
        logger.error("Error de procedimiento: SQLSTATE=%s; códigos=%s", state, codes)
        for code in codes:
            if code in errores:
                http_status, detail = errores[code]
                raise HTTPException(status_code=http_status, detail=detail) from None
        if state.startswith("08") or state in ("HYT00", "HYT01", "IM002", "IM003"):
            raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None
        if any(code in (2601, 2627) for code in codes):
            raise HTTPException(status_code=409, detail="La operación entra en conflicto con un registro existente.") from None
        if any(code in (547, 8152, 2628) for code in codes):
            raise HTTPException(status_code=422, detail="Los datos no cumplen las restricciones de la base de datos.") from None
        raise HTTPException(status_code=500, detail="No se pudo completar la operación.") from None
    except ValueError:
        logger.error("No se pudo ejecutar el procedimiento: revisa las variables de configuración de SQL Server.")
        raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None


@router.get(
    "",
    response_model=list[CitaDetalle],
    summary="Consultar y buscar citas",
    description="Sin filtros devuelve todas las citas. Los filtros se envían en la URL y se combinan con AND. Para una cita específica, utiliza id_cita. Devuelve [] si no hay coincidencias.",
    responses={
        422: {"description": "Un filtro contiene un identificador o una fecha inválidos"},
        500: {"description": "Error interno al consultar las citas"},
        503: {"description": "Base de datos no disponible o configuración incompleta"},
    },
)
def listar_citas(
    id_cita: Annotated[int | None, Query(gt=0, le=2147483647, description="ID de la cita que deseas buscar", examples=[1])] = None,
    id_paciente: Annotated[str | None, Query(min_length=1, max_length=20, description="Identificador del paciente", examples=["PAC001"])] = None,
    id_odontologo: Annotated[int | None, Query(gt=0, le=2147483647, description="Identificador del odontólogo")] = None,
    id_consultorio: Annotated[int | None, Query(gt=0, le=2147483647, description="Identificador del consultorio")] = None,
    id_estado_cita: Annotated[int | None, Query(gt=0, le=2147483647, description="Identificador del estado de la cita")] = None,
    fecha: Annotated[date | None, Query(description="Fecha de la cita en formato AAAA-MM-DD", examples=["2026-11-02"])] = None,
) -> list[CitaDetalle]:
    """GET /citas recibe filtros opcionales en la URL y devuelve una lista JSON."""
    condiciones = []
    parametros = []
    # Los nombres de columna son constantes del código. Los valores del usuario
    # se envían por separado a pyodbc, nunca se concatenan dentro del SQL.
    for columna, valor in (
        ("c.id", id_cita),
        ("c.id_paciente", id_paciente),
        ("c.id_odonto", id_odontologo),
        ("c.id_consultorio", id_consultorio),
        ("c.id_estadoCita", id_estado_cita),
        ("c.fecha", fecha),
    ):
        if valor is not None:
            condiciones.append(f"{columna} = ?")
            parametros.append(valor)

    sql = CONSULTAR_CITAS_SQL
    if condiciones:
        sql += "\nWHERE " + " AND ".join(condiciones)
    sql += ORDEN_CITAS_SQL

    try:
        with closing(get_connection()) as connection:
            with closing(connection.cursor()) as cursor:
                if parametros:
                    cursor.execute(sql, tuple(parametros))
                else:
                    cursor.execute(sql)
                # description contiene los nombres de las columnas del SELECT.
                columnas = [column[0] for column in cursor.description]
                # zip une cada nombre con su valor para crear un diccionario.
                filas = [dict(zip(columnas, fila)) for fila in cursor.fetchall()]
    except pyodbc.Error as error:
        state = str(error.args[0]) if error.args else ""
        state = state if re.fullmatch(r"[A-Z0-9]{5}", state) else "desconocido"
        logger.error("GET /citas: SQLSTATE=%s", state)
        if state.startswith("08") or state in ("HYT00", "HYT01", "IM002", "IM003"):
            raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None
        raise HTTPException(status_code=500, detail="No se pudieron consultar las citas.") from None
    except ValueError:
        logger.error("GET /citas: revisa las variables de configuración de SQL Server.")
        raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None

    # Pydantic valida la respuesta y convierte fecha y hora a texto en el JSON.
    # Si fetchall() no devuelve filas, el resultado es una lista vacía: [].
    return [CitaDetalle(**fila) for fila in filas]


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=MensajeRespuesta,
    summary="Registrar una cita",
    description="Ejecuta dbo.SP_RegistrarCita. Crea una cita real. El SP no devuelve el ID creado.",
    responses={
        409: {"description": "Odontólogo o consultorio ocupado"},
        422: {"description": "Datos inválidos o referencias inexistentes"},
        500: {"description": "Error interno al ejecutar el procedimiento"},
        503: {"description": "Base de datos no disponible o configuración incompleta"},
    },
)
def registrar_cita(cita: CitaCrear) -> MensajeRespuesta:
    """Pydantic valida el JSON antes de entrar en esta función."""
    _ejecutar_sp(
        REGISTRAR_CITA_SQL,
        (
            cita.id_paciente, cita.id_odontologo, cita.id_consultorio,
            cita.id_estado_cita, cita.fecha,
            # Texto ISO conserva los microsegundos al convertirlo a SQL TIME.
            cita.hora_inicio.isoformat(), cita.hora_fin.isoformat(), cita.motivo,
        ),
        ERRORES_REGISTRO,
    )
    return MensajeRespuesta(mensaje="Cita registrada correctamente")


@router.patch(
    "/{id_cita}/estado",
    response_model=CitaEstadoRespuesta,
    summary="Actualizar el estado de una cita",
    description="Ejecuta dbo.SP_ActualizarEstadoCita y cambia el estado de la cita indicada.",
    responses={
        404: {"description": "La cita no existe"},
        422: {"description": "Datos inválidos o estado inexistente"},
        500: {"description": "Error interno al ejecutar el procedimiento"},
        503: {"description": "Base de datos no disponible o configuración incompleta"},
    },
)
def actualizar_estado_cita(
    id_cita: Annotated[int, Path(gt=0, le=2147483647, description="ID de una cita existente", examples=[1])],
    cambio: CitaEstadoActualizar,
) -> CitaEstadoRespuesta:
    """La ruta proporciona @IdCita y el cuerpo JSON proporciona @IdEstado."""
    _ejecutar_sp(ACTUALIZAR_ESTADO_SQL, (id_cita, cambio.id_estado), ERRORES_ESTADO)
    return CitaEstadoRespuesta(
        mensaje="Estado actualizado correctamente", id_cita=id_cita, id_estado=cambio.id_estado,
    )


@router.delete(
    "/{id_cita}",
    response_model=MensajeRespuesta,
    summary="Eliminar una cita",
    description="Elimina físicamente la cita indicada por su ID. No recibe un cuerpo JSON.",
    responses={
        404: {"description": "La cita no existe"},
        409: {"description": "La cita tiene registros relacionados que impiden eliminarla"},
        422: {"description": "El identificador no es un entero positivo válido"},
        500: {"description": "Error interno al eliminar la cita"},
        503: {"description": "Base de datos no disponible o configuración incompleta"},
    },
)
def eliminar_cita(
    id_cita: Annotated[int, Path(gt=0, le=2147483647, description="ID de la cita que deseas eliminar")],
) -> MensajeRespuesta:
    """El WHERE limita el borrado a un ID; su valor se envía aparte del SQL."""
    try:
        with closing(get_connection()) as connection:
            with closing(connection.cursor()) as cursor:
                cursor.execute(ELIMINAR_CITA_SQL, (id_cita,))
                # La clave primaria permite borrar como máximo una fila.
                # db.py usa autocommit=True: SQL Server confirma esta sentencia
                # como una operación individual, sin afectar los SP existentes.
                filas_eliminadas = cursor.rowcount
    except pyodbc.Error as error:
        state = str(error.args[0]) if error.args else ""
        state = state if re.fullmatch(r"[A-Z0-9]{5}", state) else "desconocido"
        codes = [int(code) for part in error.args for code in re.findall(r"\((\d+)\)", str(part))]
        logger.error("DELETE /citas: SQLSTATE=%s; códigos=%s", state, codes)
        if 547 in codes:
            raise HTTPException(
                status_code=409,
                detail="La cita tiene registros relacionados que impiden eliminarla.",
            ) from None
        if state.startswith("08") or state in ("HYT00", "HYT01", "IM002", "IM003"):
            raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None
        raise HTTPException(status_code=500, detail="No se pudo eliminar la cita.") from None
    except ValueError:
        logger.error("DELETE /citas: revisa las variables de configuración de SQL Server.")
        raise HTTPException(status_code=503, detail="No se pudo conectar con la base de datos.") from None

    if filas_eliminadas == 0:
        raise HTTPException(status_code=404, detail="La cita no existe")
    if filas_eliminadas != 1:
        logger.error("DELETE /citas: el controlador no confirmó la eliminación de una fila.")
        raise HTTPException(status_code=500, detail="No se pudo confirmar la eliminación de la cita.")
    return MensajeRespuesta(mensaje="Cita eliminada correctamente")
