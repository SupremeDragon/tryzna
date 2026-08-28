extends Node
## Шина подій. Системи спілкуються ЧЕРЕЗ НЕЇ, а не прямими викликами.
##
## Правило: якщо два модулі з `core/` знають один про одного напряму — це помилка
## архітектури. Через 20 годин розробки такий код злипається в один клубок.

## --- Світ і переходи ---
signal world_fold_started(from_mode: int, to_mode: int)
signal world_fold_finished(mode: int)

## --- Персонаж ---
signal player_died(cause: StringName)
signal player_revived()

## --- Реєстр діянь ---
signal deed_recorded(deed: Dictionary)

## --- Сюжет ---
signal chapter_started(chapter_id: StringName)
signal quest_state_changed(quest_id: StringName, state: StringName)

## --- Інтерфейс ---
signal notice(text: String)
