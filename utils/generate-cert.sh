openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
    -subj "/C=US/ST=Denial/L=Springfield/O=Dis/CN=www.sparkyci.com" \
    -keyout ~/.sparky/certs/www.sparkyci.com.key  -out ~/.sparky/certs/www.sparkyci.com.cert
