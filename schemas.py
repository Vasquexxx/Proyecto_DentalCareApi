"""Modelos que validan los JSON recibidos y documentan Swagger."""

from datetime import date, time
from typing import Annotated, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, field_validator, model_validator


# Los identificadores INT de SQL Server tienen un tamaño máximo de 32 bits.
IdSql = Annotated[int, Field(strict=True, gt=0, le=2147483647)]
IdPaciente = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=20)]
MotivoCita = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=200)]


class CitaCrear(BaseModel):
    """Cada campo corresponde a un parámetro real de SP_RegistrarCita."""

    model_config = ConfigDict(
        extra="forbid",
        json_schema_extra={
            "examples": [{
                "id_paciente": "PAC001",
                "id_odontologo": 1,
                "id_consultorio": 1,
                "id_estado_cita": 1,
                "fecha": "2026-10-28",
                "hora_inicio": "09:00:00",
                "hora_fin": "09:30:00",
                "motivo": "Consulta de prueba desde Swagger",
            }]
        },
    )

    id_paciente: IdPaciente
    id_odontologo: IdSql
    id_consultorio: IdSql
    id_estado_cita: IdSql
    fecha: date
    hora_inicio: time
    hora_fin: time
    motivo: MotivoCita

    @field_validator("id_paciente", "motivo")
    @classmethod
    def validar_varchar(cls, value: str) -> str:
        # La base inspeccionada usa VARCHAR con la codificación Windows-1252.
        # Evitamos que SQL Server sustituya caracteres no representables por '?'.
        try:
            value.encode("cp1252")
        except UnicodeEncodeError:
            raise ValueError("El texto contiene caracteres no admitidos por VARCHAR en esta base.") from None
        return value

    @model_validator(mode="after")
    def validar_horario(self) -> Self:
        # SQL TIME guarda una hora local, sin zona horaria.
        if self.hora_inicio.tzinfo is not None or self.hora_fin.tzinfo is not None:
            raise ValueError("Envía horas locales sin zona horaria, por ejemplo 09:00:00.")
        if self.hora_fin <= self.hora_inicio:
            raise ValueError("La hora final debe ser posterior a la hora inicial.")
        return self


class CitaEstadoActualizar(BaseModel):
    """El ID de la cita llega por la ruta; el estado llega en el JSON."""

    model_config = ConfigDict(extra="forbid", json_schema_extra={"examples": [{"id_estado": 2}]})
    id_estado: IdSql


class MensajeRespuesta(BaseModel):
    mensaje: str


class CitaEstadoRespuesta(MensajeRespuesta):
    id_cita: int
    id_estado: int


class CitaDetalle(BaseModel):
    """Una fila del SELECT; los nombres coinciden con los alias de la consulta."""

    id: int
    id_paciente: str
    paciente: str
    id_odontologo: int
    odontologo: str
    fecha: date
    hora_inicio: time
    hora_fin: time
    id_consultorio: int
    consultorio: str
    id_estado_cita: int
    estado: str
    motivo: str
