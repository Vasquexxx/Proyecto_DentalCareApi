from contextlib import closing
import logging
import os
from pathlib import Path
import re

import pyodbc
from fastapi import FastAPI, HTTPException

from citas import router as citas_router
from db import get_connection

logger = logging.getLogger(__name__)


def _safe_db_message(message: str) -> str:
    """Oculta credenciales y parámetros de conexión antes de escribir el error."""
    # También ocultamos contraseñas escapadas para una cadena ODBC.
    private_values = set()
    for name in ("DB_PASSWORD", "DB_USER"):
        value = os.getenv(name)
        if value:
            private_values.update((value, value.replace("}", "}}")))
    for value in sorted(private_values, key=len, reverse=True):
        message = message.replace(value, "[OCULTO]")

    # Filtra parámetros aunque el controlador incluya una cadena de conexión.
    message = re.sub(
        r"\b(DRIVER|SERVER|DATABASE|UID|PWD|USER ID|PASSWORD|DSN|ENCRYPT|"
        r"TRUSTSERVERCERTIFICATE|TRUSTED_CONNECTION|PORT|ADDRESS|ADDR|"
        r"NETWORK ADDRESS|APP|APPLICATION NAME|WSID|CONNECTION TIMEOUT)\s*=\s*"
        r"(\{(?:[^}]|\}\})*\}|'(?:[^']|'')*'|\"(?:[^\"]|\"\")*\"|[^;\r\n]*)",
        r"\1=[OCULTO]",
        message,
        flags=re.IGNORECASE,
    )
    message = re.sub(
        r"\b(user|usuario)\s+('(?:[^']|'')*'|\"(?:[^\"]|\"\")*\")",
        r"\1 [OCULTO]",
        message,
        flags=re.IGNORECASE,
    )
    return message.replace("\r", " ").replace("\n", " ")


app = FastAPI(
    title="DentalCare API",
    description="API para el sistema de gestión de clínica dental",
    version="1.0.0"
)

app.include_router(citas_router)

@app.get("/")
def inicio():
    return {
        "mensaje": "Bienvenido a DentalCare API",
        "estado": "Funcionando correctamente"
    }


@app.get("/test-db")
def test_db():
    """Comprueba la conexión sin consultar ni modificar tablas."""
    try:
        with closing(get_connection()) as connection:
            with closing(connection.cursor()) as cursor:
                cursor.execute("SELECT 1")
                result = cursor.fetchone()
                if result is None or result[0] != 1:
                    raise ValueError("La comprobación no devolvió el resultado esperado.")
                return {"estado": "ok", "resultado": result[0]}
    except pyodbc.Error as error:
        state = str(error.args[0]) if error.args else ""
        has_state = re.fullmatch(r"[A-Z0-9]{5}", state) is not None
        details = error.args[1:] if has_state else error.args
        message = " | ".join(str(part) for part in details)
        # Sin traceback: el error original podría contener información privada.
        logger.error(
            "GET /test-db: SQLSTATE=%s; mensaje=%s",
            state if has_state else "desconocido",
            _safe_db_message(message),
        )
    except ValueError as error:
        logger.error(
            "GET /test-db: error de configuración o comprobación; "
            ".env presente=%s; mensaje=%s",
            Path(__file__).resolve().with_name(".env").is_file(),
            _safe_db_message(str(error)),
        )

    # Swagger recibe la misma respuesta genérica en ambos casos.
    raise HTTPException(
        status_code=503,
        detail="No se pudo conectar con la base de datos. Revisa la configuración y SQL Server.",
    ) from None
