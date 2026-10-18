# Data Vault для Superstore в ClickHouse (Docker)

Итоговое ДЗ, модуль 1: проектирование хранилища методом Data Vault и реализация. С использованием ClickHouse в Docker. Дополнительно приложен DDL для Greenplum (он написан по документации и на реальном Greenplum не запускался).

## Быстрый старт
1. Скачайте `SampleSuperstore.csv` с https://www.kaggle.com/datasets/roopacalistus/superstore и положите в `./data/`.
2. Выполните:
   ```bash
   make all        # поднимет контейнер, создаст таблицы, загрузит данные, прогонит проверки
   make queries    # примеры аналитики
   ```
   Или вручную: `docker compose up -d`, затем `./scripts/run_all.sh`.
3. Web-интерфейс ClickHouse: http://localhost:8123/play (user `dv_user`, пароль `dv_pass`).
4. Остановить и удалить данные: `make down`.

## Структура
| Путь | Назначение |
|---|---|
| `docker-compose.yml` | ClickHouse 24.8, `./data` монтируется в `user_files` |
| `sql/01_staging.sql` | stage-таблица, загрузка CSV, view с хеш-ключами |
| `sql/02_ddl_vault.sql` | DDL хабов, линка, спутников (с комментариями) |
| `sql/03_load.sql` | идемпотентная загрузка Raw Vault |
| `sql/04_checks.sql` | проверки: счётчики, суммы, «осиротевшие» ключи, уникальность |
| `sql/05_marts.sql` | витрины (звезда) в виде view |
| `sql/06_queries.sql` | аналитические запросы |
| `greenplum/ddl_greenplum.sql` | тот же DDL для Greenplum с PK/FK/DISTRIBUTED BY |
| `docs/model.md` | диаграмма (Mermaid) и обоснование модели |

## Модель
5 хабов (ship_mode, segment, location, product_group, sale_line), 1 линк (lnk_sale_line), 2 спутника (region, меры продажи). Подробности и диаграмма — в [docs/model.md](docs/model.md).

## Ограничения
- В датасете нет Order/Customer/Product ID, поэтому транзакция идентифицируется номером строки файла.
- ClickHouse не имеет FOREIGN KEY/UNIQUE: целостность обеспечивается ReplacingMergeTree и проверками из `04_checks.sql`.
- Скрипты проверялись на ClickHouse (встроенный движок chdb) с синтетическими данными в формате датасета; на реальном CSV и в Docker-образе.
