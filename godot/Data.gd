# Данные-таблицы GUNFALL: оружие, враги, темы, реликвии, прогрессия.
# Чистые константы без логики — правки баланса/контента живут здесь.

const THEMES := [
	{ "name": "Изумрудные пещеры", "sky0": "#0e1830", "sky1": "#1d3250", "hill_far": "#15233c", "hill_near": "#1b2c4a",
	  "ground": "#2c3a55", "top": "#58c98f", "plat": "#7fdcae", "spike": "#bcd0ff", "weather": "spores", "wcol": "#9ff0c0", "lava": "#37e0c0" },
	{ "name": "Багровые руины", "sky0": "#180d1c", "sky1": "#3a1c33", "hill_far": "#241229", "hill_near": "#301a37",
	  "ground": "#3d2438", "top": "#e0707a", "plat": "#f29a8e", "spike": "#ffd3c0", "weather": "embers", "wcol": "#ff9a5a", "lava": "#ff5a2a" },
	{ "name": "Ледяные шахты", "sky0": "#0b1426", "sky1": "#1d3a55", "hill_far": "#142339", "hill_near": "#1b2f4a",
	  "ground": "#31415f", "top": "#8fd8f2", "plat": "#b5e8fa", "spike": "#e8f6ff", "weather": "snow", "wcol": "#e8f6ff", "lava": "#3aa0ff" },
	{ "name": "Токсичные топи", "sky0": "#0d1612", "sky1": "#1d3328", "hill_far": "#13241b", "hill_near": "#1a3124",
	  "ground": "#2b3d31", "top": "#a8d65c", "plat": "#c6ec85", "spike": "#e9ffc9", "weather": "bubbles", "wcol": "#bff06a", "lava": "#9bff3a" },
	{ "name": "Пустынный форт", "sky0": "#1a1208", "sky1": "#3d2c14", "hill_far": "#291e0e", "hill_near": "#352813",
	  "ground": "#4a3a20", "top": "#e6b566", "plat": "#f4ce8d", "spike": "#ffe9c2", "weather": "sand", "wcol": "#f0d29a", "lava": "#ff7a1a" },
	{ "name": "Аметистовая бездна", "sky0": "#140a24", "sky1": "#33183f", "hill_far": "#1f1030", "hill_near": "#2d1942",
	  "ground": "#352048", "top": "#9d6bff", "plat": "#bf9bff", "spike": "#ecd9ff", "weather": "rain", "wcol": "#cba6ff", "lava": "#b24aff" },
	{ "name": "Обсидиановая кузница", "sky0": "#0a0608", "sky1": "#2a1210", "hill_far": "#170c0c", "hill_near": "#271514",
	  "ground": "#1d1618", "top": "#ff7a2a", "plat": "#ffae5c", "spike": "#ffd9a0", "weather": "ash", "wcol": "#9a8478", "lava": "#ff5a1a" },
]

# Профиль рельефа по биому (порядок как в THEMES) — задаёт «характер» карты.
# pit — шанс ямы, plateau — приподнятой площадки, cliff — резкого уступа;
# step_up — макс. высота уступа вверх (в пределах прыжка ≤3), lava — добавка к шансу лавы.
const TERRAIN := [
	{ "pit": 0.15, "pit_max": 4, "plateau": 0.12, "cliff": 0.06, "step_up": 2, "lava": 0.0 },   # Изумрудные пещеры — мягкий
	{ "pit": 0.17, "pit_max": 4, "plateau": 0.08, "cliff": 0.13, "step_up": 3, "lava": 0.18 },  # Багровые руины — рваный, лава
	{ "pit": 0.22, "pit_max": 4, "plateau": 0.10, "cliff": 0.06, "step_up": 2, "lava": 0.0 },   # Ледяные шахты — много ям
	{ "pit": 0.16, "pit_max": 4, "plateau": 0.12, "cliff": 0.06, "step_up": 2, "lava": 0.12 },  # Токсичные топи
	{ "pit": 0.10, "pit_max": 3, "plateau": 0.18, "cliff": 0.13, "step_up": 3, "lava": 0.0 },   # Пустынный форт — террасы
	{ "pit": 0.18, "pit_max": 4, "plateau": 0.16, "cliff": 0.15, "step_up": 3, "lava": 0.1 },   # Аметистовая бездна — вертикаль
	{ "pit": 0.20, "pit_max": 4, "plateau": 0.10, "cliff": 0.13, "step_up": 3, "lava": 0.35 },  # Обсидиановая кузница — рваный, много лавы
]

