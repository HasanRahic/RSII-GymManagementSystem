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

- .NET SDK 10.0
- Flutter SDK
- Docker Desktop
- Android Studio emulator za Android build provjeru

## Konfiguracija

Osjetljiva konfiguracija se cuva u root `.env` fajlu. Repo sadrzi `.env.example`, a stvarne vrijednosti drzis lokalno u `.env`.

Kopiranje example konfiguracije:

```powershell
Copy-Item .\.env.example .\.env
```

Backend i notification servis automatski ucitavaju `.env` iz root foldera projekta.

Flutter klijenti podrzavaju `--dart-define` konfiguraciju bez izmjene source koda:

```powershell
flutter run --dart-define=SERVER_BASE_URL=http://localhost:5190
flutter run --dart-define=API_BASE_URL=http://localhost:5190/api
```

Podrazumijevane vrijednosti:

- Android emulator: `http://10.0.2.2:5190`
- Windows desktop: `http://localhost:5190`

## Pokretanje backend sistema

1. Podigni infrastrukturu i notification servis:

```powershell
docker compose up -d sqlserver rabbitmq gym.notifications
```

2. Pokreni API lokalno:

```powershell
dotnet run --project .\backend\Gym.Api\Gym.Api.csproj
```

Alternativno, citav sistem mozes podici kroz Docker:

```powershell
docker compose up -d
```

Docker image-i sada koriste .NET 10, uskladjeno sa target frameworkom projekata (`net10.0`).

Ako koristis potpuno dockerizirani API, baza za Flutter klijente je:

- Windows desktop: `http://localhost:5000`
- Android emulator: `http://10.0.2.2:5000`

Primjer:

```powershell
flutter run --dart-define=SERVER_BASE_URL=http://localhost:5000
```

## Seed podaci i korisnicki nalozi

Baza se seed-a pri pokretanju API-ja.

Pristupni podaci:

- Desktop admin: `admin / test`
- Mobilni clan: `member / test`
- Mobilni trener: `trainer / test`
- Dodatni mobilni clanovi: `amel / test`, `lejla / test`

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

Windows release:

```powershell
cd .\apps\flutter-desktop
flutter clean
flutter build windows --release
```

Za pripremu arhive za predaju:

```powershell
.\resources\scripts\run-backend.ps1
.\resources\scripts\build-submission.ps1
```

Skripta kreira lokalni ZIP u `resources/submission/`. Taj folder je namjerno ignorisan iz Git-a jer build artefakti vise ne trebaju biti dio source repozitorija.

## Predaja po pravilima 2025/26

1. Napravi release build za Android i Windows.
2. Pokreni `.\resources\scripts\build-submission.ps1` da dobijes jedan predajni ZIP.
3. Na GitHub-u otvori novi `Release` i kreiraj tag u formatu slicnom `fit-build-2026-06-01_v1.0`.
4. U sekciji `Assets` uploaduj generisani ZIP iz `resources/submission/`.
5. Na DL postavi link na tacan GitHub release, ne samo na repo.

Napomene:

- Source code ostaje u repozitoriju, a ZIP ide iskljucivo kroz GitHub Release.
- `.env` nemoj commitovati.
- Ako je neki ZIP ranije bio commitovan, ukloni ga iz pracenja prije finalne predaje.
