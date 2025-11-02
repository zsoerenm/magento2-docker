# The following creates the base and development environment.
# If you want to build a development environment set the target
# to `magento2-php` (e.g. `--target magento2-php`)
# It doesn't contain any source files, because it is expected that
# the source files are mounted into the container.
# This is different from the production environment further down
# below which copies the files into the image.
FROM php:8.3.25-fpm-alpine3.22 AS magento2-php

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

COPY php/config/opcache.ini $PHP_INI_DIR/conf.d/

COPY --chown=www-data:www-data cron/crontab /etc/crontab

# Install all necessary PHP extensions based on composer.json
# This script parses src/composer.json for ext-* requirements and installs them
COPY scripts/install-php-extensions.sh /tmp/
COPY src/composer.json /tmp/composer.json

RUN /tmp/install-php-extensions.sh /tmp/composer.json \
	&& rm -f /tmp/install-php-extensions.sh /tmp/composer.json

COPY --chmod=755 php/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint

USER $UID

# The following image creates the production environment
FROM magento2-php

# Copy the source code over the existing code.
COPY --chown=www-data:www-data ./src .

RUN set -ex; \
	find var generated vendor pub/static pub/media app/etc -type f -exec chmod 644 {} + \
	&& find var generated vendor pub/static pub/media app/etc -type d -exec chmod 755 {} + \
	&& chmod u+x bin/magento \
	&& php bin/magento setup:di:compile \
	&& php bin/magento setup:static-content:deploy -f \
	&& find \
	app/code \
	lib \
	vendor \
	pub/static \
	app/etc \
	generated/code \
	generated/metadata \
	var/view_preprocessed \
	\( -type d -or -type f \) -exec chmod g-w {} \; \
	&& chmod o-rwx app/etc/env.php

COPY --chmod=755 php/docker-php-entrypoint /usr/local/bin/base-docker-php-entrypoint
COPY --chmod=755 php/prod-docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
