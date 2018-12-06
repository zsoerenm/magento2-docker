FROM cooptilleuls/varnish:4-alpine

COPY varnish/varnish-template.vcl /usr/local/etc/varnish/
COPY varnish/docker-varnish-entrypoint /usr/local/bin/

RUN chmod 755 /usr/local/bin/docker-varnish-entrypoint

ENV BACKEND_HOST web
ENV BACKEND_PORT 80
ENV VARNISH_HOST web
ENV SSL_OFFLOADED_HEADER X-Forwarded-Proto
ENV GRACE_PERIOD 0
