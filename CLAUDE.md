# Правила проекта

- Любое изменение кода сопровождается тестами, **и юнит-, и e2e-тестами**.
  Юнит: правила одного модуля (`tests/roblox/run.luau`, экран — `tests/roblox/ui.luau`).
  E2E: целый сценарий игрока (`tests/web/run.mjs` для веб-версии,
  `tests/roblox/e2e.luau` для Roblox: весь сервер в Lune с заглушками Roblox, плюс экран на Vide).
  Что заглушки не видят — в `tests/cloud/ingame.luau` (настоящий Roblox через Open Cloud).
- Перед коммитом: `npm test` должен быть зелёным, а `npm run build` должен собирать `roblox/DinoEggCatch.rbxlx`.
- Инструменты: `rokit install` (Rojo, Lune). Экран — Vide, меню — TopbarPlus, сохранение — ProfileStore
  (`roblox/Packages`, сами пакеты не правим).
- Экран: логику кладём в `UI/Logic.luau` (чистые функции), вид — в `UI/App.luau`, всё внешнее
  передаём через `deps`, чтобы экран тестировался в Lune.
- Сервер не верит клиенту: позиции, скорость, аргументы и частоту запросов проверяет сервер (`roblox/src/server/AntiCheat.lua`).
- Для проверки и тестов есть навык `/review-and-test`.
