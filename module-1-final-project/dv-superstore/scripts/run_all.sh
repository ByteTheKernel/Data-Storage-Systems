#!/usr/bin/env bash
# Применяет все SQL-скрипты по порядку внутри контейнера ClickHouse.
set -euo pipefail
cd "$(dirname "$0")/.."

CSV="data/SampleSuperstore.csv"
if [ ! -f "$CSV" ]; then
  echo "Нет $CSV. Скачайте SampleSuperstore.csv с https://www.kaggle.com/datasets/roopacalistus/superstore и положите в ./data" >&2
  exit 1
fi

CH="docker compose exec -T clickhouse clickhouse-client --user dv_user --password dv_pass --multiquery"
for f in sql/01_staging.sql sql/02_ddl_vault.sql sql/03_load.sql sql/04_checks.sql sql/05_marts.sql; do
  echo ">>> $f"
  $CH --format PrettyCompactMonoBlock < "$f"
done
echo "Готово. Примеры запросов: make queries"
