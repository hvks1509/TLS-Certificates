1. Generate a Private Key
Everything starts with a private key. This never leaves your server.

# RSA 2048-bit (widely compatible)
#openssl genrsa -out server.key 2048

# RSA 4096-bit (stronger, slightly slower handshake)
#openssl genrsa -out server.key 4096

# ECDSA (modern, faster, smaller) — P-256 curve
#openssl ecparam -genkey -name prime256v1 -noout -out server.key

# You can inspect what you made:
#openssl rsa -in server.key -text -noout        # for RSA
#openssl ec -in server.key -text -noout          # for ECDSA

2. Create a Certificate Signing Request (CSR)
The CSR bundles your public key with identity information (Subject), and is signed by your private key to prove you hold it.

#openssl req -new -key server.key -out server.csr -subj "/C=SG/ST=Singapore/L=Singapore/O=MyCompany/CN=app.example.com"

# The fields in the subject (-subj) are:
Field                       Meaning                       Example
C                           Country (2-letter ISO)          SG
ST                          State/Province                  Singapore
L                           Locality/City                   Singapore
O                           Organization                    MyCompany
OU                          Org Unit (optional)             Engineering
CN                          Common Name                     app.example.com
SAN                         Subject Alternative Names       DNS.1 = app.example.com, DNS.2 = *.app.example.com
