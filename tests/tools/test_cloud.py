"""Тесты публикации и запуска проверок в Roblox против поддельного сервера Open Cloud.
Запуск из корня репозитория:  python3 -m unittest discover -s tests/tools -v
"""
import contextlib
import io
import json
import os
import sys
import threading
import unittest
from http.server import BaseHTTPRequestHandler, HTTPServer
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
sys.path.insert(0, os.path.join(ROOT, "tests", "cloud"))
import roblox_cloud as cloud  # noqa: E402
import publish  # noqa: E402
import run_in_roblox  # noqa: E402


class FakeRoblox:
    """Маленький поддельный Roblox Open Cloud: записывает запросы и отвечает как настоящий."""

    def __init__(self):
        self.calls = []
        self.fail_next = []  # коды ошибок, которые вернуть на следующие запросы
        self.task_state = "COMPLETE"
        self.polls = 0
        fake = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def reply(self, code, payload):
                body = json.dumps(payload).encode("utf-8")
                self.send_response(code)
                self.send_header("Content-Type", "application/json")
                self.send_header("Content-Length", str(len(body)))
                self.end_headers()
                self.wfile.write(body)

            def handle_any(self, method):
                length = int(self.headers.get("Content-Length") or 0)
                body = self.rfile.read(length) if length else b""
                # заголовки HTTP не зависят от регистра
                headers = {k.lower(): v for k, v in self.headers.items()}
                fake.calls.append({"method": method, "path": self.path, "headers": headers, "body": body})
                if fake.fail_next:
                    return self.reply(fake.fail_next.pop(0), {"error": "nope"})
                if "/versions?versionType=" in self.path:
                    return self.reply(200, {"versionNumber": 42})
                if self.path.endswith("luau-execution-session-tasks"):
                    return self.reply(200, {"path": "universes/1/places/2/versions/42/luau-execution-sessions/s/tasks/t", "state": "QUEUED"})
                if self.path.endswith("/logs"):
                    return self.reply(200, {"luauExecutionSessionTaskLogs": [{"messages": ["PASS  C1", "8 passed, 0 failed"]}]})
                if "/tasks/t" in self.path:
                    fake.polls += 1
                    state = "PROCESSING" if fake.polls < 2 else fake.task_state
                    return self.reply(200, {"path": "universes/1/places/2/versions/42/luau-execution-sessions/s/tasks/t", "state": state, "error": {"code": "SCRIPT_ERROR"} if state == "FAILED" else None})
                return self.reply(404, {"error": "unknown"})

            def do_GET(self):
                self.handle_any("GET")

            def do_POST(self):
                self.handle_any("POST")

        self.server = HTTPServer(("127.0.0.1", 0), Handler)
        self.url = f"http://127.0.0.1:{self.server.server_port}"
        threading.Thread(target=self.server.serve_forever, daemon=True).start()

    def close(self):
        self.server.shutdown()


