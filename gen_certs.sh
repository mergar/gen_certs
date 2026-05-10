#!/bin/sh
set -e

# --- ПАРАМЕТРЫ ---
CN="example.local"          # Домен или IP
ORG="My Company"            # Организация
EMAIL="admin@example.local"
DAYS=365                    # Срок действия
KEY_SIZE=2048

# --- ГЕНЕРАЦИЯ КОНФИГА ---
cat <<EOF > openssl.cnf
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = RU
ST = Moscow
L = Moscow
O = $ORG
CN = $CN
emailAddress = $EMAIL

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = critical, CA:true
keyUsage = critical, digitalSignature, cRLSign, keyCertSign

[v3_req]
subjectKeyIdentifier = hash
basicConstraints = CA:FALSE
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names

[alt_names]
DNS.1 = $CN
DNS.2 = www.$CN
# IP.1 = 127.0.0.1 (раскомментируйте, если нужен IP)
EOF

# 1. Генерация CA (Корневой сертификат)
openssl genrsa -out ca.key $KEY_SIZE
openssl req -x509 -new -nodes -key ca.key -sha256 -days $DAYS -out ca.crt -config openssl.cnf -extensions v3_ca

# 2. Генерация ключа сервера и CSR (запрос на подпись)
openssl genrsa -out server.key $KEY_SIZE
openssl req -new -key server.key -out server.csr -config openssl.cnf

# 3. Подпись сертификата сервера ключом CA
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days $DAYS -sha256 -extfile openssl.cnf -extensions v3_req

# Очистка
rm openssl.cnf server.csr ca.srl

echo "Готово! Файлы для Nginx: server.crt и server.key"

exit 0