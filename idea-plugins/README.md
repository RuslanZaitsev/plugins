# IntelliJ IDEA plugins — offline bundle

Плагины JetBrains для офлайн-установки на машине без доступа к Marketplace.
Аналог того, что в `vscode-java-vsix` сделано для VSCode.

## 1. Выбрать папку под свою версию IDE

Плагины JetBrains жёстко привязаны к ветке IDE через `until-build`, поэтому архив
из чужой ветки IDEA просто откажется ставить. Версию смотреть в **Help → About**,
строка вида `Build #IU-262.10968.75`.

| Папка | Ветка | Версия IDEA |
|---|---|---|
| `2025.2-252` | 252 | 2025.2.x |
| `2025.3-253` | 253 | 2025.3.x |
| `2026.1-261` | 261 | 2026.1.x |
| `2026.2-262` | 262 | 2026.2.x |

Лишние папки можно удалить. Для 2026.3 (263, EAP) плагины на момент сборки
(2026-10-09) ещё не выпущены.

## 2. Состав

| Плагин | Назначение | Аналог в VSCode-паке |
|---|---|---|
| `jboss-drools-*` | DRL: подсветка, резолв, навигация | `jim-moody.drools`, `jhhtaylor.drools-formatter` |
| `protoeditor-*` | Protocol Buffers (`.proto`) | `zxh404.vscode-proto3`, `bufbuild.vscode-buf` |
| `graphql-*` | `.graphql`: схемы, запросы, автодополнение | `GraphQL.vscode-graphql*` |
| `spring-graphql-*` | Spring for GraphQL: эндпоинты, навигация | — |
| `bigdatatools-kafka-*` | Kafka: топики, консьюмеры, produce/consume | `jeppeandersen.vscode-kafka` |
| `bigdatatools-core-*` | зависимость Kafka, **только в ветке 252** | — |

Остального из VSCode-пака в IDEA не нужно — Maven, Spring/Spring Boot, YAML,
XML, Docker, Kubernetes, HTTP Client, Database Tools, декомпилятор, git и
инспекции качества кода встроены в Ultimate.

Чего в IDEA нет совсем: визуальных редакторов BPMN и DMN. Замены
`kie-ba-bundle` у JetBrains не существует, для `.bpmn`/`.dmn` остаётся VSCode.

## 3. Требования

* **IntelliJ IDEA Ultimate.** Drools, Kafka, GraphQL и Spring GraphQL объявляют
  `<plugin id="com.intellij.modules.ultimate"/>` и в Community Edition не
  работают. Protocol Buffers — единственный, который ставится и в CE.
* Должны быть включены bundled-плагины (Settings → Plugins → Installed):
  * **JavaScript and TypeScript** — обязательная зависимость GraphQL;
  * **Database Tools and SQL** — даёт `intellij.grid.plugin`, обязательную
    зависимость Big Data Tools Core (нужно только для ветки 252);
  * **YAML** — зависимость GraphQL.

## 4. Установка

### Вариант A: через GUI (рекомендуется)

**Settings → Plugins → ⚙ → Install Plugin from Disk…**, выбрать .zip
(распаковывать не нужно). Офлайн зависимости не резолвятся, поэтому в ветке 252
порядок важен:

1. `bigdatatools-core-*.zip`
2. `bigdatatools-kafka-*.zip`
3. остальные — в любом порядке

Перезапустить IDE один раз в конце.

### Вариант B: скриптом

Закрыть IDEA, затем:

```powershell
.\install.ps1 -Branch 2026.2-262
```

Скрипт сам находит `%APPDATA%\JetBrains\IntelliJIdea<version>\plugins` (берёт
самую свежую, если их несколько) и распаковывает туда все архивы ветки. Если
конфигов несколько или путь нестандартный — задать явно:

```powershell
.\install.ps1 -Branch 2026.2-262 -PluginsDir "$env:APPDATA\JetBrains\IntelliJIdea2026.2\plugins"
```

## 5. Если версия IDE не совпала

IDEA скажет `Plugin is not compatible with this installation`. Тогда нужен архив
точно под свой билд — скачивается на машине с интернетом так (endpoint сам
отдаёт совместимую версию):

```
https://plugins.jetbrains.com/pluginManager?action=download&id=<xmlId>&build=IU-<build>
```

`<build>` — первые два сегмента из Help → About, например `IU-262.10968`.
`<xmlId>`:

```
com.intellij.drools
idea.plugin.protoeditor
com.intellij.lang.jsgraphql
com.intellij.spring.graphql
com.intellij.bigdatatools.kafka
com.intellij.bigdatatools.core
```

Отдельная оговорка по ветке 252: `bigdatatools-core-252.28539.97` требует
`since-build 252.28539` (это 2025.2.4+). На более раннем 2025.2.x нужно
скачать Core под свой билд по ссылке выше.

## 6. Лучше, чем всё это

Если в корпоративной сети есть зеркало плагинов JetBrains —
**Settings → Plugins → ⚙ → Manage Plugin Repositories** и URL на
`updatePlugins.xml`. После этого Marketplace работает штатно, с обновлениями.
Формат тривиальный (xml + zip по HTTP), поднимается в raw-репозитории Nexus —
стоит спросить у админов, может уже существует.

## 7. Проверка целостности

```powershell
Get-FileHash -Algorithm SHA256 .\2026.2-262\*.zip | Format-List
```

Сверить с `checksums.txt`.
