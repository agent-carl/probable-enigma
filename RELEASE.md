# Выпуск GUNFALL — чек-лист релиза

Состояние кода: **релиз-кандидат v1.0.0**. Логика покрыта headless-тестами
(60 секций, включая фузз), UI проверен автотестом на переполнения (RU/EN), производительность
~1.4 мс/кадр при 180+ врагах.

## 1. Билды (уже автоматизировано)

Пуш тега `v1.0.0` запускает workflow «GUNFALL build»: соберёт Windows/Linux
и создаст релиз с архивами (веб-версия не планируется — релиз только в Steam).
Кнопка «Run workflow» станет доступна после попадания workflow в основную
ветку (например, мержем PR #1). Либо локально:

```bash
godot --headless --path godot --export-release "Windows" build/windows/gunfall.exe
godot --headless --path godot --export-release "Linux"   build/linux/gunfall.x86_64
```

**macOS** собирается только на маке (нужна подпись/нотаризация Apple):
в Godot добавить пресет macOS (Project → Export → Add → macOS), указать
Bundle Identifier (например `com.yourname.gunfall`), подписать
Developer ID-сертификатом и пройти нотаризацию (`xcrun notarytool`).

## 2. Steam (делается на вашей машине, ~вечер работы)

1. **Steamworks**: оплатить Steam Direct ($100), создать приложение,
   получить AppID.
2. **GodotSteam**: скачать GDExtension-версию для Godot 4.x
   (https://godotsteam.com), положить `addons/godotsteam` в проект,
   в корень проекта — `steam_appid.txt` с вашим AppID (только для отладки,
   в релизный билд не класть).
3. **Интеграция уже в коде** (`Game.gd`): инициализация (`_init_steam`),
   `run_callbacks()` каждый кадр и зеркалирование ачивок из `unlock()` —
   всё активируется само при наличии GodotSteam, без него тихо
   пропускается. Осталось одно: заменить `STEAM_APP_ID` (сейчас 480 —
   тестовый SpaceWar) на ваш AppID.
4. **Ачивки Steam**: в Steamworks завести ачивки с API Name = `ACH_<ID>`
   (заглавными) по списку из `Data.gd::ACHIEVEMENTS` — 23 шт.:
   ACH_FIRST_BLOOD, ACH_COMBO_MASTER, ... Код шлёт их автоматически.
5. **Облачные сейвы**: в Steamworks включить Steam Cloud для
   `gunfall.cfg` (авто-облако по пути Godot `user://`) — кода не требует.
6. **Старые GPU**: игра проверена и на GL Compatibility; при жалобах на
   запуск без Vulkan — параметр запуска в Steam:
   `--rendering-driver opengl3`.
7. **Страница**: capsule-арт, 5+ скриншотов (в игре есть дебаг-флаги
   `--lvl N`, `--boss`, `--portal` для чистых кадров), трейлер, описание
   RU+EN (тексты механик — в `README.md`).

## 3. Перед загрузкой в Steam

- [ ] Прогнать тесты: `godot --headless --path godot --script res://Test.gd`
- [ ] Windows-билд: запуск, звук, сейв в `%APPDATA%/Godot/app_userdata/GUNFALL`
- [ ] Геймпад: меню и бой (поддержка уже в коде)
- [ ] Полноэкран (F11), V-Sync, размеры окна — экран настроек
- [ ] EN-локаль: переключить язык в настройках, пробежать меню
- [ ] Депо в Steamworks: windows + linux, ветка beta → проверка → default

## 4. Версии

Версия игры — `Game.gd::GAME_VERSION` (метка в углу меню). Формат сейва —
`SAVE_VERSION` с заделом миграции `_migrate_save()`: при изменении структуры
`user://gunfall.cfg` поднять номер и написать миграцию.
