#!/bin/bash

# Substitute environment variables in the nginx configuration
if [ "$NGINX_AUTH_MODE" = "password" ]; then
  envsubst '$NGINX_PORT $NGINX_READ_ONLY_PASS $NGINX_FULL_ACCESS_PASS $BW_API_PORT $NGINX_CERT $NGINX_CERT_PRIVATE $NGINX_HOSTNAME $NGINX_ERROR_LOG_LEVEL' < /etc/nginx/conf.d/reverse-proxy.conf.template > /etc/nginx/conf.d/reverse-proxy.conf
elif [ "$NGINX_AUTH_MODE" = "cert" ]; then
  # Read the NGINX_AUTHORIZED_CLIENTS_DN environment variable and split it into individual DNs
  IFS=';' read -ra DN_ARRAY <<< "$NGINX_AUTHORIZED_CLIENTS_DN"

  # Loop through each DN and add it to the map
  for DN in "${DN_ARRAY[@]}"; do
    MAP_BLOCK+="    $DN 1;\n"
  done

  # Replace the placeholder in the Nginx template with the actual map block
  envsubst '$NGINX_PORT $BW_API_PORT $NGINX_CERT $NGINX_CERT_PRIVATE $NGINX_HOSTNAME $NGINX_AUTH_CA_CERT $NGINX_AUTH_CA_DEPTH $NGINX_ERROR_LOG_LEVEL' < /etc/nginx/conf.d/reverse-proxy.conf.cert-template | sed "s|{{NGINX_AUTHORIZED_CLIENTS_DN_MAP}}|$MAP_BLOCK|" > /etc/nginx/conf.d/reverse-proxy.conf
else
  echo "[ERROR] ENV NGINX_AUTH_MODE: $NGINX_AUTH_MODE is not supported"
  exit 1
fi

# Generate a self-signed SSL certificate if it doesn't exist
if [ ! -f /certs/$NGINX_CERT ] || [ ! -f /certs/$NGINX_CERT_PRIVATE ]; then
  echo "[INFO] Generating self-signed SSL certificate"
  mkdir -p /certs
  openssl req -x509 -newkey rsa:4096 -sha256 -days 3650 -nodes \
    -keyout /certs/$NGINX_CERT_PRIVATE -out /certs/$NGINX_CERT -subj "/CN=$NGINX_HOSTNAME" > /dev/null 2>&1
  echo "---"
fi

if [ "$NGINX_AUTH_MODE" = "cert" ]; then
  if [ ! -f /certs/$NGINX_AUTH_CA_CERT ]; then
    echo "[INFO] Generating self-signed CA certificate"
    # Generate CA private key
    openssl genpkey -algorithm RSA -out /certs/selfsigned-ca.key > /dev/null 2>&1

    # Generate CA certificate
    openssl req -new -x509 -key /certs/selfsigned-ca.key -out /certs/$NGINX_AUTH_CA_CERT -days 3650 \
      -subj "/C=US/ST=State/L=City/O=Company/OU=Dev/CN=$NGINX_HOSTNAME"
    echo "---"
  fi
fi

# Start nginx
echo "[INFO] Launching Nginx"
nginx -g 'daemon off;' &

sleep 2
# Check if service running
nginx_check=$(ls -l /proc/*/exe 2>/dev/null | grep "nginx\|www-data" | awk -F"/" '{print $3}')
if [ -n "$nginx_check" ]; then
  echo "[INFO] Nginx is running"
  echo "---"
else
  echo "[ERROR] Nginx not running check NGINX_XXX env variables and nginx error.log file"
  exit 1
fi
echo "---"

# Start Fail2Ban
if $F2B_ENABLE; then
  # Substitute environment variables in the Fail2Ban jail configuration
  envsubst '$F2B_BANTIME $F2B_FINDTIME $F2B_MAXRETRY' < /etc/fail2ban/jail.d/nginx-auth.local.template > /etc/fail2ban/jail.d/nginx-auth.local

  echo "[INFO] Launching fail2ban"
  fail2ban-server -b
  echo "---"
fi

# Launch bwapitool
/usr/local/bin/bwapitool
