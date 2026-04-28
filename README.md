# RSII Gym Management System

Seminarski rad iz predmeta Razvoj softvera II. Projekat sadrzi:

- `backend/Gym.Api` REST API
- `backend/Gym.Notifications` pomocni mikroservis za RabbitMQ notifikacije
- `flutter-desktop` administratorsku desktop aplikaciju
- `flutter-mobile` mobilnu aplikaciju za clanove i trenere

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

Svi kljucni runtime parametri objedinjeni su u `.env.example`.

Za docker scenarij:

```powershell
Copy-Item .env.example .env
```

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
cd .\flutter-desktop
flutter pub get
flutter run -d windows
```

Ako backend radi na portu `5000`:

```powershell
flutter run -d windows --dart-define=SERVER_BASE_URL=http://localhost:5000
```

## Pokretanje mobilne aplikacije

```powershell
cd .\flutter-mobile
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
cd .\flutter-mobile
flutter clean
flutter build apk --release
```

Ocekivani izlaz:

- `flutter-mobile/build/app/outputs/flutter-apk/app-release.apk`

Windows release:

```powershell
cd .\flutter-desktop
flutter clean
flutter build windows --release
```

Ocekivani izlaz:

- `flutter-desktop/build/windows/x64/runner/Release/gym_desktop.exe`

Za pripremu arhive za predaju koristi skriptu:

```powershell
.\run-backend.ps1
.\submission\build-submission.ps1
```

## Recommender dokumentacija

Dokumentacija sistema preporuke nalazi se u:

- `docs/recommender-dokumentacija.pdf`

Izvorni markdown za dokumentaciju:

- `docs/recommender-dokumentacija.md`

## Napomena za evaluaciju

Projekat je pripremljen tako da se moze pokrenuti bez izmjene source koda. Za promjenu API adrese koristi se iskljucivo konfiguracija (`appsettings`, `.env`, `--dart-define`), ne rucna izmjena fajlova.