const WEAPONS := {
	"pistol":  { "name": "Пистолет", "dmg": 12, "cd": 16, "spd": 12.0, "spread": 0.035, "pellets": 1, "auto": false, "ammo": INF, "color": "#ffd86b", "kick": 1.2, "len": 15 },
	"smg":     { "name": "ПП «Оса»", "dmg": 8, "cd": 6, "spd": 13.0, "spread": 0.10, "pellets": 1, "auto": true, "ammo": 150, "color": "#9be8ff", "kick": 1.6, "len": 17 },
	"shotgun": { "name": "Дробовик", "dmg": 9, "cd": 44, "spd": 11.0, "spread": 0.24, "pellets": 6, "auto": false, "ammo": 32, "color": "#ffb077", "kick": 5.0, "len": 19 },
	"rifle":   { "name": "Винтовка", "dmg": 36, "cd": 34, "spd": 18.0, "spread": 0.012, "pellets": 1, "auto": false, "ammo": 30, "color": "#d3a4ff", "kick": 3.2, "len": 23 },
	"grenade": { "name": "Гранатомёт", "dmg": 34, "cd": 52, "spd": 9.5, "spread": 0.02, "pellets": 1, "auto": false, "ammo": 18, "color": "#9ef07f", "kick": 4.0, "len": 20, "gren": true, "radius": 80, "fuse": 80 },
	"railgun": { "name": "Рельса", "dmg": 55, "cd": 50, "spd": 22.0, "spread": 0.0, "pellets": 1, "auto": false, "ammo": 20, "color": "#7fd4ff", "kick": 3.6, "len": 25, "pierce": true },
	"flame":   { "name": "Огнемёт", "dmg": 4, "cd": 2, "spd": 0.0, "spread": 0.0, "pellets": 0, "auto": true, "ammo": 240, "color": "#ff7a3d", "kick": 0.6, "len": 18, "flame": true, "range": 132.0, "cone": 0.5 },
	"ricochet": { "name": "Рикошет", "dmg": 11, "cd": 9, "spd": 13.0, "spread": 0.05, "pellets": 1, "auto": true, "ammo": 96, "color": "#b9ff6b", "kick": 1.4, "len": 18, "bounce": 3 },
	"minigun": { "name": "Миниган", "dmg": 5, "cd": 3, "spd": 14.0, "spread": 0.15, "pellets": 1, "auto": true, "ammo": 350, "color": "#ffe066", "kick": 0.9, "len": 20 },
	"magnum":  { "name": "Магнум", "dmg": 64, "cd": 42, "spd": 21.0, "spread": 0.0, "pellets": 1, "auto": false, "ammo": 14, "color": "#ff6b8a", "kick": 6.5, "len": 22 },
}

const WEAPON_DROPS := ["smg", "shotgun", "rifle", "grenade", "railgun", "flame", "ricochet", "minigun", "magnum"]

