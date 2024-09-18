# BWAPITOOL : Secure restful API from bitwarden CLI

---
[![Docker Pulls](https://img.shields.io/docker/pulls/misterbabou/bwapitool.svg?logo=docker)](https://hub.docker.com/r/misterbabou/bwapitool)
[![GitHub Release](https://img.shields.io/github/release/Misterbabou/bwapitool.svg?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/releases/latest)
[![GitHub last commit](https://img.shields.io/github/last-commit/Misterbabou/bwapitool?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/commits/main)
[![MIT Licensed](https://img.shields.io/github/license/Misterbabou/bwapitool.svg?logo=github&logoColor=959DA5)](https://github.com/Misterbabou/bwapitool/blob/main/LICENSE.md)
---

BWPITOOL brings a secure docker container to host you bitwarden CLI restful API server with password and fail2ban.

See official documentation for the CLI restful API: https://bitwarden.com/help/vault-management-api/

How does it work:
 - Running the official bitwarden CLI command: `bw serve`
 - Nginx https frontend to make secure connection between clients and restful API.
 - Nginx authentication for clients. There is 2 modes of authentication: read only which can only do `GET` requests and a full access which can do all `GET, PUT, POST, DELETE`
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

## Nginx password to do GET API requests 
NGINX_READ_ONLY_PASS=changeme

## Ninx password to do all (GET, PUT, POST, DELETE) API requests
NGINX_FULL_ACCESS_PASS=superchangeme

## Docker nginx port inside container (don't change it unless you know what your doing)
#NGINX_PORT=443

## SSL Configuration
#NGINX_HOSTNAME=your.server.domain
#NGINX_CERT=nginx-selfsigned.crt
#NGINX_CERT_PRIVATE=nginx-selfsigned.key

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
>ENV BW_CLIENTID and BW_CLIENTSECRET are madatory for the first docker-compose startup

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

Copy and paste the result in the ".env" variable and uncomment :
BW_SESSION="your previous command result"

At the point you can delete 
BW_CLIENTID 
BW_CLIENTSECRET

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

You had to had a new header X-Password to your api requests.
See official documentation to forge requests: https://bitwarden.com/help/vault-management-api/

Exemple for search an item with "test" in it:
```
curl -k -s --request GET --url https://your.server.domain:9443/list/object/items?search=test --header 'Accept: application/json' --header 'X-Password: <your NGINX_READ_ONLY_PASS>'
```

Exemple with sync request :
```
curl -k -s --request POST --url https://your.server.domain:9443/sync --header 'Accept: application/json' --header 'X-Password: <your NGINX_FULL_ACCESS_PASS>'
```

> [!NOTE]
> 
>curl -k option need to be use only if you are using the self signed certificate

## Fail2ban debug  

Check banned IPs:
```
sudo docker exec -it bwapitool fail2ban-client banned
```

Unban:
```
sudo docker exec -it bwapitool fail2ban-client set nginx-auth unbanip <IP>
```
