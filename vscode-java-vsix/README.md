# VS Code offline pack: Java / Maven / Spring Boot / Kafka / YAML / gRPC

Набор `.vsix` для установки на машине без доступа к Marketplace.
Все пакеты скачаны с VS Code Marketplace, platform-specific собраны под **Windows x64**
(в имени файла суффикс `@win32-x64`).

## Установка

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Скрипт ставит пакеты в правильном порядке: оффлайн-установка не резолвит
`extensionDependencies`, поэтому `redhat.java` должен встать раньше всего Java-инструментария,
`redhat.vscode-yaml` — раньше Kubernetes, `mtxr.sqltools` — раньше драйвера PostgreSQL.

После установки — полный перезапуск VS Code и `code --list-extensions --show-versions`.

## Состав

### Java core
| Расширение | Что заменяет в IDEA |
|---|---|
| `redhat.java` | сам язык: индексация, навигация, рефакторинги, quick fixes (Eclipse JDT LS) |
| `vscjava.vscode-java-debug` | отладчик, hot code replace |
| `vscjava.vscode-java-test` | запуск JUnit 5, дерево тестов, покрытие |
| `vscjava.vscode-maven` | панель Maven, lifecycle, effective pom, архетипы |
| `vscjava.vscode-gradle` | панель Gradle, задачи, Kotlin DSL |
| `vscjava.vscode-java-dependency` | Project/Dependency view, «Maven Dependencies» |
| `vscjava.vscode-java-pack` | мета-пакет (ставится последним, просто связывает остальные) |
| `dgileadi.java-decompiler` | декомпиляция `.class` при переходе в библиотечный код |
| `shengchen.vscode-checkstyle` | инспекции Checkstyle |

### Spring
| Расширение | Что даёт |
|---|---|
| `vmware.vscode-spring-boot` | Spring Tools 4: навигация по бинам, автодополнение в `application.yml/properties`, live-данные запущенного приложения, подсветка `@RequestMapping`/`@Value`/SpEL |
| `vscjava.vscode-spring-boot-dashboard` | дашборд приложений: запуск/стоп/дебаг, список endpoint'ов и бинов |
| `vscjava.vscode-spring-initializr` | генерация проекта (нужен доступ к start.spring.io — в закрытом контуре бесполезен, но зависимостей не тянет) |
| `vmware.vscode-boot-dev-pack` | мета-пакет |

### Инфраструктура
| Расширение | Что даёт |
|---|---|
| `redhat.vscode-yaml` | YAML LS: схемы, валидация, формат (`application.yml`, k8s-манифесты) |
| `redhat.vscode-xml` | XML LS: `pom.xml` с автодополнением по схеме, Liquibase changelog, XSD/DTD |
| `jeppeandersen.vscode-kafka` | браузер кластера: топики, партиции, consumer groups, продюсер/консюмер прямо из `.kafka`-файлов |
| `bufbuild.vscode-buf` | protobuf LSP: навигация, формат, lint (см. примечание ниже) |
| `local.m2e-protobuf` | сгенерированные protoc-классы видны в Java без правки pom.xml (см. раздел ниже) |
| `zxh404.vscode-proto3` | подсветка и базовая навигация по `.proto` — запасной вариант, работает без внешних бинарников |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | кластеры, поды, логи, `kubectl`/OpenShift |
| `ms-azuretools.vscode-containers` | Dockerfile, compose, образы |

### Kotlin
| `fwcd.kotlin` | Kotlin LSP: автодополнение, переход к определению. Заметно слабее IDEA — для правок в Kotlin-модулях хватает, для активной разработки нет. |

### Качество, БД, git, UX
| Расширение | Что даёт |
|---|---|
| `mtxr.sqltools` + `mtxr.sqltools-driver-pg` | подключение к PostgreSQL, запросы, просмотр схемы — вместо окна Database |
| `humao.rest-client` | `.http`-файлы — прямой аналог HTTP Client из IDEA |
| `eamodio.gitlens` | blame, история строки, сравнение веток |
| `editorconfig.editorconfig` | `.editorconfig` |
| `usernamehw.errorlens` | ошибки и warning'и прямо в строке, как в IDEA |
| `k--kato.intellij-idea-keybindings` | раскладка горячих клавиш IntelliJ IDEA |


## Не ставятся по умолчанию (`optional/`)

В закрытом контуре без интернета от них нет пользы, только уведомления. `install.ps1` их не ставит.

| Пакет | Почему убран |
|---|---|
| `fwcd.kotlin` | language server в пакет не входит, расширение скачивает его с GitHub |
| `ms-kubernetes-tools.vscode-kubernetes-tools` | активируется на любом YAML (в том числе `application.yml`), без `kubectl`/`helm` предлагает скачать их с `dl.k8s.io` |

Поставить вручную, если понадобится: `code --install-extension .\optional\<файл>.vsix`.

## Что нужно на машине помимо расширений

- **JDK 21+** — на нём запускается языковой сервер JDT LS, независимо от версии Java в проекте.
  Плюс JDK, под который собирается проект (17). Оба прописываются в настройках.
