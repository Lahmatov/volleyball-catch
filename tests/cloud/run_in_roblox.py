"""Собирает игру, загружает её в тестовое место Roblox и запускает tests/cloud/ingame.luau
внутри настоящего Roblox через Open Cloud Luau Execution.

По мотивам Roblox/place-ci-cd-demo (MIT): https://github.com/Roblox/place-ci-cd-demo

Нужно (переменные окружения):
  ROBLOX_API_KEY      ключ Open Cloud с правами universe.places:write и
                      universe.place.luau-execution-session:write
  ROBLOX_UNIVERSE_ID  id опыта (universe) с ТЕСТОВЫМ местом
  ROBLOX_PLACE_ID     id тестового места (не боевого!)

Запуск из корня репозитория:  python3 tests/cloud/run_in_roblox.py
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PLACE_FILE = os.path.join(ROOT, "roblox", "DinoEggCatch.rbxlx")
TASK_FILE = os.path.join(ROOT, "tests", "cloud", "ingame.luau")


def env(name):
    value = os.environ.get(name, "").strip()
    if not value:
        sys.exit(f"Нет переменной {name}. Как её получить — в roblox/README.md, раздел «Тесты в настоящем Roblox».")
    return value


def request(url, api_key, body=None, content_type="application/json"):
    headers = {"x-api-key": api_key, "Accept": "application/json"}
    if body is not None:
        headers["Content-Type"] = content_type
    req = urllib.request.Request(url, data=body, headers=headers, method="POST" if body is not None else "GET")
    for attempt in range(3):
        try:
            with urllib.request.urlopen(req) as response:
                return json.loads(response.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            if e.code < 500 or attempt == 2:
                sys.exit(f"Roblox ответил {e.code}: {e.read().decode('utf-8', 'replace')}")
        except urllib.error.URLError as e:
            if attempt == 2:
                sys.exit(f"Нет связи с Roblox: {e}")
        time.sleep(2)


def main():
    api_key = env("ROBLOX_API_KEY")
    universe = env("ROBLOX_UNIVERSE_ID")
    place = env("ROBLOX_PLACE_ID")

    print("Собираю игру (rojo build)")
    subprocess.run(["rojo", "build", "-o", PLACE_FILE], cwd=os.path.join(ROOT, "roblox"), check=True)

    print("Загружаю в тестовое место")
    with open(PLACE_FILE, "rb") as f:
        uploaded = request(
            f"https://apis.roblox.com/universes/v1/{universe}/places/{place}/versions?versionType=Saved",
            api_key, f.read(), "application/xml")
    version = uploaded["versionNumber"]

    print(f"Запускаю проверки на версии {version}")
    with open(TASK_FILE, encoding="utf-8") as f:
        script = f.read()
    task = request(
        f"https://apis.roblox.com/cloud/v2/universes/{universe}/places/{place}/versions/{version}/luau-execution-session-tasks",
        api_key, json.dumps({"script": script}).encode("utf-8"))

    while task["state"] in ("QUEUED", "PROCESSING"):
        time.sleep(3)
        task = request(f"https://apis.roblox.com/cloud/v2/{task['path']}", api_key)

    logs = request(f"https://apis.roblox.com/cloud/v2/{task['path']}/logs", api_key)
    for chunk in logs.get("luauExecutionSessionTaskLogs", []):
        for line in chunk.get("messages", []):
            print(line)

    if task["state"] != "COMPLETE":
        print(f"Проверки не прошли: {json.dumps(task.get('error'), ensure_ascii=False)}", file=sys.stderr)
        sys.exit(1)
    print("Все проверки в Roblox прошли")


if __name__ == "__main__":
    main()
