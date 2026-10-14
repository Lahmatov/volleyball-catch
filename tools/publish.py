"""Публикует игру в БОЕВОЕ место Roblox: игроки сразу получают новую версию.

Запускает CI после зелёных тестов на ветке production (.github/workflows/tests.yml).
Переменные: ROBLOX_API_KEY, ROBLOX_UNIVERSE_ID, ROBLOX_PLACE_ID (боевые).
Вручную:  python3 tools/publish.py   (сначала прогони npm test!)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import roblox_cloud as cloud  # noqa: E402


def main(build=True):
    try:
        api_key = cloud.env("ROBLOX_API_KEY")
        universe = cloud.env("ROBLOX_UNIVERSE_ID")
        place = cloud.env("ROBLOX_PLACE_ID")
        path = cloud.build_place() if build else cloud.PLACE_FILE
        version = cloud.upload_place(api_key, universe, place, path, publish=True)
    except cloud.CloudError as e:
        cloud.fail(f"Не опубликовано: {e}")
    print(f"Опубликовано: версия {version}. Новые серверы уже с ней, старые обновятся при перезапуске.")
    return version


if __name__ == "__main__":
    main()