const UPGRADES := [
	{ "id": "hp", "icon": "♥", "name": "Живучесть", "desc": "+25 к максимуму здоровья и лечение на 25" },
	{ "id": "dmg", "icon": "✦", "name": "Крупный калибр", "desc": "+15% к урону всего оружия" },
	{ "id": "rate", "icon": "≈", "name": "Скорострельность", "desc": "Оружие стреляет на 12% быстрее" },
	{ "id": "speed", "icon": "»", "name": "Лёгкие ботинки", "desc": "+10% к скорости бега" },
	{ "id": "djump", "icon": "⇈", "name": "Двойной прыжок", "desc": "Дополнительный прыжок в воздухе", "unique": true },
	{ "id": "steal", "icon": "+", "name": "Вампиризм", "desc": "+3 здоровья за каждое убийство" },
	{ "id": "armor", "icon": "▣", "name": "Бронежилет", "desc": "Получаемый урон снижен на 15%" },
	{ "id": "crit", "icon": "◎", "name": "Крит. патроны", "desc": "+10% шанс двойного урона" },
	{ "id": "jump", "icon": "↑", "name": "Пружины", "desc": "+8% к высоте прыжка" },
	{ "id": "shieldup", "icon": "▢", "name": "Энергощит", "desc": "+30 к запасу щита и медленное восстановление щита" },
	{ "id": "dashcd", "icon": "⟫", "name": "Реактивный рывок", "desc": "Перезарядка рывка быстрее на 30%" },
	{ "id": "blast", "icon": "✺", "name": "Сапёр", "desc": "+40% к радиусу и урону ваших взрывов" },
	{ "id": "magnet", "icon": "◈", "name": "Магнит", "desc": "Притягивает монеты и предметы с большего расстояния" },
	{ "id": "berserk", "icon": "⚡", "name": "Берсерк", "desc": "Чем длиннее серия убийств, тем выше урон" },
	{ "id": "incend", "icon": "🔥", "name": "Зажигательные", "desc": "Пули с шансом поджигают врагов (урон по времени)" },
	{ "id": "cryo", "icon": "❄", "name": "Крио-патроны", "desc": "Пули с шансом замораживают врагов (замедление)" },
	{ "id": "luck", "icon": "🍀", "name": "Удача", "desc": "Враги на 50% чаще роняют лут" },
]

const RELICS := {
	"glass":      { "icon": "🔺", "name": "Стеклянная пушка", "desc": "+60% урона, но −30% к макс. HP" },
	"vampire":    { "icon": "🩸", "name": "Кровавый клык", "desc": "+10 HP за каждое убийство" },
	"detonate":   { "icon": "💣", "name": "Детонатор", "desc": "Убитые враги взрываются" },
	"chain":      { "icon": "⚡", "name": "Цепь молний", "desc": "Попадания бьют током по ближнему врагу" },
	"midas":      { "icon": "🪙", "name": "Касание Мидаса", "desc": "+1 монета за каждое убийство" },
	"adrenaline": { "icon": "💉", "name": "Адреналин", "desc": "При HP < 35%: +40% к скорострельности и бегу" },
	"thorns":     { "icon": "🌵", "name": "Шипы", "desc": "Получив урон, ранит окружающих врагов" },
	"second":     { "icon": "🕊", "name": "Второе дыхание", "desc": "Раз за уровень переживает смертельный удар (1 HP)" },
	"overcharge": { "icon": "🔋", "name": "Сверхзаряд", "desc": "Ультимейт заряжается на 60% быстрее" },
	"frost":      { "icon": "❄", "name": "Морозная аура", "desc": "Близкие враги замедляются" },
	"regen":      { "icon": "🌿", "name": "Регенерация", "desc": "Медленно восстанавливает здоровье" },
	"executioner":{ "icon": "🪓", "name": "Палач", "desc": "+50% урона по врагам с HP < 30%" },
	"bulwark":    { "icon": "🛉", "name": "Бастион", "desc": "+25 щита в начале каждого уровня" },
	"hunter":     { "icon": "🎯", "name": "Охотник", "desc": "+30% урона по врагам с HP > 70% (первый удар больнее)" },
	"siphon":     { "icon": "🛡", "name": "Сифон", "desc": "8% нанесённого урона возвращается щитом" },
	"splinter":   { "icon": "💥", "name": "Шрапнель", "desc": "Убитый враг выпускает осколки во все стороны" },
	"momentum":   { "icon": "🏃", "name": "Разгон", "desc": "Убийство ненадолго ускоряет бег и стрельбу" },
	"bloodlust":  { "icon": "🔥", "name": "Жажда крови", "desc": "Чем ниже HP, тем выше урон (до +50%)" },
	"vengeance":  { "icon": "⚔", "name": "Возмездие", "desc": "После получения урона следующее попадание ×2" },
}

# Редкость улучшений и реликвий: 1 обычная, 2 редкая, 3 легендарная.
# Влияет на цвет рамки/названия и на шанс выпадения (взвешенный по уровню).
const RARITY := {
	# улучшения
	"hp": 1, "dmg": 1, "rate": 1, "speed": 1, "jump": 1, "magnet": 1,
	"steal": 2, "armor": 2, "crit": 2, "shieldup": 2, "dashcd": 2, "cryo": 2, "incend": 2, "luck": 2,
	"djump": 3, "blast": 3, "berserk": 3,
	# реликвии
	"vampire": 1, "midas": 1, "thorns": 1, "regen": 1, "hunter": 1, "siphon": 1,
	"glass": 2, "detonate": 2, "frost": 2, "executioner": 2, "bulwark": 2, "momentum": 2, "bloodlust": 2, "splinter": 2, "adrenaline": 2,
	"chain": 3, "second": 3, "overcharge": 3, "vengeance": 3,
}

