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
IP.1 = 127.0.0.1
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

openssl x509 -in /root/gen_certs/server.crt -text -noout | grep -A1 "Subject Alternative Name"

# Очистка
rm openssl.cnf server.csr ca.srl

cat <<EOF
Done: server.crt + server.key
Nginx:
..
        listen 1443 ssl;

        ssl_certificate     /root/gen_certs/server.crt;
        ssl_certificate_key /root/gen_certs/server.key;

        ssl_protocols       TLSv1.2 TLSv1.3;
        ssl_ciphers         HIGH:!aNULL:!MD5;
..

EOF

case $( uname -s ) in
	FreeBSD)
		echo "Install CERT"
		echo "FreeBSD:"
		echo "mkdir -p /usr/local/etc/ssl/certs"
		echo "cp /root/gen_certs/ca.crt /usr/local/etc/ssl/certs/"
		echo "certctl rehash"
		mkdir -p /usr/local/etc/ssl/certs
		cp /root/gen_certs/ca.crt /usr/local/etc/ssl/certs/
		certctl rehash
		;;
	*)
		true
		;;
esac

# 
echo "for haproxy: cat /root/gen_certs/server.crt /root/gen_certs/server.key > /root/gen_certs/server.pem"
cat /root/gen_certs/server.crt /root/gen_certs/server.key > /root/gen_certs/server.pem



exit 0
