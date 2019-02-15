# Makefile for Docker Nginx PHP Composer MySQL

include .env

# MySQL
MYSQL_DUMPS_DIR=data/db/dumps

help:
	@echo ""
	@echo "usage: make COMMAND"
	@echo ""
	@echo "Commands:"
	@echo "  apidoc              Generate documentation of API"
	@echo "  code-sniff          Check the API with PHP Code Sniffer (PSR2)"
	@echo "  clean               Clean directories for reset"
	@echo "  composer-up         Update PHP dependencies with composer"
	@echo "  composer-require    Install PHP dependencies with composer"
	@echo "  docker-start        Create and start containers"
	@echo "  docker-stop         Stop and clear all services"
	@echo "  gen-certs           Generate SSL certificates"
	@echo "  logs                Follow log output"
	@echo "  mysql-dump          Create backup of all databases"
	@echo "  mysql-restore       Restore backup of all databases"
	@echo "  phpmd               Analyse the API with PHP Mess Detector"
	@echo "  test                Test application"

apidoc:
	@docker-compose exec -T php php -d memory_limit=256M -d xdebug.profiler_enable=0 ./app/vendor/bin/apigen generate app/src --destination app/doc
	@make resetOwner

clean:
	@rm -Rf data/db/mysql/*
	@rm -Rf $(MYSQL_DUMPS_DIR)/*
	@rm -Rf app/app/vendor
	@rm -Rf app/app/composer.lock
	@rm -Rf app/app/doc
	@rm -Rf app/app/report
	@rm -Rf etc/ssl/*

code-sniff:
	@echo "Checking the standard code..."
	@docker-compose exec -T php ./app/vendor/bin/phpcs -v --standard=PSR2 app/src

composer-install:
	@docker run --rm -v $(shell pwd)/app:/app composer install

composer-up:
	@docker run --rm -v $(shell pwd)/app:/app composer update

composer-require:
	@docker run --rm -v $(shell pwd)/app:/app composer require $(package)

docker-start: init
	docker-compose up -d

docker-stop:
	@docker-compose down -v
	@make clean

gen-certs:
	@docker run --rm -v $(shell pwd)/etc/ssl:/certificates -e "SERVER=$(NGINX_HOST)" jacoelho/generate-certificate

logs:
	@docker-compose logs -f

mysql-dump:
	@mkdir -p $(MYSQL_DUMPS_DIR)
	@docker exec $(shell docker-compose ps -q mysqldb) mysqldump --all-databases -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" > $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null
	@make resetOwner

mysql-restore:
	@docker exec -i $(shell docker-compose ps -q mysqldb) mysql -u"$(MYSQL_ROOT_USER)" -p"$(MYSQL_ROOT_PASSWORD)" < $(MYSQL_DUMPS_DIR)/db.sql 2>/dev/null

phpmd:
	@docker-compose exec -T php \
	./app/vendor/bin/phpmd \
	./app/src \
	text cleancode,codesize,controversial,design,naming,unusedcode

test: code-sniff
	@docker-compose exec -T php ./app/vendor/bin/phpunit --colors=always --configuration ./app/

.PHONY: clean test code-sniff init
