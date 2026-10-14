"""Общий код для Roblox Open Cloud: собрать игру, загрузить версию места, запустить Luau.

По мотивам Roblox/place-ci-cd-demo (MIT): https://github.com/Roblox/place-ci-cd-demo
Адрес API можно подменить переменной ROBLOX_API_BASE (так делают тесты).
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PLACE_FILE = os.path.join(ROOT, "roblox", "DinoEggCatch.rbxlx")


class CloudError(Exception):
    pass


def api_base():
    return os.environ.get("ROBLOX_API_BASE", "https://apis.roblox.com").rstrip("/")


def env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        raise CloudError(f"Нет переменной {name}. Как её получить — в roblox/README.md, раздел «Публикация».")
    return value


def request(url, api_key, body=None, content_type="application/json", retries=3, pause=2):
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method="POST" if body is not None else "GET")
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            # 4xx — ошибка в запросе или ключе, повтор не поможет
            if e.code < 500 or attempt == retries - 1:
                raise CloudError(f"Roblox ответил {e.code}: {e.read().decode('utf-8', 'replace')}")
        except urllib.error.URLError as e:
            if attempt == retries - 1:
                raise CloudError(f"Нет связи с Roblox: {e}")
        time.sleep(pause)


def build_place():
    print("Собираю игру (rojo build)")
    subprocess.run(["rojo", "build", "-o", PLACE_FILE], cwd=os.path.join(ROOT, "roblox"), check=True)
    return PLACE_FILE


def upload_place(api_key, universe, place, path, publish):
    """Загружает .rbxlx как новую версию места. publish=True — игроки сразу видят новую версию."""
    kind = "Published" if publish else "Saved"
    with open(path, "rb") as f:
        result = request(
            f"{api_base()}/universes/v1/{universe}/places/{place}/versions?versionType={kind}",
            api_key, f.read(), "application/xml")
    version = result.get("versionNumber")
    if not isinstance(version, int):
        raise CloudError(f"Roblox не вернул номер версии: {result}")
    return version


def run_luau(api_key, universe, place, version, script, poll=3):
    """Запускает Luau на сервере с этой версией места. Возвращает (успех, строки лога)."""
    task = request(
        f"{api_base()}/cloud/v2/universes/{universe}/places/{place}/versions/{version}/luau-execution-session-tasks",
        api_key, json.dumps({"script": script}).encode("utf-8"))
    while task["state"] in ("QUEUED", "PROCESSING"):
        time.sleep(poll)
        task = request(f"{api_base()}/cloud/v2/{task['path']}", api_key)
    logs = request(f"{api_base()}/cloud/v2/{task['path']}/logs", api_key)
    lines = [line for chunk in logs.get("luauExecutionSessionTaskLogs", []) for line in chunk.get("messages", [])]
    return task["state"] == "COMPLETE", lines, task.get("error")


def fail(message):
    print(message, file=sys.stderr)
    sys.exit(1)
