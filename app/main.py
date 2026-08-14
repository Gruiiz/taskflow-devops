"""Small dependency-free HTTP API used by the DevOps project."""

from __future__ import annotations

import argparse
import json
import logging
import os
import time
import uuid
from http import HTTPStatus
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from typing import Any
from urllib.parse import urlsplit

from app.domain import TaskStore, TaskValidationError

LOGGER = logging.getLogger("taskflow")
MAX_REQUEST_BYTES = 16_384
APP_ENV = os.getenv("APP_ENV", "development")
APP_VERSION = os.getenv("APP_VERSION", "1.1.0")


def log_event(level: int, event: str, **fields: object) -> None:
    """Write one structured JSON event for CloudWatch and local Docker logs."""

    payload = {
        "event": event,
        "service": "taskflow-api",
        "environment": APP_ENV,
        "version": APP_VERSION,
        **fields,
    }
    LOGGER.log(level, json.dumps(payload, ensure_ascii=False, separators=(",", ":")))


class TaskFlowRequestHandler(BaseHTTPRequestHandler):
    """HTTP handler exposing health and task endpoints."""

    task_store = TaskStore()
    server_version = "TaskFlow/1.0"

    def do_GET(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        self._begin_request()
        path = self._request_path()
        if path == "/health":
            self._send_json(HTTPStatus.OK, {"status": "ok"})
            return

        if path == "/version":
            self._send_json(
                HTTPStatus.OK,
                {"service": "taskflow-api", "version": APP_VERSION, "environment": APP_ENV},
            )
            return

        if path == "/tasks":
            tasks = [task.to_dict() for task in self.task_store.list_all()]
            self._send_json(HTTPStatus.OK, {"tasks": tasks, "count": len(tasks)})
            return

        task_id = self._task_id_from_path(path)
        if task_id is not None:
            task = self.task_store.get(task_id)
            if task is None:
                self._send_error(HTTPStatus.NOT_FOUND, "Tarefa não encontrada.")
            else:
                self._send_json(HTTPStatus.OK, task.to_dict())
            return

        self._send_error(HTTPStatus.NOT_FOUND, "Rota não encontrada.")

    def do_POST(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        self._begin_request()
        if self._request_path() != "/tasks":
            self._send_error(HTTPStatus.NOT_FOUND, "Rota não encontrada.")
            return

        try:
            payload = self._read_json_body()
            task = self.task_store.create(payload.get("title"))
        except TaskValidationError as error:
            self._send_error(HTTPStatus.UNPROCESSABLE_ENTITY, str(error))
            return
        except (json.JSONDecodeError, UnicodeDecodeError):
            self._send_error(HTTPStatus.BAD_REQUEST, "JSON inválido.")
            return
        except RequestTooLargeError:
            self._send_error(
                HTTPStatus.REQUEST_ENTITY_TOO_LARGE,
                "Corpo da requisição muito grande.",
            )
            return

        self._send_json(HTTPStatus.CREATED, task.to_dict())

    def do_DELETE(self) -> None:  # noqa: N802 - BaseHTTPRequestHandler contract
        self._begin_request()
        task_id = self._task_id_from_path(self._request_path())
        if task_id is None:
            self._send_error(HTTPStatus.NOT_FOUND, "Rota não encontrada.")
            return

        if not self.task_store.delete(task_id):
            self._send_error(HTTPStatus.NOT_FOUND, "Tarefa não encontrada.")
            return

        self._send_json(HTTPStatus.OK, {"deleted": True, "id": task_id})

    def _request_path(self) -> str:
        path = urlsplit(self.path).path.rstrip("/")
        return path or "/"

    @staticmethod
    def _task_id_from_path(path: str) -> int | None:
        parts = path.strip("/").split("/")
        if len(parts) != 2 or parts[0] != "tasks" or not parts[1].isdigit():
            return None
        return int(parts[1])

    def _read_json_body(self) -> dict[str, Any]:
        raw_length = self.headers.get("Content-Length", "0")
        try:
            length = int(raw_length)
        except ValueError as error:
            raise json.JSONDecodeError("invalid content length", raw_length, 0) from error

        if length > MAX_REQUEST_BYTES:
            raise RequestTooLargeError
        raw_body = self.rfile.read(length)
        payload = json.loads(raw_body.decode("utf-8"))
        if not isinstance(payload, dict):
            raise json.JSONDecodeError("object expected", raw_body.decode("utf-8"), 0)
        return payload

    def _send_error(self, status: HTTPStatus, message: str) -> None:
        self._send_json(status, {"error": message, "status": status.value})

    def _send_json(self, status: HTTPStatus, payload: object) -> None:
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status.value)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Content-Security-Policy", "default-src 'none'")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("X-Request-ID", self.request_id)
        self.end_headers()
        self.wfile.write(body)

        started_at = getattr(self, "_request_started_at", time.perf_counter())
        log_event(
            logging.INFO,
            "http_request",
            request_id=self.request_id,
            method=self.command,
            path=self._request_path(),
            status=status.value,
            duration_ms=round((time.perf_counter() - started_at) * 1000, 2),
        )

    def _begin_request(self) -> None:
        self._request_started_at = time.perf_counter()
        candidate = self.headers.get("X-Request-ID", "")
        allowed = candidate and len(candidate) <= 64 and all(
            character.isalnum() or character in "-_." for character in candidate
        )
        self.request_id = candidate if allowed else uuid.uuid4().hex

    def log_message(self, format: str, *args: object) -> None:
        # Access events are emitted in structured form by ``_send_json``.
        return


class RequestTooLargeError(ValueError):
    """Raised when a request exceeds the configured body limit."""


def create_handler(store: TaskStore) -> type[TaskFlowRequestHandler]:
    """Create an isolated handler class bound to a task store."""

    class BoundTaskFlowRequestHandler(TaskFlowRequestHandler):
        task_store = store

    return BoundTaskFlowRequestHandler


def create_server(
    host: str = "0.0.0.0",  # nosec B104 - container must listen on every interface
    port: int = 8000,
    store: TaskStore | None = None,
) -> ThreadingHTTPServer:
    """Build the HTTP server. Tests use port zero for an ephemeral port."""

    repository = store if store is not None else TaskStore()
    return ThreadingHTTPServer((host, port), create_handler(repository))


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="TaskFlow API")
    parser.add_argument(
        "--host",
        default="0.0.0.0",  # nosec B104 - explicit container bind address
    )
    parser.add_argument("--port", type=int, default=8000)
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    configured_level = getattr(logging, os.getenv("LOG_LEVEL", "INFO").upper(), logging.INFO)
    logging.basicConfig(level=configured_level, format="%(message)s")
    server = create_server(args.host, args.port)
    log_event(logging.INFO, "service_started", host=args.host, port=args.port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        log_event(logging.INFO, "service_stopping")
    finally:
        server.server_close()


if __name__ == "__main__":
    main()
