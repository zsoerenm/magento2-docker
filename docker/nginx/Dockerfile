FROM nginxinc/nginx-unprivileged:1.29.5-alpine AS magento2-nginx

COPY docker/nginx/conf/default.conf.template /etc/nginx/templates/

WORKDIR /var/www/html

USER root

RUN set -ex; \
    deluser nginx \
    && addgroup -g 1000 -S nginx \
    && adduser -S -D -H -u 1000 -s /sbin/nologin -G nginx -g nginx nginx \
    && chown -R nginx:0 /var/cache/nginx \
    && chown -R nginx:0 /etc/nginx

USER nginx

# Production image — static assets baked in from PHP build stage
# Media files are still shared via a named volume (uploaded at runtime)

# Reference the PHP image to copy static assets from
ARG PHP_IMAGE
# hadolint ignore=DL3006
FROM ${PHP_IMAGE} AS php_source

FROM magento2-nginx AS magento2-nginx-production

USER root

COPY --chown=nginx:nginx ./src/nginx.conf.sample .
COPY --chown=nginx:nginx ./src/pub/*.php ./pub/
COPY --chown=nginx:nginx ./src/pub/**/*.php ./pub/

# Copy pre-deployed static content from the PHP production image
COPY --from=php_source --chown=nginx:nginx /var/www/html/pub/static ./pub/static

# Enable production optimizations in nginx.conf.sample
RUN sed -i 's/# expires max/expires max/g' nginx.conf.sample

USER nginx
