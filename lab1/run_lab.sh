#!/usr/bin/env bash
set -euo pipefail

NAME="${NAME:-Yahor Falkouski}"

ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$ROOT/work"
rm -rf "$WORK"
mkdir -p "$WORK" "$ROOT/logs"
cd "$WORK"
exec > >(sed "s#$WORK#.#g" | tee "$ROOT/logs/lab1.log") 2>&1

export CA_PASS="$(openssl rand -hex 12)"
export P12_PASS="$(openssl rand -hex 12)"
umask 077
printf 'CA: %s\nPKCS12: %s\n' "$CA_PASS" "$P12_PASS" > passwords.txt
umask 022

step() { printf '\n=== %s ===\n' "$*"; }
run()  { printf '$ %s\n' "$*"; "$@"; }

step "Zadanie 1a: wersja OpenSSL"
run openssl version -a

step "Zadanie 1b: hasze MD5 i SHA-1"
printf '%s' "$NAME" | openssl md5  > moje_dane.md5
printf '%s' "$NAME" | openssl sha1 > moje_dane.sha
cat moje_dane.md5 moje_dane.sha

step "Zadanie 1c: klucz HEX 2048 bit i szyfrowanie AES-256-CBC"
openssl rand -hex 256 > dane.key
echo "dane.key: $(tr -d '\n' < dane.key | wc -c | tr -d ' ') znakow HEX"
printf '%s\n' "$NAME" > tekst.in
run openssl enc -aes-256-cbc -salt -pbkdf2 -in tekst.in -out tekst.out -pass file:dane.key
xxd tekst.out | head -2

step "Zadanie 1d: deszyfrowanie"
run openssl enc -aes-256-cbc -d -pbkdf2 -in tekst.out -out tekst.decrypt -pass file:dane.key
cat tekst.decrypt
cmp tekst.in tekst.decrypt && echo "OK: tekst.decrypt identyczny z tekst.in"

step "Zadanie 2: konfiguracja openssl.cnf"
cat > openssl.cnf <<'CNF'
HOME = .

[ ca ]
default_ca = moje_ca

[ moje_ca ]
dir              = .
certs            = $dir/certs
crl_dir          = $dir/crl
database         = $dir/index.txt
new_certs_dir    = $dir/newcerts
certificate      = $dir/cacert.pem
serial           = $dir/serial
crlnumber        = $dir/crlnumber
crl              = $dir/crl.pem
private_key      = $dir/private/cakey.pem
x509_extensions  = usr_cert
copy_extensions  = none
default_days     = 100
default_crl_days = 20
default_md       = sha256
preserve         = no
unique_subject   = yes
policy           = policy_match

[ policy_match ]
countryName            = match
stateOrProvinceName    = match
organizationName       = optional
organizationalUnitName = optional
localityName           = optional
commonName             = supplied
emailAddress           = supplied

[ req ]
default_bits       = 2048
default_keyfile    = privkey.pem
distinguished_name = req_distinguished_name
attributes         = req_attributes
x509_extensions    = v3_ca
string_mask        = utf8only

[ req_distinguished_name ]
countryName = Kod kraju (podaj 2 litery)
countryName_default = PL
countryName_min = 2
countryName_max = 2
stateOrProvinceName = Nazwa wojewodztwa
stateOrProvinceName_default = mazowieckie
localityName = Lokalizacja (np. miasto)
localityName_default = Siedlce
0.organizationName = Nazwa organizacji
0.organizationName_default = UwS
organizationalUnitName = Nazwa jednostki
organizationalUnitName_default = Instytut Informatyki
commonName = Imie i nazwisko wlasciciela
commonName_max = 64
emailAddress = Adres skrzynki e-mail
emailAddress_max = 64

[ req_attributes ]
challengePassword = Podaj haslo
challengePassword_default = challenge6
challengePassword_min = 6
challengePassword_max = 20

