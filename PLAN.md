# Carousel Containment — план форку Grouping

## Що перевірено / що припущення

### НЕ перевірено (bash-команди не були схвалені)
- Версія Plasma — **припущення з TASK.md: 6.6.6** (Kubuntu 26.04)
- Наявність dev-пакетів (`libplasma-dev`, `extra-cmake-modules`, `qt6-base-dev`, `qt6-declarative-dev`, `libkf6*-dev`) — **не перевірено**
- Клон kdeplasma-addons — **не виконано**, структура grouping нижче — за публічним кодом invent.kde.org
- Шляхи встановлення плагінів (`qtpaths6 --plugin-dir`) — **не перевірено**

### Перевірено
- TASK.md прочитано повністю
- Репозиторій plasma-carousel-cpp порожній (тільки TASK.md, гілка master)

---

## Структура applets/grouping (за публічним кодом kdeplasma-addons 6.x)

```
applets/grouping/
├── CMakeLists.txt
├── package/
│   ├── metadata.json            # KPackage metadata, type=Plasma/Containment
│   └── contents/
│       └── ui/
│           ├── main.qml         # fullRepresentation (таби, список аплетів)
│           └── CompactRepresentation.qml  # compact (іконка на панелі)
└── lib/                         # (або container/)
    ├── CMakeLists.txt
    ├── groupingcontainment.h
    ├── groupingcontainment.cpp  # C++ Plasma::Containment subclass
    └── (можливо abstractgroupableitem.h/cpp, groupmodel, тощо)
```

**Ключове**: `GroupingContainment` наслідує `Plasma::Containment` — це дає можливість вміщувати інші аплети (applet nesting). Без C++ containment QML-плазмоїд не може бути контейнером.

Metadata.json містить `"KPlugin": {"Id": "org.kde.plasma.grouping"}` і `"X-Plasma-ContainmentType": "Panel"` (або Custom).

---

## Кроки форку

### 1. Клон джерел (одноразово)
```bash
mkdir -p src && cd src
git clone --depth 1 -b v6.6.6 https://invent.kde.org/plasma/kdeplasma-addons.git
```
Якщо тег `v6.6.6` не існує — спробувати `Plasma/6.6.6`, `v6.2.5`, або знайти найближчий через `git ls-remote --tags`.

### 2. Копіювання файлів grouping → carousel
```
cp -r src/kdeplasma-addons/applets/grouping/ carousel-containment/
```

### 3. Перейменування
| Що | Було | Стане |
|----|------|-------|
| Plugin ID | `org.kde.plasma.grouping` | `org.uw5eg0.carousel.container` |
| C++ клас | `GroupingContainment` | `CarouselContainment` |
| Файли | `groupingcontainment.{h,cpp}` | `carouselcontainment.{h,cpp}` |
| CMake target | `plasma_applet_grouping` | `plasma_applet_carousel` |
| metadata.json | Name: Grouping | Name: Carousel |

### 4. Зміни в QML
- **CompactRepresentation.qml**: замість іконки/табів — `[<] [compact поточного аплета] [>]`
  - `RowLayout { Button{<} ; Loader{currentApplet.compactRep} ; Button{>} ; Button{▲} }`
  - Колесо миші (`MouseArea.onWheel`) — перемикання
- **main.qml (fullRepresentation)**: замість табів — `fullRepresentation` поточного аплета + список аплетів із кнопками ↑↓ для зміни порядку
- **Нова логіка «follow updates»**: підписатись на `Applet.statusChanged` / `Applet.activated` кожного вкладеного аплета; при зміні — `currentIndex = thatApplet`

### 5. C++ зміни (мінімальні)
- Перейменувати клас і реєстрацію плагіна
- Якщо `follow updates` потребує C++ сигналу — додати `Q_PROPERTY(int currentIndex ...)` і сигнал `currentIndexChanged`
- Переконатись, що `constraintsEvent()` / `appletAdded()` / `appletRemoved()` коректні

### 6. CMakeLists.txt (кореневий, для цієї теки)
```cmake
cmake_minimum_required(VERSION 3.20)
project(plasma-carousel-containment)

find_package(ECM REQUIRED)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings)

find_package(Qt6 REQUIRED COMPONENTS Quick Qml)
find_package(KF6 REQUIRED COMPONENTS Plasma Package)
# або find_package(Plasma) — залежить від версії

add_subdirectory(carousel-containment)
```

### 7. Встановлення
- **C++ плагін (.so)**: `${KDE_INSTALL_PLUGINDIR}/plasma/containments/` — зазвичай `/usr/lib/x86_64-linux-gnu/qt6/plugins/plasma/containments/`
  - **Проблема**: це системний шлях, потрібен sudo
  - **Можливий workaround**: `QT_PLUGIN_PATH=~/.local/lib/plasma/containments plasmashell --replace`
  - Або `cmake -DCMAKE_INSTALL_PREFIX=~/.local` + переконатись, що Plasma бачить цей шлях
- **QML package**: `kpackagetool6 -t Plasma/Containment -i package/` або `cmake install` в `~/.local/share/plasma/plasmoids/`

### 8. Тестування
```bash
# Збірка
mkdir build && cd build
cmake .. -DCMAKE_INSTALL_PREFIX=$HOME/.local
make -j$(nproc)
make install

# Запуск (в окремому терміналі)
QT_PLUGIN_PATH=$HOME/.local/lib/qt6/plugins plasmashell --replace

# Або kquitapp6 plasmashell && QT_PLUGIN_PATH=... plasmashell
```
Додати аплет через «Add Widgets» → шукати «Carousel».

---

## Ризики

| Ризик | Серйозність | Коментар |
|-------|-------------|----------|
| C++ плагін потребує системного шляху | Високий | `QT_PLUGIN_PATH` може допомогти, але не гарантовано |
| ABI-сумісність при оновленні Plasma | Середній | Збірка проти системних хедерів — при оновленні Plasma треба перезбирати |
| Grouping може бути видалений/змінений в нових версіях | Низький | Форк незалежний, але при оновленні Plasma може зникнути API |
| `follow updates` — невідомо який сигнал ловити | Середній | Треба перевірити `Plasma::Applet::status()` і `statusChanged` — може бути достатньо |
| Тег v6.6.6 може не існувати | Низький | Є fallback: шукати інші теги або main branch |
| Dev-пакети можуть бути не встановлені | Потрібна перевірка | `sudo apt install libplasma-dev extra-cmake-modules qt6-base-dev qt6-declarative-dev` |

---

## Перший крок після схвалення плану
1. `apt list --installed | grep libplasma` — перевірити пакети
2. Клон kdeplasma-addons → прочитати реальну структуру grouping
3. Копіювати, перейменувати, зібрати мінімальний containment без змін QML
4. Переконатись, що він з'являється в «Add Widgets»
5. Потім міняти QML на карусель
