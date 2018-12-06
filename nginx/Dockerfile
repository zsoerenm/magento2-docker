FROM nginx:alpine as magento2-nginx-base

COPY nginx/conf/default.conf.template /etc/nginx/conf.d/default.conf.template

RUN chmod 664 /etc/nginx/conf.d/default.conf.template

CMD envsubst '$$SERVER_NAME $$BACKEND_HOST' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'

FROM magento2-nginx-base

COPY --from=magento2-php-prod --chown=1000:nginx /var/www/html/index.php /var/www/html/index.php
COPY --from=magento2-php-prod --chown=1000:nginx /var/www/html/nginx.conf.sample /var/www/html/nginx.conf.sample
COPY --from=magento2-php-prod --chown=1000:nginx /var/www/html/pub/static /var/www/html/pub/static