[ usr_cert ]
basicConstraints = CA:FALSE
nsComment        = "testowy certyfikat"

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical,CA:TRUE
CNF
export OPENSSL_CONF="$WORK/openssl.cnf"
cat openssl.cnf

step "Zadanie 3a: struktura katalogow i plikow"
mkdir -p certs crt newcerts private crl
touch index.txt
echo 01 > serial
echo 01 > crlnumber
ls

step "Zadanie 3b: klucz CA 4096 bit zaszyfrowany 3DES"
run openssl genrsa -out private/cakey.pem 4096
run openssl rsa -in private/cakey.pem -out private/cakey.enc -outform PEM -des3 -passout env:CA_PASS
mv private/cakey.enc private/cakey.pem
head -1 private/cakey.pem

step "Zadanie 3c: autocertyfikat CA na dwa lata"
run openssl req -new -x509 -batch -days 730 -passin env:CA_PASS -key private/cakey.pem \
  -out cacert.pem -subj "/C=PL/ST=mazowieckie/L=Siedlce/O=UwS/OU=Instytut Informatyki/CN=moje_ca/emailAddress=ca@example.com"
openssl x509 -in cacert.pem -noout -subject -issuer -dates

step "Zadanie 4a: klucz uzytkownika i zgloszenie"
USER_SUBJ="/C=PL/ST=mazowieckie/L=Siedlce/O=UwS/OU=Instytut Informatyki/CN=$NAME/emailAddress=student@example.com"
run openssl genrsa -out newkey01.pem 2048
openssl req -new -batch -key newkey01.pem -out moje_req01.req -subj "$USER_SUBJ"
openssl req -in moje_req01.req -noout -subject -verify

step "Zadanie 4b: CA wystawia certyfikat"
echo "serial: $(cat serial)"
echo "index.txt: [$(cat index.txt)]"
run openssl ca -batch -in moje_req01.req -passin env:CA_PASS -notext -out user01.pem
ls newcerts

step "Zadanie 4c: zmiany w serial i index.txt"
echo "serial: $(cat serial) (serial.old: $(cat serial.old))"
cat index.txt
openssl x509 -in newcerts/01.pem -noout -subject -issuer -dates -ext basicConstraints
openssl x509 -in newcerts/01.pem -noout -text | grep -A1 -i "comment"

step "Zadanie 4d: drugi certyfikat dla tego samego zgloszenia"
if openssl ca -batch -in moje_req01.req -passin env:CA_PASS -notext -out user02.pem; then
  echo "certyfikat utworzony"
else
  echo "certyfikat NIE zostal utworzony"
fi

step "Zadanie 5e: lista CRL przed uniewaznieniem"
run openssl ca -gencrl -passin env:CA_PASS -out crl/lista_1.crl
openssl crl -in crl/lista_1.crl -noout -text | head -12

step "Zadanie 5f: uniewaznienie certyfikatu"
run openssl ca -revoke newcerts/01.pem -passin env:CA_PASS
cat index.txt

step "Zadanie 5g: lista CRL z crldays i crlhours"
run openssl ca -gencrl -crldays 7 -crlhours 12 -passin env:CA_PASS -out crl/lista_2.crl
openssl crl -in crl/lista_2.crl -noout -text | head -16
openssl crl -in crl/lista_2.crl -noout -lastupdate -nextupdate

step "Zadanie 6a: PKCS #12"
run openssl pkcs12 -export -in newcerts/01.pem -inkey newkey01.pem -certfile cacert.pem \
  -out 01.p12 -passout env:P12_PASS
openssl pkcs12 -in 01.p12 -passin env:P12_PASS -info -noout 2>&1 | head -5

step "Weryfikacja lancucha"
openssl verify -CAfile cacert.pem newcerts/01.pem || true
openssl verify -crl_check -CAfile cacert.pem -CRLfile crl/lista_2.crl newcerts/01.pem || true