class CloudTest(unittest.TestCase):
    def setUp(self):
        self.fake = FakeRoblox()
        self.env = mock.patch.dict(os.environ, {
            "ROBLOX_API_BASE": self.fake.url,
            "ROBLOX_API_KEY": "secret-key",
            "ROBLOX_UNIVERSE_ID": "1",
            "ROBLOX_PLACE_ID": "2",
            "NO_PROXY": "127.0.0.1,localhost",
            "no_proxy": "127.0.0.1,localhost",
        })
        self.env.start()
        self.no_sleep = mock.patch.object(cloud.time, "sleep", lambda s: None)
        self.no_sleep.start()

    def tearDown(self):
        self.no_sleep.stop()
        self.env.stop()
        self.fake.close()

    # ---------- юнит ----------

    def test_P1_upload_saved_vs_published(self):
        place = os.path.join(ROOT, "tests", "tools", "fake.rbxlx")
        with open(place, "wb") as f:
            f.write(b"<roblox/>")
        try:
            self.assertEqual(cloud.upload_place("k", "1", "2", place, publish=False), 42)
            self.assertEqual(cloud.upload_place("k", "1", "2", place, publish=True), 42)
        finally:
            os.remove(place)
        saved, published = self.fake.calls
        self.assertEqual(saved["path"], "/universes/v1/1/places/2/versions?versionType=Saved")
        self.assertEqual(published["path"], "/universes/v1/1/places/2/versions?versionType=Published")
        self.assertEqual(published["headers"]["x-api-key"], "k")
        self.assertEqual(published["headers"]["content-type"], "application/xml")
        self.assertEqual(published["body"], b"<roblox/>")

    def test_P2_retries_on_server_error_but_not_on_bad_key(self):
        self.fake.fail_next = [503]
        self.assertEqual(cloud.request(self.fake.url + "/universes/v1/1/places/2/versions?versionType=Saved", "k", b"x", "application/xml")["versionNumber"], 42)
        self.assertEqual(len(self.fake.calls), 2, "после 503 должен быть повтор")
        self.fake.calls.clear()
        self.fake.fail_next = [401]
        with self.assertRaises(cloud.CloudError) as err:
            cloud.request(self.fake.url + "/x", "bad", b"x")
        self.assertIn("401", str(err.exception))
        self.assertEqual(len(self.fake.calls), 1, "неверный ключ не повторяем")

    def test_P3_missing_variable_is_clear(self):
        with mock.patch.dict(os.environ, {"ROBLOX_PLACE_ID": ""}):
            with self.assertRaises(cloud.CloudError) as err:
                cloud.env("ROBLOX_PLACE_ID")
        self.assertIn("ROBLOX_PLACE_ID", str(err.exception))

    # ---------- e2e: целиком скрипты CI ----------

    def test_P4_publish_script_publishes_built_game(self):
        out = io.StringIO()
        with contextlib.redirect_stdout(out):
            version = publish.main(build=False)
        self.assertEqual(version, 42)
        [call] = self.fake.calls
        self.assertEqual(call["path"], "/universes/v1/1/places/2/versions?versionType=Published")
        with open(cloud.PLACE_FILE, "rb") as f:
            self.assertEqual(call["body"], f.read(), "загружен собранный файл игры")
        self.assertIn("Опубликовано: версия 42", out.getvalue())

    def test_P5_publish_without_key_fails_loudly(self):
        with mock.patch.dict(os.environ, {"ROBLOX_API_KEY": ""}):
            with contextlib.redirect_stderr(io.StringIO()):
                with self.assertRaises(SystemExit) as code:
                    publish.main(build=False)
        self.assertEqual(code.exception.code, 1)
        self.assertEqual(self.fake.calls, [], "без ключа ничего не отправлено")

    def test_P6_cloud_tests_upload_without_publishing_and_report(self):
        out = io.StringIO()
        with mock.patch.object(cloud, "build_place", lambda: cloud.PLACE_FILE), contextlib.redirect_stdout(out):
            run_in_roblox.main()
        paths = [c["path"] for c in self.fake.calls]
        self.assertEqual(paths[0], "/universes/v1/1/places/2/versions?versionType=Saved", "тестовое место не публикуется")
        self.assertTrue(paths[1].endswith("/versions/42/luau-execution-session-tasks"), "проверки на только что загруженной версии")
        script = json.loads(self.fake.calls[1]["body"])["script"]
        self.assertIn("C1 Сервер игры запустился без ошибок", script)
        self.assertIn("8 passed, 0 failed", out.getvalue())

    def test_P7_cloud_tests_fail_when_roblox_says_failed(self):
        self.fake.task_state = "FAILED"
        with mock.patch.object(cloud, "build_place", lambda: cloud.PLACE_FILE), contextlib.redirect_stdout(io.StringIO()), contextlib.redirect_stderr(io.StringIO()):
            with self.assertRaises(SystemExit) as code:
                run_in_roblox.main()
        self.assertEqual(code.exception.code, 1)


if __name__ == "__main__":
    unittest.main()
