# Laboratorium 1. Urząd certyfikacji w OpenSSL

Autor: Yahor Falkouski. OpenSSL 3.6.5, macOS.

Uruchomienie: `NAME="Imię Nazwisko" ./run_lab.sh`. Skrypt tworzy katalog `work/` i zapisuje wynik w `logs/lab1.log`.

## Odpowiedzi na pytania

- **1d.** Deszyfrowanie `tekst.out` kluczem `dane.key` zwróciło oryginalny tekst. `cmp` nie znalazł różnic.
- **4c.** Plik `serial` zmienił się z `01` na `02`. W `index.txt` pojawił się wpis ze statusem `V`, serią `01` i danymi właściciela.
- **4d.** OpenSSL odrzucił drugi certyfikat dla tego samego zgłoszenia: `There is already a certificate`. Powodem jest `unique_subject = yes`.
- **5g.** Opcje `-crldays 7 -crlhours 12` ustawiły następną listę CRL na 15 października 2026, 02:26:41 GMT. Sprawdzenie: `openssl crl -in crl/lista_2.crl -noout -nextupdate`.
- **6c.** Import certyfikatu CA nie daje zaufania automatycznie. Pęk kluczy pokazał `This root certificate is not trusted` ([zrzut](screenshots/6c_ca_not_trusted.png)). Po ustawieniu `Always Trust` certyfikat użytkownika dostał status `valid` ([zrzut](screenshots/6c_user_cert_valid.png)).

## Import PKCS#12 (6b)

Przeglądarka Brave korzysta z Pęku kluczy macOS. Plik `work/01.p12` (hasło w `work/passwords.txt`, plik poza repozytorium) trafił do pęku `login`. Przed zaufaniem do CA certyfikat miał status `not trusted` ([zrzut](screenshots/6b_user_cert_not_trusted.png)).

## Konfiguracja

Plik `work/openssl.cnf` spełnia wszystkie wymagania zadania 2: CA `moje_ca`, katalog `.`, ważność 100 dni, CRL co 20 dni, dopasowanie `countryName` i `stateOrProvinceName`, wymagane `commonName` i `emailAddress`, hasło od 6 znaków, domyślne `PL` i `mazowieckie`, komentarz `testowy certyfikat` oraz `basicConstraints = CA:FALSE`.
