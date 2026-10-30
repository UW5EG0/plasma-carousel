# Carousel Container (`org.uw5eg0.carousel.container`)

C++ containment-плазмоїд для панелі KDE Plasma 6 — форк `applets/grouping` з kdeplasma-addons v6.6.6.
На панелі показує один вкладений віджет за раз: `[<] [поточний віджет] [>] [▲]`.

Не плутати з QML-плазмоїдом `org.uw5eg0.carousel` (`~/workspace/plasma-carousel`) — це окрема річ.

## Користування

**Панель**
- `<` / `>` або колесо миші — гортати (по колу).
- ПКМ на віджеті — його власне контекстне меню.
- Клік по compact-віджету (напр. таймеру) відкриває попап каруселі одразу на ньому.
- `▲` — відкрити/закрити попап.
- Додавання: перетягнути віджет з «Додати віджети» на карусель (або «+» у попапі).

**Попап**
- Ліворуч — список віджетів: клік = вибрати (міняє і панель, і попап), ↑/↓ = порядок, кошик = видалити.
- Праворуч — бар вибраного віджета: іконка, назва, `+` (режим редагування з оглядачем віджетів),
  `×` (видалити вибраний), `☰` (контекстне меню віджета: налаштування тощо).
- Під баром — сам віджет:
  - віджети з окремим повним виглядом (таймер, монітори) — їхній справжній `fullRepresentation`;
  - віджети лише з одним виглядом (`preferredRepresentation: fullRepresentation`, напр. Command Output)
    лишаються на панелі, а в попапі — **другий екземпляр** того самого компонента, живий і клікабельний.
- Видалення з можливістю «Скасувати» (Plasma): віджет одразу зникає з каруселі, після скасування
  повертається на попереднє місце.

**Налаштування** (ПКМ → «Налаштувати Карусель-контейнер…»)
- колесо миші вкл/викл;
- «follow updates» — перемикатися на віджет, що змінився. Тригери (окремо вмикаються):
  статус (Active / NeedsAttention), заголовок/іконка, текст тултіпа. Пауза між автоперемиканнями
  (дефолт 2 с). Не спрацьовує перші 3 с після старту, під курсором миші і при відкритому попапі.
  Універсального сигналу «вміст змінився» в Plasma немає — віджет, що не міняє ні статус, ні тултіп,
  follow не спровокує.

**Обмеження**
- Копія для однопредставлених віджетів показує той самий стан лише якщо віджет тримає дані поза
  своїм `fullRepresentation` (як Command Output: `widget.outputText` на корені). Віджет, що тримає стан
  усередині представлення, у копії показав би окремий стан.
- Скрипти Plasma (`evaluateScript`) вкладені віджети напряму не бачать (`desktopById` шукає лише
  top-level containment-и). Конфіг вкладених — через віджет каруселі:
  `w.currentConfigGroup = ["Applets", "<id>", "Configuration", "General"]; w.writeConfig(...)`,
  потім `plasmashell --replace` (живі віджети конфіг не перечитують).

## Залежності (Kubuntu 26.04)
```
sudo apt install libplasma-dev libkf6package-dev extra-cmake-modules \
    qt6-base-dev qt6-declarative-dev libkf6i18n-dev libkf6config-dev libkf6coreaddons-dev
```
`libplasma-dev` має бути тієї ж версії, що й встановлена Plasma (`plasmashell --version`).

## Збірка й встановлення (без sudo, у ~/.local)
```
cmake -B build -DCMAKE_INSTALL_PREFIX=$HOME/.local -DKDE_INSTALL_USE_QT_SYS_PATHS=OFF \
      -DKDE_INSTALL_QTPLUGINDIR=lib/x86_64-linux-gnu/qt6/plugins -DCMAKE_BUILD_TYPE=RelWithDebInfo
cmake --build build -j$(nproc)
cmake --install build
```
Результат: `~/.local/lib/x86_64-linux-gnu/qt6/plugins/plasma/applets/org.uw5eg0.carousel.container.so`
(QML вшитий у .so, окремого пакета немає).

Щоб plasmashell бачив `~/.local`, є env-скрипт (вже створено)
`~/.config/plasma-workspace/env/carousel-qtpluginpath.sh`:
```sh
export QT_PLUGIN_PATH="$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins${QT_PLUGIN_PATH:+:$QT_PLUGIN_PATH}"
```
Діє з наступного входу в сесію. Застосувати нову збірку без логаута:
```
QT_PLUGIN_PATH=$HOME/.local/lib/x86_64-linux-gnu/qt6/plugins setsid plasmashell --replace >/dev/null 2>&1 &
```
Якщо панель впала через плагін: `setsid plasmashell --replace >/dev/null 2>&1 &` (без змінної) і
прибрати/перейменувати env-скрипт.

## Після оновлення Plasma
Плагін лінкується з libplasma, ABI між мінорними версіями (6.6 → 6.7) не гарантований.
```
sudo apt install libplasma-dev     # dev тієї ж версії, що нова plasma
rm -rf build && <команди збірки вище>
QT_PLUGIN_PATH=... setsid plasmashell --replace >/dev/null 2>&1 &
```
Якщо в новій Plasma змінився grouping/systemtray — порівняти з клоном потрібного тегу
(`git clone --depth 1 -b vX.Y.Z https://invent.kde.org/plasma/kdeplasma-addons.git`).

## Структура
```
src/carouselcontainment.{h,cpp}  Plasma::Containment (CustomEmbedded): newTask, контекстне меню
                                 (showPlasmoidMenu / showPlasmoidMenuAt), showAddWidgets
src/metadata.json, src/main.xml  метадані; налаштування (порядок, поточний, колесо, follow)
src/qml/main.qml                 карусель на панелі, попап, follow updates, порядок, DnD, видалення
src/qml/OrderList.qml            список у попапі (вибір, ↑/↓, видалити)
src/qml/CompactApplet.qml        expander вкладених без власного діалогу (як у systray)
src/qml/config.qml, ConfigGeneral.qml   сторінка налаштувань
```
Як влаштовано (з коду libplasma / systemtray v6.6.6):
- `CustomEmbedded` containment = `isContainment()` → його `main.qml` рендериться прямо в панелі.
- Вкладені аплети беруть `formFactor` панелі → самі показують compact.
- Кожен аплет — у wrapper всередині `StackLayout` (розмір через layout-рушій, приховані теж мають
  геометрію); поточний — за `wrapper.StackLayout.index`.
- Попап (`PlasmaCore.AppletPopup`): `expanded = true` створює `fullRepresentationItem`, який
  переноситься в попап; при закритті — у невидимий storage (як `preloadedStorage` у systray).