# Категории реликвий для синергий-наборов: атака / защита / поддержка.
# Набрав 3+ реликвии одной категории, получаешь бонус (5+ — усиленный).
const RELIC_CAT := {
	"glass": "off", "detonate": "off", "chain": "off", "executioner": "off", "hunter": "off",
	"splinter": "off", "bloodlust": "off", "vengeance": "off", "momentum": "off",
	"vampire": "def", "thorns": "def", "second": "def", "regen": "def", "siphon": "def", "bulwark": "def",
	"midas": "util", "adrenaline": "util", "overcharge": "util", "frost": "util",
}

# Модификаторы уровня: редкие события, меняющие правила всего уровня.
# Выпадают с 3-го уровня (не на боссах), баннер при входе + свой визуал.
const LEVEL_MODS := {
	"bloodmoon": { "icon": "🌑", "name": "Кровавая луна", "desc": "Враги быстрее и злее, но +1 монета за убийство" },
	"fog":       { "icon": "🌫", "name": "Мгла",          "desc": "Видимость ниже, но очки ×1.3" },
	"swarm":     { "icon": "🐝", "name": "Рой",           "desc": "Врагов заметно больше, но они слабее" },
	"goldrush":  { "icon": "💰", "name": "Золотая лихорадка", "desc": "Больше сундуков и +1 монета за убийство, но враги крепче" },
}

# Активные предметы (слот, клавиша E): мгновенные/area-способности с кулдауном
const ACTIVES := {
	"bomb":   { "icon": "💣", "name": "Бомба", "desc": "Взрыв по области у прицела", "cd": 300 },
	"blink":  { "icon": "✦", "name": "Блинк", "desc": "Телепорт к прицелу + i-кадры", "cd": 220 },
	"freeze": { "icon": "❄", "name": "Заморозка", "desc": "Замораживает врагов вокруг", "cd": 480 },
	"medkit": { "icon": "✚", "name": "Аптечка", "desc": "Мгновенно +40 HP", "cd": 600 },
	"nova":   { "icon": "✺", "name": "Щит-нова", "desc": "Щит + отталкивающая волна", "cd": 480 },
	"turret": { "icon": "🛠", "name": "Турель", "desc": "Ставит авто-турель, что стреляет по врагам", "cd": 540 },
	"slowmo": { "icon": "⏳", "name": "Хроно-поле", "desc": "Замедляет время на пару секунд", "cd": 540 },
}

# Классы персонажей: разные стартовые наборы (разблок за «ядра»)
const CLASSES := [
	{ "id": "soldier",  "icon": "🔫", "name": "Солдат", "desc": "Сбалансирован. Старт: пистолет + ПП «Оса».", "cost": 0 },
	{ "id": "berserk",  "icon": "🔥", "name": "Берсерк", "desc": "+20% урон, −20% HP. Старт: дробовик + огнемёт.", "cost": 12 },
	{ "id": "ghost",    "icon": "💨", "name": "Призрак", "desc": "+30% скорость, двойной прыжок, быстрый рывок, −15% HP. Старт: винтовка.", "cost": 12 },
	{ "id": "engineer", "icon": "⚙", "name": "Инженер", "desc": "Старт: рикошет + гранатомёт, актив «Щит-нова».", "cost": 15 },
	{ "id": "tank",     "icon": "🛡", "name": "Танк", "desc": "+60% HP, броня, старт со щитом, −10% скорость.", "cost": 15 },
]

