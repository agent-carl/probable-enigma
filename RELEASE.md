# Выпуск GUNFALL — чек-лист релиза

Состояние кода: **релиз-кандидат v1.0.0**. Логика покрыта headless-тестами
(59 секций), UI проверен автотестом на переполнения (RU/EN), производительность
~1.4 мс/кадр при 180+ врагах.

## 1. Билды (уже автоматизировано)

**GitHub Actions → «GUNFALL build» → Run workflow**, в поле версии ввести
`v1.0.0` → workflow соберёт Windows/Linux/Web, создаст тег и релиз с архивами.
Либо локально:

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
3. **Инициализация** — единственная точка входа в коде:
   в `Game.gd::_ready()` добавить:
   ```gdscript
   if Engine.has_singleton("Steam"):
       Steam.steamInitEx(true, ВАШ_APPID)
   ```
4. **Ачивки Steam**: все достижения проходят через одну функцию
   `Game.gd::unlock(id)` — добавить туда одну строку:
   ```gdscript
   if Engine.has_singleton("Steam") and Steam.loggedOn():
       Steam.setAchievement("ACH_" + id.to_upper())
       Steam.storeStats()
   ```
   В Steamworks завести ачивки с API Name = `ACH_<ID>` по списку из
   `Data.gd::ACHIEVEMENTS` (23 шт.: FIRST_BLOOD, COMBO_MASTER, ...).
5. **Облачные сейвы**: в Steamworks включить Steam Cloud для
   `gunfall.cfg` (авто-облако по пути Godot `user://`) — кода не требует.
6. **Страница**: capsule-арт, 5+ скриншотов (в игре есть дебаг-флаги
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