- **Maven** (или wrapper в проекте) и `~/.m2/settings.xml` с внутренним Nexus.
- **buf** (опционально) — расширение `bufbuild.vscode-buf` по умолчанию скачивает бинарник
  с GitHub Releases. В закрытом контуре положить `buf.exe` руками и указать `"buf.path"`.
  Без этого LSP не стартует, но `zxh404.vscode-proto3` продолжит подсвечивать `.proto`.

Все настройки — в `settings.recommended.jsonc`, там же выключение всего, что ходит в интернет
(schemastore, телеметрия, автообновления).

## Проверка целостности после переноса

```powershell
Get-FileHash *.vsix -Algorithm SHA256
```
и сверить с `checksums.txt`.

## Совместимость

Собрано под **VS Code 1.126**. Самое требовательное в наборе — Kubernetes Tools и Kafka (1.110),
Container Tools (1.109), Error Lens (1.107), GitLens (1.101); Java/Spring — 1.95 и ниже.
Раскладка IntelliJ взята версии **1.7.7** (требует 1.94): последняя 1.7.8 требует VS Code 1.138
и на 1.126 не установится.

`redhat.java` взят в **universal**-сборке (52 МБ) вместо platform-specific (128 МБ):
разница — встроенный JRE, который всё равно не нужен, так как JDK 21 задаётся
через `java.jdt.ls.java.home`.

## Чего в наборе нет

**SonarLint** — сознательно исключён. Любая его сборка (и win32-x64, и universal) весит
250+ МБ из-за анализаторов под все языки, то есть не проходит лимит GitHub в 100 МБ на файл
и потребовал бы нарезки на части. Если он нужен — качается отдельно и переносится
не через репозиторий. Частично его роль закрывает `shengchen.vscode-checkstyle`.

## Почему redhat.java именно 1.57.2026090408, а не свежее

В билдах с 11.09.2026 (`1.57.2026091108` и новее) внутри лежит ecj
`org.eclipse.jdt.core.compiler.batch_3.46.200`, где поле
`ConstructorDeclaration.constructorCall` инкапсулировано — остались только
`getConstructorCall()` / `getEarlyConstructorCall()` / `getLateConstructorCall()`.
Встроенный lombok (`1.18.39-4050`) читает это поле напрямую (16 обращений в байт-коде)
и падает с `java.lang.NoSuchFieldError` → `Internal Error compiling` на каждом файле,
.class не создаются, автодополнение и диагностика мертвы.

Подмена lombok на более новый не помогает: релиз 1.18.48 (01.09.2026) обращается
к тому же полю, а edge-сборки на projectlombok.org сейчас нет вовсе.
Версия агента к тому же берётся из каталога `extension/lombok/` самого расширения,
а не из зависимостей проекта — поэтому `lombok.version` в pom.xml на это не влияет.

`1.57.2026090408` (04.09.2026) — последний билд с ecj `3.46.100.v20260826`,
в котором поле ещё публичное. Проверено: `javap` показывает
`public ExplicitConstructorCall constructorCall;`.

**Не обновлять это расширение**, пока lombok не выпустит версию с поддержкой нового JDT.
В `settings.recommended.jsonc` автообновления уже выключены
(`extensions.autoUpdate`, `extensions.autoCheckUpdates`, `update.mode`).

## GraphQL

| Пакет | Назначение |
|---|---|
| `GraphQL.vscode-graphql-syntax` | подсветка `.graphql`/`.gql` и GraphQL внутри строк; самодостаточен |
| `GraphQL.vscode-graphql` | LSP: автодополнение по схеме, валидация, go-to-definition, hover |
| `GraphQL.vscode-graphql-execution` | выполнение запросов из файла (опционально) |

`syntax` — это `extensionDependencies` основного пакета, оффлайн не подтянется сам,
поэтому в `install.ps1` он идёт первым.

Умные функции включаются только при наличии graphql-config в корне проекта
(`graphql.config.yml`), иначе останется одна подсветка:

```yaml
schema: src/main/resources/graphql/schema.graphqls
documents: src/main/resources/graphql/**/*.graphql
```

Схему держать локальным файлом: интроспекция по URL в закрытом контуре не сработает.

## Git

Встроенного SCM-модуля VS Code хватает для commit/push/pull/branch/stash,
а раскраска файлов по git-статусу в Explorer и разделы Staged Changes / Changes
в панели Source Control — это тоже встроенное, расширений не требует.
Добавлены только то, чего в редакторе нет:

| Пакет | Аналог в IDEA |
|---|---|
| `mhutchie.git-graph` | вкладка Git Log: граф веток, действия по коммитам. Автономен, без аккаунта и сети |
| `eamodio.gitlens` | Annotate (blame), история файла/строки, interactive rebase. Облачные функции (Launchpad, AI, Cloud Patches) требуют аккаунта GitKraken и в закрытом контуре не активируются |
| `donjayamanne.githistory` | Show History — во многом дублирует GitLens, можно не ставить |