# Мета-прогрессия: постоянные улучшения между забегами за «ядра»
const META := {
	"vitality":    { "icon": "♥", "name": "Закалка", "desc": "+20 к стартовому HP за уровень", "cost": [4, 7, 11], "max": 3 },
	"power":       { "icon": "✦", "name": "Мощь", "desc": "+6% к урону за уровень", "cost": [5, 9, 14], "max": 3 },
	"swift":       { "icon": "»", "name": "Прыть", "desc": "+5% к скорости бега за уровень", "cost": [4, 8], "max": 2 },
	"fortune":     { "icon": "◉", "name": "Богатство", "desc": "+5 стартовых монет за уровень", "cost": [3, 6, 9], "max": 3 },
	"munitions":   { "icon": "▸", "name": "Арсенал", "desc": "Старт со случайным доп. оружием", "cost": [10], "max": 1 },
	"relic_start": { "icon": "🔮", "name": "Наследие", "desc": "Старт со случайной реликвией", "cost": [16], "max": 1 },
	"discount":    { "icon": "%", "name": "Скидки", "desc": "−12% к ценам в магазине за уровень", "cost": [6, 11], "max": 2 },
}

const ACHIEVEMENTS := [
	{ "id": "first_blood", "name": "Первая кровь", "desc": "Убить первого врага" },
	{ "id": "combo_master", "name": "Мастер серий", "desc": "Серия из 10 убийств" },
	{ "id": "boss_slayer", "name": "Победитель боссов", "desc": "Одолеть босса" },
	{ "id": "arsenal", "name": "Арсенал", "desc": "Носить 4 оружия одновременно" },
	{ "id": "deep_diver", "name": "Глубоко", "desc": "Дойти до 10-го уровня" },
	{ "id": "sharpshooter", "name": "Снайпер", "desc": "Точность 90%+ за забег (30+ выстрелов)" },
	{ "id": "high_score", "name": "Богач", "desc": "Набрать 1000 очков за забег" },
	{ "id": "survivor", "name": "Живучий", "desc": "Прожить 3 минуты за один забег" },
	{ "id": "combo_legend", "name": "Неудержимый", "desc": "Серия из 25 убийств" },
	{ "id": "rich_legend", "name": "Магнат", "desc": "Набрать 2500 очков за забег" },
	{ "id": "coin_hoard", "name": "Скопидом", "desc": "Накопить 60 монет за забег" },
	{ "id": "relic_collector", "name": "Сила реликвий", "desc": "Собрать 5 реликвий за один забег" },
	{ "id": "overkill", "name": "Перебор", "desc": "Нанести 5000 урона за забег" },
	{ "id": "marksman", "name": "Меткий стрелок", "desc": "Точность 95%+ за забег (50+ выстрелов)" },
	{ "id": "nightmare", "name": "Кошмар наяву", "desc": "Победить босса на «Кошмаре» и выше" },
	{ "id": "iron_run", "name": "Двужильный", "desc": "Прожить 5 минут за один забег" },
	{ "id": "deep_legend", "name": "Бездна зовёт", "desc": "Дойти до 15-го уровня" },
	{ "id": "daily_player", "name": "Сегодня мой день", "desc": "Сыграть забег дня" },
	{ "id": "veteran", "name": "Ветеран", "desc": "1000 убийств за всё время" },
	{ "id": "boss_legend", "name": "Гроза боссов", "desc": "Победить 10 боссов за всё время" },
	{ "id": "treasure_hunter", "name": "Кладоискатель", "desc": "Открыть 25 сундуков за всё время" },
	{ "id": "persistent", "name": "Упорство", "desc": "Сыграть 25 забегов" },
	{ "id": "completionist", "name": "Первопроходец", "desc": "Открыть весь контент коллекции" },
]

# Разблокируемый контент: эти оружие/реликвии открываются по достижению порога
# пожизненной статистики. Всё, чего здесь нет, доступно с самого начала.
const UNLOCK_DEFS := [
	{ "id": "rifle",    "kind": "weapon", "stat": "deep",   "need": 3 },
	{ "id": "grenade",  "kind": "weapon", "stat": "kills",  "need": 150 },
	{ "id": "flame",    "kind": "weapon", "stat": "chests", "need": 8 },
	{ "id": "railgun",  "kind": "weapon", "stat": "bosses", "need": 1 },
	{ "id": "ricochet", "kind": "weapon", "stat": "deep",   "need": 8 },
	{ "id": "minigun",  "kind": "weapon", "stat": "kills",  "need": 500 },
	{ "id": "magnum",   "kind": "weapon", "stat": "bosses", "need": 4 },
	{ "id": "detonate",    "kind": "relic", "stat": "kills",  "need": 250 },
	{ "id": "glass",       "kind": "relic", "stat": "kills",  "need": 450 },
	{ "id": "executioner", "kind": "relic", "stat": "bosses", "need": 2 },
	{ "id": "chain",       "kind": "relic", "stat": "bosses", "need": 3 },
	{ "id": "adrenaline",  "kind": "relic", "stat": "deep",   "need": 5 },
	{ "id": "overcharge",  "kind": "relic", "stat": "deep",   "need": 6 },
	{ "id": "bulwark",     "kind": "relic", "stat": "deep",   "need": 10 },
	{ "id": "frost",       "kind": "relic", "stat": "runs",   "need": 4 },
	{ "id": "second",      "kind": "relic", "stat": "deaths", "need": 4 },
]

