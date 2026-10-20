# Laboratorium 2. Uwierzytelnianie Kerberos i SSH

Środowisko: macOS z Dockerem. Dwa kontenery Debian 12 w sieci `lab2net`: serwer `kerberos.uws.edu.pl` i klient `klient.uws.edu.pl`.
Uruchomienie: `./run_lab.sh`. Pełny wynik zapisuje `logs/lab2.log`.

## Zadania

1. **Instalacja serwera.** Zainstalowałem `krb5-kdc`, `krb5-admin-server`, `krb5-user` i `openssh-server`. Kontener nosi nazwę `kerberos.uws.edu.pl`. Kontenery korzystają z zegara hosta, więc pominąłem `ntp` i porównałem `date -u` na obu maszynach. Wyniki są identyczne.
2. **Konfiguracja.** Utworzyłem `/etc/krb5.conf`, `/etc/krb5kdc/kdc.conf` i `kadm5.acl` (`*/admin@REALM.KB.UWS.EDU.PL *`) dla domeny `REALM.KB.UWS.EDU.PL`. Polecenie `kdb5_util create -r REALM.KB.UWS.EDU.PL -s` utworzyło pliki `principal`, `principal.kadm5`, `principal.kadm5.lock` i `principal.ok`. Następnie uruchomiłem `krb5-kdc` i `krb5-admin-server`.
3. **Użytkownicy.** Dodałem `student`, `student/admin` i `host/kerberos.uws.edu.pl` (`addprinc -randkey` oraz `ktadd`). Polecenie `listprincs` wypisuje wszystkich uczestników, a `klist -k` pokazuje klucze hosta w keytabie.
4. **SSH.** W `sshd_config` ustawiłem `GSSAPIAuthentication yes` i `GSSAPICleanupCredentials yes`. Założyłem konto systemowe `student` i uruchomiłem sshd.
5. **Klient.** Zainstalowałem `krb5-user`, wpisałem domenę do `krb5.conf` i dodałem `GSSAPIAuthentication yes` oraz `GSSAPIKeyExchange yes` do `ssh_config`. Po `kinit student` `klist` pokazuje bilet `krbtgt/...`. Polecenie `ssh -v student@kerberos.uws.edu.pl` kończy się komunikatem `Authenticated ... using "gssapi-with-mic"` i nie pyta o hasło. Po logowaniu `klist` wypisuje też bilet usługi `host/kerberos.uws.edu.pl@REALM.KB.UWS.EDU.PL`. Po `kdestroy` serwer odrzuca logowanie bez hasła.

## Zmiany względem instrukcji

- `master_key_type = aes256-cts` zastępuje przestarzały `des3-hmac-sha1`. W `supported_enctypes` stoją aes256 i aes128.
- W `krb5.conf` dodałem `rdns = false` i `dns_canonicalize_hostname = false`. Docker rozwiązywał adres serwera na `kerberos.lab2net`, więc klient szukał nieistniejącego `krbtgt/LAB2NET@...` i zgłaszał `Unspecified GSS failure`.
- Metoda `gssapi-keyex` nie działa, bo Debian nie zawiera łatki GSSAPIKeyExchange. Logowanie przechodzi metodą `gssapi-with-mic`.
- Hasła testowe: master `masterpass123`, `student` `studentpass1`, `student/admin` `adminpass1`.
