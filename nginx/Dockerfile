FROM nginxinc/nginx-unprivileged:1.28.0-alpine AS magento2-nginx

# renovate: datasource=github-tags depName=magento2 packageName=magento/magento2 versioning=composer
ARG MAGENTO_VERSION=2.4.8-p2

COPY nginx/conf/default.conf.template /etc/nginx/templates/

WORKDIR /var/www/html

USER root

RUN set -ex; \
    deluser nginx \
    && addgroup -g 1000 -S nginx \
    && adduser -S -D -H -u 1000 -s /sbin/nologin -G nginx -g nginx nginx \
    && chown -R nginx:0 /var/cache/nginx \
    && chown -R nginx:0 /etc/nginx && \
    apk --update add tar && \
    wget -qO magento2.tar.gz https://github.com/magento/magento2/archive/refs/tags/${MAGENTO_VERSION}.tar.gz && \
    tar xzfo magento2.tar.gz magento2-${MAGENTO_VERSION}/nginx.conf.sample --strip-components=1 && \
    # Also copy php files from pub folder so that nginx thinks index.php, get.php, etc exists
    # This could probably be done more efficiently by editing the nginx.conf.sample
    # (so that it doesn't check for existence anymore)
    # Media files need to shared via a named volume (see docker-compose file)
    tar xzfo magento2.tar.gz --wildcards magento2-${MAGENTO_VERSION}/pub/*.php --strip-components=1 && \
    tar xzfo magento2.tar.gz --wildcards magento2-${MAGENTO_VERSION}/pub/**/*.php --strip-components=1 && \
    rm magento2.tar.gz && \
    chown -R nginx:nginx .

USER nginx

# The following image creates the production environment.
FROM magento2-nginx

COPY --from=magento2-php-prod /var/www/html/pub/static /var/www/html/pub/static
