FROM nginx:alpine

COPY sslproxy/conf/default.conf.template /etc/nginx/conf.d/default.conf.template
COPY sslproxy/conf/ssl-dhparams.pem /etc/nginx/ssl/ssl-dhparams.pem

RUN chmod 664 /etc/nginx/conf.d/default.conf.template

CMD envsubst '$$SERVER_NAME $$BACKEND_HOST' < /etc/nginx/conf.d/default.conf.template > /etc/nginx/conf.d/default.conf && exec nginx -g 'daemon off;'
