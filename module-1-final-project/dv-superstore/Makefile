CH = docker compose exec -T clickhouse clickhouse-client --user dv_user --password dv_pass --multiquery --format PrettyCompactMonoBlock

up:        ## поднять ClickHouse
	docker compose up -d

all: up    ## поднять, создать таблицы, загрузить, проверить
	@sleep 8
	./scripts/run_all.sh

queries:   ## примеры аналитических запросов
	$(CH) < sql/06_queries.sql

checks:    ## проверки качества
	$(CH) < sql/04_checks.sql

shell:     ## интерактивный клиент
	docker compose exec clickhouse clickhouse-client --user dv_user --password dv_pass

down:      ## остановить и удалить данные
	docker compose down -v
