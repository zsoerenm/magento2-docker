FROM php:7.1.24-fpm-alpine3.8 as magento2-php-base

ARG COMMIT="local-build"
ARG DATE="1970-01-01T00:00:00Z"
ARG URL="https://github.com/zsoerenm/magento2-docker"
ARG VERSION="dirty"

LABEL org.label-schema.schema-version="1.0" \
    org.label-schema.build-date=$DATE \
    org.label-schema.vendor="Soeren Zorn" \
    org.label-schema.name="zsoerenm/magento2-php" \
    org.label-schema.description="A PHP container with Magento 2" \
    org.label-schema.version="$VERSION" \
    org.label-schema.vcs-url=$URL \
    org.label-schema.vcs-ref=$COMMIT

ARG MAGENTO_USER_ID=1000
ARG MAGENTO_GROUP_ID=1000

RUN set -ex; \
    addgroup -g "${MAGENTO_GROUP_ID}" -S magento; \
    adduser -u "${MAGENTO_USER_ID}" -D -S -s /bin/bash -G magento magento; \
		adduser magento www-data; \
		sed -i '/^magento/s/!/*/' /etc/shadow; \
		echo "date.timezone=${PHP_TIMEZONE:-UTC}" > $PHP_INI_DIR/conf.d/date_timezone.ini \
 		&& echo "memory_limit=${PHP_MEMORY_LIMIT:-2G}" > $PHP_INI_DIR/conf.d/memory_limit.ini \
 		&& echo "max_execution_time=${PHP_MAX_EXECUTION_TIME:-1800}" > $PHP_INI_DIR/conf.d/max_execution_time.ini \
 		&& echo "zlib.output_compression=${PHP_ZLIB_COMPRESSION:-On}" > $PHP_INI_DIR/conf.d/zlib_compression.ini

COPY php/config/opcache.ini $PHP_INI_DIR/conf.d/

RUN set -ex; \
    apk add --update --no-cache -t .php-rundeps \
        icu-libs \
				freetype \
        libmcrypt \
        libxslt \
        libjpeg-turbo \
        libpng \
        libxml2 \
    && apk add --update --no-cache -t .build-deps \
        icu-dev \
        freetype-dev \
        libjpeg-turbo-dev \
        libpng-dev \
        libmcrypt-dev \
        libxml2-dev \
        libxslt-dev \
    && docker-php-ext-configure gd --with-freetype-dir=/usr/include/ --with-jpeg-dir=/usr/include/ \
    && docker-php-ext-install -j$(nproc) \
        bcmath \
        gd \
        intl \
        mcrypt \
        opcache \
        pdo_mysql \
        soap \
        xsl \
        zip \
    && docker-php-source delete; \
    apk del --purge .build-deps

	COPY php/config/remove_redis_config.php php/config/set_redis_config php/config/set_database_config php/docker-php-entrypoint /usr/local/bin/

	RUN  set -ex; \
	   chmod u+x /usr/local/bin/docker-php-entrypoint \
	   && chmod 755 \
	     /usr/local/bin/remove_redis_config.php \
	     /usr/local/bin/set_redis_config \
	     /usr/local/bin/set_database_config

FROM magento2-php-base as magento2-php

ARG MAGENTO_VERSION=2.2.6

RUN set -ex; \
    curl -SL http://pubfiles.nexcess.net/magento/ce-packages/magento2-${MAGENTO_VERSION}.tar.gz \
		| tar xzf - -o \
	&& find var generated vendor pub/static pub/media app/etc -type f -exec chmod g+w {} + \
	&& find var generated vendor pub/static pub/media app/etc -type d -exec chmod g+ws {} + \
	&& mkdir /var/www/html/baseconfig \
	&& cp -p app/etc/* /var/www/html/baseconfig \
  && chown -R magento:www-data . \
	&& chmod u+x bin/magento

FROM magento2-php as magento2-php-builder

COPY --chown=magento:www-data ./src .

# Prunefind folders should not have been copied since they are in .dockerignore. The permissions for these file should already be correct.
RUN set -ex; \
	prunefind="\
		-path ./vendor/amzn -o \
		-path ./vendor/bin -o \
		-path ./vendor/braintree -o \
		-path ./vendor/colinmollenhour -o \
		-path ./vendor/composer -o \
		-path ./vendor/container-interop -o \
		-path ./vendor/doctrine -o \
		-path ./vendor/dotmailer -o \
		-path ./vendor/friendsofphp -o \
		-path ./vendor/guzzlehttp -o \
		-path ./vendor/ircmaxell -o \
		-path ./vendor/justinrainbow -o \
		-path ./vendor/klarna -o \
		-path ./vendor/lusitanian -o \
		-path ./vendor/magento -o \
		-path ./vendor/monolog -o \
		-path ./vendor/myclabs -o \
		-path ./vendor/oyejorge -o \
		-path ./vendor/paragonie -o \
		-path ./vendor/pdepend -o \
		-path ./vendor/pelago -o \
		-path ./vendor/phar-io -o \
		-path ./vendor/phpdocumentor -o \
		-path ./vendor/phpmd -o \
		-path ./vendor/phpseclib -o \
		-path ./vendor/phpspec -o \
		-path ./vendor/phpunit -o \
		-path ./vendor/psr -o \
		-path ./vendor/ramsey -o \
		-path ./vendor/sebastian -o \
		-path ./vendor/seld -o \
		-path ./vendor/squizlabs -o \
		-path ./vendor/symfony -o \
		-path ./vendor/tedivm -o \
		-path ./vendor/temando -o \
		-path ./vendor/theseer -o \
		-path ./vendor/tubalmartin -o \
		-path ./vendor/vertex -o \
		-path ./vendor/webmozart -o \
		-path ./vendor/zendframework -o \
		-path ./dev -o \
		-path ./setup -o \
		-path ./update" \
 	&& find . -type d \( $prunefind \) -prune -o -type f -exec chmod 644 {} + \
	&& find . -type d \( $prunefind \) -prune -o -type d -exec chmod 755 {} + \
	&& find var generated vendor pub/static pub/media app/etc -type d \( $prunefind \) -prune -o -type f -exec chmod g+w {} + \
	&& find var generated vendor pub/static pub/media app/etc -type d \( $prunefind \) -prune -o -type d $prunefind -exec chmod g+ws {} + \
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

FROM magento2-php-base

COPY --from=magento2-php-builder --chown=magento:www-data /var/www/html /var/www/html
COPY php/prod-docker-php-entrypoint /usr/local/bin/docker-php-entrypoint
