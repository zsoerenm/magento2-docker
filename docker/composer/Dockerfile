# This Dockerfile depends on the magento2-php image built from php/Dockerfile.
# Docker Compose automatically builds the php service first using the
# additional_contexts feature in docker-compose.override.yml:
#   additional_contexts:
#     magento2-php: service:php
# This allows you to simply run:
#   docker compose run --rm composer <command>
FROM magento2-php

# Composer stores its cache (downloaded packages, cloned git repos) and auth.json
# under COMPOSER_HOME, which defaults to $HOME/.composer. Since www-data has no
# home directory, we point it to a writable location instead.
ENV COMPOSER_HOME=/tmp/.composer

# Git is needed for installing packages from GitHub repositories (e.g. Hyvä theme)
USER root
RUN apk add --no-cache git
USER www-data

# renovate: datasource=docker depName=composer
COPY --from=composer:2.8.12 /usr/bin/composer /usr/bin/composer

COPY --chmod=755 docker/composer/docker-composer-entrypoint /usr/local/bin/docker-php-entrypoint