FROM magento2-php-prod

# Add redis to catch "Unable to unserialize value, string is corrupted." error
# https://magento.stackexchange.com/questions/194010/magento-2-2-unable-to-unserialize-value
RUN set -ex; \
    apk add --update --no-cache dcron redis

COPY cron/config/remove_redis_config.php cron/config/set_redis_config cron/config/set_database_config cron/docker-php-entrypoint /usr/local/bin/

RUN  set -ex; \
    chmod u+x /usr/local/bin/docker-php-entrypoint \
    && chown magento:magento \
      /usr/local/bin/remove_redis_config.php \
      /usr/local/bin/set_redis_config \
      /usr/local/bin/set_database_config \
    && chmod u+x \
      /usr/local/bin/remove_redis_config.php \
      /usr/local/bin/set_redis_config \
      /usr/local/bin/set_database_config \
    && chmod 4755 /usr/bin/crontab \
    && echo '' > /etc/crontabs/magento \
    && chmod 600 /etc/crontabs/magento

#HEALTHCHECK --interval=5s --timeout=3s \
#    CMD ps aux | grep '[c]rond' || exit 1

CMD ["crond", "-f", "-l", "0"]
