"""Integration tests for the HTTP API."""

from __future__ import annotations

import json
import threading
import unittest
from http.client import HTTPResponse
from urllib.error import HTTPError
from urllib.request import Request, urlopen

from app.domain import TaskStore
from app.main import create_server


class TaskFlowApiTest(unittest.TestCase):
    def setUp(self) -> None:
        self.server = create_server("127.0.0.1", 0, TaskStore())
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        host, port = self.server.server_address
        self.base_url = f"http://{host}:{port}"

    def tearDown(self) -> None:
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)

    def request(
        self, method: str, path: str, payload: object | None = None
    ) -> tuple[int, dict[str, object]]:
        data = None
        headers = {}
        if payload is not None:
            data = json.dumps(payload).encode("utf-8")
            headers["Content-Type"] = "application/json"
        request = Request(self.base_url + path, data=data, headers=headers, method=method)

        try:
            response: HTTPResponse = urlopen(request, timeout=2)
        except HTTPError as error:
            response = error

        with response:
            body = json.loads(response.read().decode("utf-8"))
            return response.status, body

    def test_health_endpoint(self) -> None:
        status, body = self.request("GET", "/health")

        self.assertEqual(status, 200)
        self.assertEqual(body, {"status": "ok"})

    def test_version_and_security_headers(self) -> None:
        request = Request(
            self.base_url + "/version",
            headers={"X-Request-ID": "phase2-test"},
            method="GET",
        )

        with urlopen(request, timeout=2) as response:
            body = json.loads(response.read().decode("utf-8"))
            self.assertEqual(response.status, 200)
            self.assertEqual(body["service"], "taskflow-api")
            self.assertIn("version", body)
            self.assertEqual(response.headers["X-Request-ID"], "phase2-test")
            self.assertEqual(response.headers["X-Content-Type-Options"], "nosniff")

    def test_task_lifecycle(self) -> None:
        create_status, created = self.request("POST", "/tasks", {"title": "Criar CI"})
        list_status, listed = self.request("GET", "/tasks")
        get_status, fetched = self.request("GET", "/tasks/1")
        delete_status, deleted = self.request("DELETE", "/tasks/1")
        missing_status, missing = self.request("GET", "/tasks/1")

        self.assertEqual(create_status, 201)
        self.assertEqual(created["id"], 1)
        self.assertEqual(list_status, 200)
        self.assertEqual(listed["count"], 1)
        self.assertEqual(get_status, 200)
        self.assertEqual(fetched["title"], "Criar CI")
        self.assertEqual(delete_status, 200)
        self.assertEqual(deleted, {"deleted": True, "id": 1})
        self.assertEqual(missing_status, 404)
        self.assertEqual(missing["status"], 404)

    def test_rejects_invalid_task(self) -> None:
        status, body = self.request("POST", "/tasks", {"title": "  "})

        self.assertEqual(status, 422)
        self.assertIn("obrigatório", str(body["error"]))

    def test_unknown_routes_return_404(self) -> None:
        get_status, _ = self.request("GET", "/unknown")
        post_status, _ = self.request("POST", "/unknown", {})
        delete_status, _ = self.request("DELETE", "/tasks/not-a-number")

        self.assertEqual((get_status, post_status, delete_status), (404, 404, 404))

    def test_malformed_json_returns_400(self) -> None:
        request = Request(
            self.base_url + "/tasks",
            data=b"{invalid",
            headers={"Content-Type": "application/json"},
            method="POST",
        )

        with self.assertRaises(HTTPError) as context:
            urlopen(request, timeout=2)

        self.assertEqual(context.exception.code, 400)


if __name__ == "__main__":
    unittest.main()
