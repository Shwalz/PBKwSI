#!/usr/bin/env bash
# Laboratorium 2: Kerberos + SSH (GSSAPI) w dwóch kontenerach Docker (Debian).
# Użycie: ./run_lab.sh   (wynik: logs/lab2.log)
set -u
cd "$(dirname "$0")"
REALM=REALM.KB.UWS.EDU.PL
HOST=kerberos.uws.edu.pl
NET=lab2net
IMG=debian:bookworm
LOG=logs/lab2.log
mkdir -p logs
: > "$LOG"
exec > >(tee -a "$LOG") 2>&1

srv() { docker exec -e DEBIAN_FRONTEND=noninteractive "$SRV" bash -c "$*"; }
cli() { docker exec -e DEBIAN_FRONTEND=noninteractive "$CLI" bash -c "$*"; }
step() { printf '\n\n===== %s =====\n' "$*"; }
run() { printf '\n$ %s\n' "$2"; "$1" "$2"; }

SRV=lab2-server; CLI=lab2-client
docker rm -f $SRV $CLI >/dev/null 2>&1
docker network rm $NET >/dev/null 2>&1
docker network create $NET >/dev/null
docker run -d --name $SRV --network $NET --network-alias $HOST --hostname $HOST $IMG sleep infinity >/dev/null
docker run -d --name $CLI --network $NET --hostname klient.uws.edu.pl $IMG sleep infinity >/dev/null

step "Zadanie 1. Instalacja serwera"
# Kontenery współdzielą zegar hosta, więc ntp nie jest potrzebny; zgodność czasu sprawdzamy poleceniem date.
srv "apt-get update -qq && apt-get install -y -qq krb5-kdc krb5-admin-server krb5-user openssh-server openssh-client >/dev/null 2>&1; echo instalacja: kod \$?"
run srv "hostname; date -u"
run cli "date -u"
run srv "grep -c . /etc/hosts; getent hosts $HOST"

step "Zadanie 2. Konfiguracja serwera i baza danych"
srv "cat > /etc/krb5.conf <<CONF
[libdefaults]
        default_realm = $REALM
        rdns = false
        dns_canonicalize_hostname = false

[realms]
        $REALM = {
                kdc = $HOST
                admin_server = $HOST
        }

[domain_realm]
        $HOST = $REALM
CONF
mkdir -p /etc/krb5kdc /var/lib/krb5kdc
cat > /etc/krb5kdc/kdc.conf <<CONF
[kdcdefaults]
    kdc_ports = 750,88

[realms]
    $REALM = {
        database_name = /var/lib/krb5kdc/principal
        admin_keytab = FILE:/etc/krb5kdc/kadm5.keytab
        acl_file = /etc/krb5kdc/kadm5.acl
        key_stash_file = /etc/krb5kdc/stash
        kdc_ports = 750,88
        max_life = 10h 0m 0s
        max_renewable_life = 7d 0h 0m 0s
        master_key_type = aes256-cts
        supported_enctypes = aes256-cts:normal aes128-cts:normal
        default_principal_flags = +preauth
    }
CONF
echo '*/admin@$REALM *' > /etc/krb5kdc/kadm5.acl"
run srv "cat /etc/krb5.conf /etc/krb5kdc/kdc.conf /etc/krb5kdc/kadm5.acl"
run srv "kdb5_util create -r $REALM -s -P masterpass123 2>&1 | tail -5"
run srv "ls -l /var/lib/krb5kdc"

step "Uruchomienie serwera Kerberos"
srv "service krb5-kdc start; service krb5-admin-server start" 2>&1
sleep 2
run srv "service krb5-kdc status; service krb5-admin-server status"

step "Zadanie 3. Zarządzanie użytkownikami"
srv "kadmin.local -q 'addprinc -pw adminpass1 student/admin'
kadmin.local -q 'addprinc -pw studentpass1 student'
kadmin.local -q 'addprinc -randkey host/$HOST'
kadmin.local -q 'ktadd host/$HOST'" 2>&1 | grep -v '^Authenticating'
run srv "kadmin.local -q listprincs"
run srv "klist -k /etc/krb5.keytab"

step "Zadanie 4. Konfiguracja serwera SSH"
srv "grep -q '^GSSAPIAuthentication yes' /etc/ssh/sshd_config || echo 'GSSAPIAuthentication yes' >> /etc/ssh/sshd_config
grep -q '^GSSAPICleanupCredentials yes' /etc/ssh/sshd_config || echo 'GSSAPICleanupCredentials yes' >> /etc/ssh/sshd_config
useradd -m -s /bin/bash student; mkdir -p /run/sshd; service ssh start"
run srv "grep -E '^GSSAPI' /etc/ssh/sshd_config; service ssh status; id student"

step "Zadanie 5. Klient: uwierzytelnianie przez Kerberos"
cli "apt-get update -qq && apt-get install -y -qq krb5-user openssh-client >/dev/null 2>&1; echo instalacja: kod \$?"
cli "cat > /etc/krb5.conf <<CONF
[libdefaults]
        default_realm = $REALM
        rdns = false
        dns_canonicalize_hostname = false

[realms]
        $REALM = {
                kdc = $HOST
                admin_server = $HOST
        }

[domain_realm]
        $HOST = $REALM
CONF
printf 'Host *\n    GSSAPIAuthentication yes\n    GSSAPIKeyExchange yes\n' >> /etc/ssh/ssh_config"
run cli "tail -4 /etc/ssh/ssh_config"
run cli "echo studentpass1 | kinit student"
run cli "klist"
# Debian nie zawsze zawiera łatkę GSSAPIKeyExchange; wtedy ssh ignoruje opcję z ostrzeżeniem.
run cli "ssh -v -o StrictHostKeyChecking=accept-new -o PasswordAuthentication=no -o PubkeyAuthentication=no student@$HOST 'whoami; hostname; klist 2>&1 | head -5' 2>&1 | grep -E 'GSSAPI|gss|Authenticat|Authenticated|student|kerberos|Bad option|Unsupported'"
run cli "klist"
run srv "grep -iE 'gssapi|accepted' /var/log/auth.log 2>/dev/null | tail -5; true"

step "Kontrola negatywna: bez biletu logowanie bez hasła nie działa"
run cli "kdestroy; ssh -o StrictHostKeyChecking=accept-new -o PasswordAuthentication=no -o PubkeyAuthentication=no -o BatchMode=yes student@$HOST whoami 2>&1 | tail -2"
