"""Configuración de la conexión a SQL Server mediante variables de entorno."""

import os
from pathlib import Path

import pyodbc
from dotenv import load_dotenv


load_dotenv(Path(__file__).resolve().parent / ".env")


def get_connection() -> pyodbc.Connection:
    """Abre una conexión; quien la utiliza debe cerrarla al terminar."""
    required = ("DB_SERVER", "DB_NAME", "DB_USER", "DB_PASSWORD")
    if any(not os.getenv(name) for name in required):
        raise ValueError("Faltan variables de entorno para conectar con SQL Server.")

    port = int(os.getenv("DB_PORT", "1433"))
    if not 1 <= port <= 65535:
        raise ValueError("El puerto de SQL Server no es válido.")

    encrypt = os.getenv("DB_ENCRYPT", "yes").lower()
    trust_certificate = os.getenv("DB_TRUST_SERVER_CERTIFICATE", "no").lower()
    if encrypt not in ("yes", "no") or trust_certificate not in ("yes", "no"):
        raise ValueError("Las opciones de cifrado deben ser yes o no.")

    settings = {
        "DRIVER": os.getenv("DB_DRIVER", "ODBC Driver 18 for SQL Server"),
        "SERVER": f"{os.environ['DB_SERVER']},{port}",
        "DATABASE": os.environ["DB_NAME"],
        "UID": os.environ["DB_USER"],
        "PWD": os.environ["DB_PASSWORD"],
        "Encrypt": encrypt,
        "TrustServerCertificate": trust_certificate,
    }
    # Las llaves protegen valores que contengan caracteres como punto y coma.
    connection_string = ";".join(
        key + "={" + value.replace("}", "}}") + "}"
        for key, value in settings.items()
    )
    return pyodbc.connect(connection_string, timeout=5, autocommit=True)
