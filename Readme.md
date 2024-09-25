# BWAPITOOL : Secure restful API for bitwarden CLI

---
[![Docker Pulls](https://img.shields.io/docker/pulls/misterbabou/bwapitool.svg?logo=docker)](https://hub.docker.com/r/misterbabou/bwapitool)
[![GitHub Release](https://img.shields.io/github/release/Misterbabou/bwapitool.svg?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/releases/latest)
[![GitHub last commit](https://img.shields.io/github/last-commit/Misterbabou/bwapitool?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/commits/main)
[![MIT Licensed](https://img.shields.io/github/license/Misterbabou/bwapitool.svg?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/blob/main/LICENSE.md)
---

BWPITOOL brings a secure docker container to host you bitwarden CLI restful API server with password or certificate authentication and fail2ban.

See official documentation for the CLI restful API: https://bitwarden.com/help/vault-management-api/

How does it work:
 - Running the official bitwarden CLI command: `bw serve`
 - Nginx https frontend to make secure connection between clients and restful API.
 - Nginx authentication for clients. There is 2 modes of authentication: certificate or password (read only password which can only do `GET` requests and a full access password which can do all `GET, PUT, POST, DELETE`). Certificate is recommended as clients don't use same credentials.
 - Fail2ban to prevent brute-force for nginx authentication

It can be useful:
  - To make a backup if remote Bitwarden server goes down
  - To share secrets for servers
  - To share some passwords with newcomers without creating a new bitwarden account

> [!NOTE]
> 
> This project will not implement certbot to renew Web certificates. If no certs are provided a self-signed certificate is automaticaly created for the SSL connection.

## Configuration

It's recommended to use docker compose to run this application

- Create `docker-compose.yml` file:
```
version: "3"
services:
  bwapitool:
    container_name: bwapitool
    image: misterbabou/bwapitool:latest
    restart: unless-stopped
    cap_add:
      - NET_ADMIN
    ports:
      - 9443:443
    env_file: 
      - ".env"
    volumes:
      - "./appdata/vault:/root/.config/Bitwarden CLI"
      - "./appdata/log:/var/log/nginx"
      - "./appdata/certs:/certs"
```

- On the same directory as docker-compose.yml create `.env` file
```
## BWAPITOOL Configuration File
## Uncomment any of the following lines to change the defaults
##
## By default, Vaultwarden expects for this file to be named ".env" and located
## in the current working directory.

## Timezone 
#TZ=Europe/Paris 

#############
### NGINX ###
#############

## Docker nginx port inside container (don't change it unless you know what your doing)
#NGINX_PORT=443

## SSL Configuration
#NGINX_HOSTNAME=your.server.domain
#NGINX_CERT=nginx-selfsigned.crt
#NGINX_CERT_PRIVATE=nginx-selfsigned.key

## NGINX ERROR log level (crit, error, warn, notice, info, debug)
#NGINX_ERROR_LOG_LEVEL=error

## Nginx Authentication password or cert. Cert is recommended
NGINX_AUTH_MODE=password

### Password authentication:
## Nginx password to do GET API requests
#NGINX_READ_ONLY_PASS=changeme

## Ninx password to do all (GET, PUT, POST, DELETE) API requests
#NGINX_FULL_ACCESS_PASS=superchangeme

### Cert authentication:
## Sets the verification depth in the client certificates chain.
#NGINX_AUTH_CA_DEPTH=1

## Location of your root ca certificate
#NGINX_AUTH_CA_CERT=selfsigned-ca.crt

## List of authorized clients DN (seperated by ;)
## Regex are suported by adding ~ for instance ~.*OU=Dev.* allow all certificate from OU=DEV
#NGINX_AUTHORIZED_CLIENTS_DN="CN=Client1,OU=Dev,O=Company,L=City,ST=State,C=US;CN=Client2,OU=Dev,O=Company,L=City,ST=State,C=US"

##############
### BW CLI ###
##############

## The URL for your self-hosted instance
#BW_REMOTE_SERVER=https://vault.bitwarden.com
## Event logging to the Bitwarden server.
#BW_DISABLE_EVENTS=false

## Loging into you account is made with API KEY can be found on path : https://your.server.domain/#/settings/security/security-keys
#BW_CLIENTID=""
#BW_CLIENTSECRET=""

## Bitwarden session to unlock your vault on docker container start
## command: sudo docker exec -it bwapitool bw unlock --raw
#BW_SESSION=""

## Docker bitwarden cli api port inside container (don't change it unless you know what your doing)
#BW_API_PORT=8087

################
### FAIL2BAN ###
################

## Launch Fail2BAN turning to false is not recommanded
#F2B_ENABLE=true

## Ban time in seconds
#F2B_BANTIME=600
## Time slot for fails count in seconds
#F2B_FINDTIME=600
## The maximum fail attempt in the time slot
#F2B_MAXRETRY=3
```

> [!IMPORTANT]
>
>ENV `BW_CLIENTID` and `BW_CLIENTSECRET` are madatory for the first docker-compose startup

- Ensure rights for the .env file are restrected only to your user
```
chmod 600 .env
```

- Launch the docker-compose for the first time
```
sudo docker compose up -d && docker compose logs -f
```
You should see a following result
```
bwapitool    | [WARNING] Vault is locked
bwapitool    | bw unlock --raw
bwapitool    | Or use API to unlock can be insecure!
bwapitool    | [INFO] Launching API SERVER
```
- Unlock the vault the most secure way
```
sudo docker exec -it bwapitool bw unlock --raw
```
Copy and paste the result in the `.env` file in this variable :
`BW_SESSION="your previous command result"`

At the point you can delete `BW_CLIENTID` and `BW_CLIENTSECRET` from `.env` file

- Retart the docker-container:
```
sudo docker compose down 
sudo docker compose up -d 
```

At this point your container should be ready to verify on computer running your container:
```
curl -k -s --request GET --url https://127.0.0.1:9443/status --header 'Accept: application/json' --header 'X-Password: <your NGINX_READ_ONLY_PASS>'
```
Success result:
```
{"success":true,"data":{"object":"template","template":{"serverUrl":"https://vault.bitwarden.com","lastSync":"2024-08-17T14:58:08.659Z","userEmail":"youremail","userId":"yourid","status":"unlocked"}}}
```

## Client requests:

### Client requests password mode:
You need to had a new header X-Password to your api requests.
See official documentation to forge requests: https://bitwarden.com/help/vault-management-api/

Exemple for search an item with "test" in it:
```
curl -k -s --request GET --url https://your.server.domain:9443/list/object/items?search=test --header 'Accept: application/json' --header 'X-Password: <your NGINX_READ_ONLY_PASS>'
```

Exemple with sync request :
```
curl -k -s --request POST --url https://your.server.domain:9443/sync --header 'Accept: application/json' --header 'X-Password: <your NGINX_FULL_ACCESS_PASS>'
```

### Clients requests cert mode
You need to have a client certificate and a client certificate key to authenticate.
If you are using the default root_ca here is how you can generate a client certificate:

- Go into certs volume directory
```
cd ./certs
```
- Generate the client private key
```
openssl genpkey -algorithm RSA -out ./clientX.key
```

- Generate a client certificate signing request (CSR)
```
openssl req -new -key ./clientX.key -out ./clientX.csr \
    -subj "/C=US/ST=State/L=City/O=Company/OU=Dev/CN=ClientX"
```

- Sign the client CSR with your CA (valid for 365 days)
```
openssl x509 -req -in ./clientX.csr -CA ./selfsigned-ca.crt -CAkey ./selfsigned-ca.key -CAcreateserial ./clientX.crt -days 365
```

- Copy clientX.key and clientX.crt to our client making the request

Exemple for search an item with "test" in it:
```
curl --key ./clientX.key --cert ./clientX.crt -k -s --request GET --url https://your.server.domain:9443/list/object/items?search=test --header 'Accept: application/json'
```

Exemple with sync request :
```
curl --key ./clientX.key --cert ./clientX.crt -k -s --request POST --url https://your.server.domain:9443/sync --header 'Accept: application/json'
```

> [!NOTE]
> 
>`curl -k` option need to be use only if you are using the self signed certificate

## Fail2ban debug  

Check banned IPs:
```
sudo docker exec -it bwapitool fail2ban-client banned
```

Unban:
```
sudo docker exec -it bwapitool fail2ban-client set nginx-auth unbanip <IP>
```