Changelists из IDEA аналога не имеют — ни встроенного, ни в расширениях.

## buf CLI (для bufbuild.vscode-buf)

Расширение само бинарник не содержит и по умолчанию тянет его с GitHub Releases —
в закрытом контуре это не работает, поэтому `buf` лежит рядом:

`buf-Windows-x86_64-v1.73.0.zip` (34 МБ, официальный релиз bufbuild/buf v1.73.0)

Внутри: `buf/bin/buf.exe`, плюс плагины `protoc-gen-buf-lint.exe` и
`protoc-gen-buf-breaking.exe` (нужны только для `buf lint` / `buf breaking` в CI).

Установка:

```powershell
Expand-Archive .\buf-Windows-x86_64-v1.73.0.zip -DestinationPath C:\tools -Force
C:\tools\buf\bin\buf.exe --version    # должно напечатать 1.73.0
```

Затем в settings.json (ключ именно такой, других у расширения нет):

```json
"buf.commandLine.path": "C:\\tools\\buf\\bin\\buf.exe"
```

Если `buf` не нужен — расширение можно не ставить вовсе, `.proto` останутся
под `zxh404.vscode-proto3` (подсветка и переходы по import).

## proto-классы в VS Code без правки pom.xml — `local.m2e-protobuf` 1.1.0

Ставится через `install.ps1` вместе со всем набором. Настраивать ничего не нужно,
скрипты-«фиксы» не нужны.

**Как работает.** Это m2e-коннектор, OSGi-бандл для JDT LS, который подключается через
`contributes.javaExtensions`.

- Привязан к `maven-compiler-plugin` (`compile`/`testCompile`, те же фильтры `compilerId`, что у
  `m2e.jdt`/`m2e.apt`), а не к самому protobuf-плагину. Поэтому workspace lifecycle mapping
  с `<ignore/>` или `<execute>` для `protobuf-maven-plugin` его **не выключает**.
- Находит выполнения `org.xolstice:protobuf-maven-plugin` (`compile`, `compile-custom`, …) и
  `io.github.ascopes:protobuf-maven-plugin` (`generate`) прямо в модели проекта, включая конфигурацию
  из `pluginManagement` parent-pom. Их выходные каталоги регистрирует как source folders. Каталог берётся
  из явного `<outputDirectory>`, затем из свойств `javaOutputDirectory`/`protocPluginOutputDirectory`,
  затем из дефолтов (`target/generated-sources/protobuf/java`, `.../protobuf/<pluginId>`).
- **protoc внутри IDE не запускается** (на уровне бандла protobuf goals помечены `ignore`).
  Классы генерирует обычный `mvn compile`. Без этого JDT LS сам выполняет protoc (маппинг `execute`
  вшит в jar xolstice), и если protoc в IDE не скачался или не запустился, плагин **сначала очищает**
  `generated-sources/protobuf` и только потом падает. Сгенерированные `mvn` классы при этом пропадают.

### Проверено в настоящем VS Code 1.103 (изолированный профиль)

Реконструкция `digital-ksb-cache`: parent-pom с `pluginManagement` для xolstice 0.6.1
(`compile` + `compile-custom`/grpc-java, `os-maven-plugin`), модули `common` и
`digital-ksb-cache-service`. Код сгенерирован `mvn` 3.9.6 командой
`mvn compile -pl digital-ksb-cache-service -am`.

| сценарий | без коннектора / 1.0.0 | 1.1.0 |
|---|---|---|
| ваш реальный lifecycle-файл с `<ignore/>` для protobuf | **ошибки, каталогов нет в classpath** | 0 ошибок |
| lifecycle-файла нет | ок | 0 ошибок |
| lifecycle-файл с `<execute>` | — | 0 ошибок |
| protoc в IDE недоступен | **классы стёрты, ошибки** | 0 ошибок, классы на месте |

### Порядок на рабочем ПК

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
mvn compile -pl digital-ksb-cache-service -am
```
Затем в VS Code один раз: `Ctrl+Shift+P` → **Java: Clean Java Language Server Workspace**.
Локальный `build-helper` в pom можно откатить; если ставили `skip-worktree`, снимите флаг:
`git update-index --no-skip-worktree digital-ksb-cache-service/pom.xml`.

После изменения `.proto` нужен `mvn compile`, как и в IDEA. VS Code подхватит новые классы сам.

### Если всё же не видно

`fix-proto.ps1 -ProjectRoot <repo>` — необязательная диагностика, она **ничего не меняет**. Показывает:
установлен ли коннектор; лежат ли `.project`/`.classpath` рядом с pom.xml (тогда модуль импортирован
как Eclipse-проект и m2e не участвует, ошибка 1013; убрать можно через `check-eclipse-artifacts.ps1 -Remove`);
есть ли в pom блок `org.eclipse.m2e:lifecycle-mapping` для `maven-compiler-plugin`; сгенерированы ли
классы вообще.

Исходники коннектора лежат в `m2e-protobuf-src/`: один класс, `plugin.xml` и маппинг.
