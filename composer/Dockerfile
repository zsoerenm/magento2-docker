# This Dockerfile depends on the magento2-php image built from php/Dockerfile.
# Docker Compose automatically builds the php service first due to the depends_on
# setting in docker-compose.override.yml, so you can simply run:
#   docker compose run --rm composer <command>
FROM magento2-php

# renovate: datasource=docker depName=composer
COPY --from=composer:2.8.12 /usr/bin/composer /usr/bin/composer

COPY --chmod=755 composer/docker-composer-entrypoint /usr/local/bin/docker-php-entrypoint