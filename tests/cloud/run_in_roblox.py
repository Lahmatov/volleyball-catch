"""Собирает игру, загружает её в ТЕСТОВОЕ место Roblox (не публикуя) и запускает
tests/cloud/ingame.luau внутри настоящего Roblox через Open Cloud Luau Execution.

Переменные: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID (тестовые!).
Запуск из корня репозитория:  python3 tests/cloud/run_in_roblox.py
"""
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0, os.path.join(ROOT, "tools"))
import roblox_cloud as cloud  # noqa: E402

TASK_FILE = os.path.join(ROOT, "tests", "cloud", "ingame.luau")


def main():
    try:
        api_key = cloud.env("ROBLOX_API_KEY")
        universe = cloud.env("ROBLOX_UNIVERSE_ID")
        place = cloud.env("ROBLOX_PLACE_ID")
        path = cloud.build_place()
        version = cloud.upload_place(api_key, universe, place, path, publish=False)
        print(f"Запускаю проверки на версии {version}")
        with open(TASK_FILE, encoding="utf-8") as f:
            ok, lines, error = cloud.run_luau(api_key, universe, place, version, f.read())
    except cloud.CloudError as e:
        cloud.fail(str(e))
    for line in lines:
        print(line)
    if not ok:
        cloud.fail(f"Проверки в Roblox не прошли: {error}")
    print("Все проверки в Roblox прошли")


if __name__ == "__main__":
    main()
