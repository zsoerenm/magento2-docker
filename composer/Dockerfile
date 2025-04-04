FROM zsoerenm/magento2-php:2.4.7-p3 AS magento2-composer

# Remove Magento installation as it needs to be mounted anyway
# and doing so avoids potentential confusion.
RUN set -ex; \
	rm -r /var/www/html && \
	mkdir /var/www/html

COPY --from=composer:2.8.7 /usr/bin/composer /usr/bin/composer

COPY --chmod=755 composer/docker-composer-entrypoint /usr/local/bin/docker-php-entrypoint