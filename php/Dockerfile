FROM php:8.1.31-fpm-alpine3.20 AS magento2-php-base

ARG MAGENTO_USER_ID=1000
ARG MAGENTO_GROUP_ID=1000
ARG NGINX_USER_ID=101
ARG NGINX_GROUP_ID=101

RUN set -ex; \
	addgroup -g "${MAGENTO_GROUP_ID}" -S magento \
	&& adduser -u "${MAGENTO_USER_ID}" -D -S -G magento magento \
	# Make www-data use the same uid and gid as nginx
	&& deluser www-data \
	&& addgroup -g "${NGINX_GROUP_ID}" -S www-data \
	&& adduser -u "${NGINX_USER_ID}" -D -S -G www-data www-data \
	&& adduser magento www-data \
	&& sed -i '/^magento/s/!/*/' /etc/shadow \
	&& echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini \
	&& echo "memory_limit=${PHP_MEMORY_LIMIT:-2G}" > $PHP_INI_DIR/conf.d/memory_limit.ini \
	&& echo "max_execution_time=${PHP_MAX_EXECUTION_TIME:-1800}" > $PHP_INI_DIR/conf.d/max_execution_time.ini \
	&& echo "zlib.output_compression=${PHP_ZLIB_COMPRESSION:-On}" > $PHP_INI_DIR/conf.d/zlib_compression.ini

COPY php/config/opcache.ini $PHP_INI_DIR/conf.d/

# Install all necessary PHP extensions.
# See https://experienceleague.adobe.com/en/docs/commerce-operations/installation-guide/prerequisites/php-settings
# For some it is required to also add corresponding libraries.
# In all cases the dev version is required for installation,
# but can be removed after installation has finished.
RUN set -ex; \
	apk add --update --no-cache -t .php-rundeps \
	icu \
	freetype \
	libxslt \
	libjpeg-turbo \
	libpng \
	libzip \
	libxml2 \
	&& apk add --update --no-cache -t .build-deps \
	icu-dev \
	freetype-dev \
	libjpeg-turbo-dev \
	libpng-dev \
	libzip-dev \
	libmcrypt-dev \
	libxml2-dev \
	libxslt-dev \
	&& docker-php-ext-configure gd --with-freetype=/usr/include/ --with-jpeg=/usr/include/ \
	&& docker-php-ext-install -j$(nproc) \
	bcmath \
	gd \
	intl \
	opcache \
	pdo_mysql \
	sockets \
	soap \
	xsl \
	zip \
	&& docker-php-source delete \
	&& apk del --purge .build-deps

COPY --chmod=755 php/docker-php-entrypoint /usr/local/bin/docker-php-entrypoint

# The following creates the development environment.
# Compiling like bin/magento setup:di:compile
# and setup:static-content:deploy are not necessary and
# is actually discouraged
# See https://experienceleague.adobe.com/en/docs/commerce-operations/performance-best-practices/development-environment
# If you want to build a development environment set the target
# to `magento2-php` (e.g. `--target magento2-php`)
FROM magento2-php-base AS magento2-php

# renovate: datasource=github-tags depName=magento2 packageName=magento/magento2 versioning=composer
ARG MAGENTO_VERSION=2.4.7-p4

RUN set -ex; \
	wget -qO- http://pubfiles.nexcess.net/magento/ce-packages/magento2-${MAGENTO_VERSION}.tar.gz \
	| tar xzfo - \
	&& find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + \
	&& find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + \
	&& mkdir /var/www/html/baseconfig \
	&& cp -p app/etc/* /var/www/html/baseconfig \
	&& chown -R magento:www-data . \
	&& chmod u+x bin/magento

# The following image creates the production environment
FROM magento2-php AS magento2-php-builder

# Copy the source code over the existing code.
# This may be a whole Magento installation
# or just the changed files.
# Make sure the versions match, though.
COPY --chown=magento:www-data ./src .

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

# This last image prunes all unnecessay files.
# It actually only copies all necessary files from the previous image
FROM magento2-php-base

COPY --from=magento2-php-builder --chown=magento:www-data /var/www/html /var/www/html
COPY --chmod=755 php/docker-php-entrypoint /usr/local/bin/base-docker-php-entrypoint
COPY --chmod=755 php/prod-docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