# Алтари-события: интерактив с выбором риск/награда (1 шт. на уровень с шансом).
const SHRINES := {
	"blood":  { "icon": "🩸", "title": "Кровавый алтарь",  "offer": "Отдать 25% макс. HP в обмен на случайную реликвию." },
	"gamble": { "icon": "🎲", "title": "Алтарь азарта",     "offer": "Поставить половину монет: с шансом 50% удвоить ставку, иначе потерять." },
	"power":  { "icon": "🔥", "title": "Алтарь ярости",     "offer": "+25% к урону на весь забег, но пробудить волну врагов." },
	"spring": { "icon": "✨", "title": "Целебный источник", "offer": "Восстановить всё здоровье и щит ценой −10% к максимуму HP." },
	"greed":  { "icon": "🪙", "title": "Алтарь жадности",  "offer": "+1 монета за каждое убийство до конца забега, но получаемый урон +15%." },
	"chrono": { "icon": "⏳", "title": "Алтарь Хроноса",   "offer": "Рывок и активный предмет перезаряжаются на 25% быстрее, но −10 макс. HP." },
}

const ENEMY_BASE := {
	"walker":  { "w": 26, "h": 28, "hp": 30, "spd": 1.1, "dmg": 12, "score": 10, "cd": 0, "fly": false },
	"shooter": { "w": 26, "h": 30, "hp": 42, "spd": 0.0, "dmg": 9, "score": 20, "cd": 105, "fly": false },
	"flyer":   { "w": 24, "h": 20, "hp": 22, "spd": 1.7, "dmg": 10, "score": 15, "cd": 0, "fly": true },
	"tank":    { "w": 36, "h": 38, "hp": 130, "spd": 0.55, "dmg": 11, "score": 45, "cd": 135, "fly": false },
	"exploder": { "w": 22, "h": 24, "hp": 18, "spd": 1.9, "dmg": 24, "score": 18, "cd": 0, "fly": false, "radius": 62 },
	"sniper":  { "w": 26, "h": 30, "hp": 34, "spd": 0.0, "dmg": 26, "score": 30, "cd": 0, "fly": false },
	"splitter": { "w": 30, "h": 30, "hp": 52, "spd": 0.9, "dmg": 12, "score": 25, "cd": 0, "fly": false },
	"charger": { "w": 34, "h": 32, "hp": 95, "spd": 0.7, "dmg": 18, "score": 35, "cd": 0, "fly": false },
	"healer":  { "w": 24, "h": 24, "hp": 36, "spd": 1.5, "dmg": 6, "score": 45, "cd": 150, "fly": true },
	"orbiter": { "w": 24, "h": 24, "hp": 46, "spd": 2.0, "dmg": 11, "score": 38, "cd": 95, "fly": true, "orbit": 150 },
	"totem":   { "w": 22, "h": 34, "hp": 70, "spd": 0.0, "dmg": 6, "score": 50, "cd": 0, "fly": false },
	"shieldbearer": { "w": 30, "h": 32, "hp": 60, "spd": 0.8, "dmg": 14, "score": 42, "cd": 0, "fly": false },
	"bomber":  { "w": 26, "h": 20, "hp": 40, "spd": 1.6, "dmg": 15, "score": 40, "cd": 130, "fly": true },
	"shard":   { "w": 14, "h": 16, "hp": 10, "spd": 2.4, "dmg": 8, "score": 5, "cd": 0, "fly": false },
	"boss":    { "w": 70, "h": 74, "hp": 900, "spd": 0.9, "dmg": 18, "score": 300, "cd": 70, "fly": false },
}
