# The following creates the base and development environment.
# If you want to build a development environment set the target
# to `magento2-php` (e.g. `--target magento2-php`)
# It doesn't contain any source files, because it is expected that
# the source files are mounted into the container.
# This is different from the production environment further down
# below which copies the files into the image.
FROM php:8.3.27-fpm-alpine3.22 AS magento2-php

ARG UID=1000
ARG GID=1000

RUN set -ex; \
	deluser www-data \
	&& addgroup -g $GID -S www-data \
	&& adduser -S -D -H -u $UID -s /sbin/nologin -G www-data -g www-data www-data \
	&& sed -i '/^magento/s/!/*/' /etc/shadow \
	&& echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini \
	&& echo "memory_limit=${PHP_MEMORY_LIMIT:-2G}" > $PHP_INI_DIR/conf.d/memory_limit.ini \
	&& echo "max_execution_time=${PHP_MAX_EXECUTION_TIME:-1800}" > $PHP_INI_DIR/conf.d/max_execution_time.ini \
	&& echo "zlib.output_compression=${PHP_ZLIB_COMPRESSION:-On}" > $PHP_INI_DIR/conf.d/zlib_compression.ini

COPY docker/php/config/opcache.ini $PHP_INI_DIR/conf.d/

COPY --chown=www-data:www-data docker/cron/crontab /etc/crontab

# Install all necessary PHP extensions based on composer.json
# This script parses src/composer.json for ext-* requirements and installs them
COPY docker/php/install-php-extensions.sh /tmp/
COPY src/composer.json /tmp/composer.json

RUN /tmp/install-php-extensions.sh /tmp/composer.json \
	&& rm -f /tmp/install-php-extensions.sh /tmp/composer.json

COPY --chmod=755 docker/php/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint

USER $UID

# Development image — adds Node.js for frontend build tools (e.g. Hyvä Tailwind CSS)
FROM magento2-php AS magento2-php-dev

USER root

RUN apk add --no-cache nodejs npm

COPY --chmod=755 docker/php/tailwind.sh /usr/local/bin/tailwind

USER $UID

# Build stage — installs dependencies, compiles DI and static content
FROM magento2-php-dev AS magento2-php-build

# git is needed for composer source installs (e.g. Hyvä private repos)
USER root
RUN apk add --no-cache git
USER www-data

# renovate: datasource=docker depName=composer
COPY --from=composer:2.8.12 /usr/bin/composer /usr/bin/composer

COPY --chown=www-data:www-data ./src .

ENV COMPOSER_HOME=/tmp/.composer

# GitHub token for private repos (Hyvä theme etc.) — passed as build arg, not persisted in image
ARG COMPOSER_AUTH
ENV COMPOSER_AUTH=${COMPOSER_AUTH}

RUN set -ex; \
	composer install --no-dev --no-interaction \
	&& mkdir -p var pub/static pub/media generated/code generated/metadata var/view_preprocessed \
	&& find var vendor pub/static pub/media app/etc -type f -exec chmod 644 {} + \
	&& find var vendor pub/static pub/media app/etc -type d -exec chmod 755 {} + \
	&& chmod u+x bin/magento \
	# Enable all modules if config.php is missing (fresh install) \
	&& [ -f app/etc/config.php ] || php bin/magento module:enable --all \
	# Build Tailwind CSS if any themes have it \
	&& (tailwind build 2>/dev/null || true) \
	# NOTE: di:compile and autoloader optimization are done at container start
	# because they create references to env.php which doesn't exist at build time.
	# Remove stub env.php created by module:enable \
	&& rm -f app/etc/env.php

# Production image — no Node.js, only compiled assets
FROM magento2-php AS magento2-php-production

COPY --from=magento2-php-build --chown=www-data:www-data /var/www/html /var/www/html
COPY --from=magento2-php-build /usr/bin/composer /usr/bin/composer

COPY --chmod=755 docker/php/docker-php-entrypoint /usr/local/bin/base-docker-php-entrypoint
COPY --chmod=755 docker/php/prod-docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
