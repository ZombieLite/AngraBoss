=====================
AngraBoss
by Alexander.3
http://vk.com/zombielite
Telegram: @zombielite
=====================
=====================
Интеграция
=====================
Делаем все по данной инструкции:
https://vk.com/page-70119885_55732395

=====================
Настройка босса
=====================
#define MAPCHOOSER					// Включите это, если используете API плагин мапчузера.
#define NEW_SEARCH					// Если включено, то босс будет преследовать ближайшего игрока

#define AGGRESSIVE_ATTACK	random_num(1, 2)	// Кол-во агрессии за убийство
#define AGGRESSIVE_TENTACLE	random_num(5, 10)	// Кол-во агрессии за убийство с помощью тентаклей
#define AGGRESSIVE_POISON	random_num(10, 20)	// Кол-во агрессии за ядовитое убийство
#define AGGRESSIVE_FLAME	random_num(1, 5)	// Кол-во агрессии за бараш-убийство
#define AGGRESSIVE_PASSIVE	random_num(1, 1)	// Кол-во агрессии через n-время

new const msg_boxhp[] =		"Box health: %d"	// Наименование ящика
const Float:box_health =	0.1			// Здоровье ящика ( коэффициент )

Все остальные настройки в файле configs/zl/zl_angraboss.ini