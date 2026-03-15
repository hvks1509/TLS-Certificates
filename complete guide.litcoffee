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

## Important: Modern TLS validation uses Subject Alternative Names (SANs), not just CN. Most CAs and browsers require SANs. To include them, you need a config snippet:

# san.cnf
[req]
distinguished_name = req_dn
req_extensions = v3_req
prompt = no

[req_dn]
C  = SG
O  = MyCompany
CN = app.example.com

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = app.example.com
DNS.2 = *.app.example.com
IP.1  = 10.0.1.50

## Then generate the CSR with it:
#openssl req -new -key server.key -out server.csr -config san.cnf

## Verify your CSR looks right:
#openssl req -in server.csr -text -noout

Note: Check that the SANs appear under "Requested Extensions."

# Self-Signed Certificate
The simplest case. You sign your own certificate with your own key. No CA involved. Good for local dev, internal testing, or quick mTLS setups.

From an existing key + CSR:
#openssl x509 -req -in server.csr -signkey server.key -out server.crt -days 365 -extfile san.cnf -extensions v3_req

Remarks-1: The -extfile / -extensions flags are critical — without them, SANs from your CSR won't make it into the final certificate.
Remarks-2: Clients connecting to this server will reject the cert unless you explicitly trust it (add it to your OS/browser trust store, or pass --cacert server.crt in curl).

# Internal / Private CA
This is the pattern for organizations that want to issue their own trusted certs across internal infrastructure. Two phases: set up the CA, then use it to sign.
## Phase 1: Create the CA
## Generate the CA's private key (protect this carefully)
openssl genrsa -aes256 -out ca.key 4096

# Create the CA's self-signed root certificate
#openssl req -x509 -new -key ca.key -sha256 -days 3650 -out ca.crt -subj "/C=SG/O=MyCompany/CN=MyCompany Internal CA"

This ca.crt is what you distribute to all clients and servers as a trusted root. On Linux, you'd typically copy it into /usr/local/share/ca-certificates/ and run update-ca-certificates.

## Phase 2: Sign a server certificate with the CA
#openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial -out server.crt -days 365 -sha256 -extfile san.cnf -extensions v3_req

Key flags:

-CA / -CAkey point to your CA's cert and key
-CAcreateserial creates a serial number file (ca.srl) to track issued certs
-extfile / -extensions again ensure SANs are copied into the cert

Verify the chain:
#openssl verify -CAfile ca.crt server.crt
# should print: server.crt: OK

Inspect the issued cert:
#openssl x509 -in server.crt -text -noout

Check that Issuer shows your CA's subject, and that SANs are present.

Optional: Intermediate CA
In production internal PKI, you often don't sign leaf certs directly with the root. Instead you create an intermediate CA signed by the root, and use the intermediate to sign server certs. The server then serves a chain file (server.crt + intermediate.crt) so clients can trace the path back to the root.

#cat server.crt intermediate.crt > fullchain.crt

Putting it together: testing the chain
Once you have server.key and fullchain.crt (or server.crt for self-signed), you can spin up a quick test server:

#openssl s_server -accept 4433 -cert server.crt -key server.key -CAfile ca.crt

And connect from another terminal:
#openssl s_client -connect localhost:4433 -CAfile ca.crt

Note: The mechanics are identical in all three cases — the only difference is who signs the CSR and who trusts the signer. Self-signed means you trust yourself. Internal CA means your org distributes the root. Public CA means browsers already have the root in their trust store.
Let me know if you want to go deeper on any part — intermediate CAs, mTLS (client certs), certificate revocation (CRL/OCSP), or automating this with tools like step-ca or cfssl.

