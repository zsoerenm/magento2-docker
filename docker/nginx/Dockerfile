FROM nginxinc/nginx-unprivileged:1.28.0-alpine AS magento2-nginx

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

# The following image creates the production environment.
FROM magento2-nginx

USER root

# Copy the source code over the existing code.
COPY --chown=nginx:nginx ./src/nginx.conf.sample .
# Also copy php files from pub folder so that nginx thinks index.php, get.php, etc exists
# This could probably be done more efficiently by editing the nginx.conf.sample
# (so that it doesn't check for existence anymore)
# Media files need to shared via a named volume (see docker-compose file)
COPY --chown=nginx:nginx ./src/pub/*.php .
COPY --chown=nginx:nginx ./src/pub/**/*.php .

# Enable production optimizations in nginx.conf.sample
RUN sed -i 's/# expires max/expires max/g' nginx.conf.sample

USER nginx
