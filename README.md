# RSII Gym Management System

Seminarski rad iz predmeta Razvoj softvera II. Projekat sadrzi:

- `backend/Gym.Api` REST API
- `backend/Gym.Notifications` pomocni mikroservis za RabbitMQ notifikacije
- `apps/flutter-desktop` administratorsku desktop aplikaciju
- `apps/flutter-mobile` mobilnu aplikaciju za clanove i trenere

## Arhitektura

- Baza: SQL Server
- Komunikacija izmedju servisa: RabbitMQ
- Mikroservisi: `Gym.Api` + `Gym.Notifications`
- Klijenti: Flutter desktop i Flutter mobile
- Sistem preporuke: preporuka teretana na osnovu aktivnosti korisnika, aktivne teretane i preferiranih tipova treninga

## Preduslovi

- .NET SDK 9 ili noviji
- Flutter SDK
- Docker Desktop
- Android Studio emulator za Android build provjeru

## Konfiguracija

Po novim pravilima predaje, osjetljiva konfiguracija nije u `appsettings.json`, nego u `.env`.
Repo sadrzi samo `.env.example`, a stvarne vrijednosti drzis lokalno u `.env`.

Za docker scenarij:

```powershell
Copy-Item .env.example .env
```

Backend i notification servis automatski ucitavaju `.env` iz root foldera projekta.

Flutter klijenti podrzavaju i `--dart-define` konfiguraciju, bez izmjene source koda:

```powershell
flutter run --dart-define=SERVER_BASE_URL=http://localhost:5190
flutter run --dart-define=API_BASE_URL=http://localhost:5190/api
```

Podrazumijevane vrijednosti:

- Android emulator: `http://10.0.2.2:5190`
- Windows desktop: `http://localhost:5190`

## Pokretanje backend sistema

Najjednostavniji nacin za pokretanje bez izmjene koda:

1. Podigni infrastrukturu i pomocni servis:

```powershell
docker compose up -d sqlserver rabbitmq gym.notifications
```

2. Pokreni API lokalno:

```powershell
dotnet run --project .\backend\Gym.Api\Gym.Api.csproj
```

Alternativno, mozes pokrenuti sve kroz docker:

```powershell
docker compose up -d
```

Ako koristis potpuno dockerizirani API, baza za Flutter klijente je:

- Windows desktop: `http://localhost:5000`
- Android emulator: `http://10.0.2.2:5000`

Primjer:

```powershell
flutter run --dart-define=SERVER_BASE_URL=http://localhost:5000
```

## Seed podaci i korisnicki nalozi

Baza se migrira i seed-a pri pokretanju API-ja.

Pristupni podaci:

- Desktop admin: `admin / test`
- Mobilni clan: `member / test`
- Mobilni trener: `trainer / test`
- Dodatni mobilni clanovi: `amel / test`, `lejla / test`

Napomena: projekat koristi vise korisnickih uloga, pa su login nalozi imenovani po ulozi ili testnim korisnicima iz seed podataka.

## Pokretanje desktop aplikacije

```powershell
cd .\apps\flutter-desktop
flutter pub get
flutter run -d windows
```

Ako backend radi na portu `5000`:

```powershell
flutter run -d windows --dart-define=SERVER_BASE_URL=http://localhost:5000
```

## Pokretanje mobilne aplikacije

```powershell
cd .\apps\flutter-mobile
flutter pub get
flutter run
```

Ako backend radi na portu `5000`:

```powershell
flutter run --dart-define=SERVER_BASE_URL=http://10.0.2.2:5000
```

## Build za predaju

Android release:

```powershell
cd .\apps\flutter-mobile
flutter clean
flutter build apk --release
```

Ocekivani izlaz:

- `apps/flutter-mobile/build/app/outputs/flutter-apk/app-release.apk`

Windows release:

```powershell
cd .\apps\flutter-desktop
flutter clean
flutter build windows --release
```

Ocekivani izlaz:

- `apps/flutter-desktop/build/windows/x64/runner/Release/gym_desktop.exe`

Za pripremu arhive za predaju koristi skriptu:

```powershell
.\resources\scripts\run-backend.ps1
.\resources\scripts\build-submission.ps1
```

## Recommender dokumentacija

Dokumentacija sistema preporuke nalazi se u:

- `resources/docs/recommender-dokumentacija.pdf`

Izvorni markdown za dokumentaciju:

- `resources/docs/recommender-dokumentacija.md`

## Predaja po novim uputama

- Napravi GitHub `Release` za verziju koju predajes.
- U release priloge dodaj Android APK i Windows build artefakte.
- `.env` nemoj commitovati; ako profesor trazi, dostavi ga odvojeno kao zasticenu arhivu prema uputama.
- Na DL postavi link na tacan GitHub release, ne samo na repo.

## Napomena za evaluaciju

Projekat je pripremljen tako da se moze pokrenuti bez izmjene source koda. Za promjenu API adrese koristi se iskljucivo konfiguracija (`.env`, `--dart-define`, docker env varijable), ne rucna izmjena fajlova.

## Struktura repozitorija

- `backend/` backend servisi i domena
- `apps/` Flutter desktop i mobilna aplikacija
- `resources/docs/` dokumentacija i recommender prilozi
- `resources/submission/` predajni artefakti za profesora
- `resources/scripts/` pomocne skripte za pokretanje i pripremu predaje
