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
