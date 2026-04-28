# Recommender dokumentacija

## Naziv modula

Sistem preporuke teretana i grupnih treninga unutar aplikacije `RSII Gym Management System`.

## Svrha

Modul preporuke predlaze korisniku teretane koje su najrelevantnije na osnovu:

- korisnikove aktivne teretane
- historije check-in dolazaka
- potvrdenih i placenih grupnih treninga
- preferiranih tipova treninga
- dostupnosti termina i popunjenosti kapaciteta

## Implementacija

Glavna logika preporuke implementirana je u backend servisu:

- `backend/Gym.Services/Services/TrainingSessionService.cs`

REST endpoint koji vraca preporuke:

- `backend/Gym.Api/Controllers/TrainingSessionsController.cs`

Flutter mobilni klijent koji poziva preporuke:

- `apps/flutter-mobile/lib/services/api_services.dart`

## Kratak opis algoritma

Algoritam koristi jednostavni content-based i behavior-based scoring model:

1. Ucita korisnika, grad, aktivnu teretanu i historiju aktivnosti.
2. Ucita sve check-in zapise korisnika.
3. Ucita potvrdene rezervacije i uspjesno placene grupne treninge.
4. Formira tezine za tipove treninga koje korisnik najvise koristi.
5. Za svaku teretanu racuna score na osnovu:
   - otvorenog statusa
   - podudarnosti grada
   - primarne teretane
   - broja prethodnih posjeta
   - podudarnosti tipova treninga
   - broja aktivnih termina
   - omjera popunjenosti kapaciteta
6. Rezultate sortira po skoru i vraca top preporuke.

## Razlog odabira pristupa

Za seminarski rad odabran je jednostavniji algoritam preporuke koji:

- ne zahtijeva eksterni ML servis
- moze raditi odmah nad podacima iz relacione baze
- lako se objasnjava i testira
- daje korisne preporuke i sa manjim skupom seed podataka

## Putanja glavne logike

- `backend/Gym.Services/Services/TrainingSessionService.cs`
- metoda: `GetRecommendedGymsAsync`

## Prilozi

U PDF dokumentaciji prilozeni su:

- printscreen source code-a glavne logike preporuke
- prikaz preporuka u aplikacijskom interfejsu sa seeded podacima

## Testni scenario

Za testiranje preporuka mogu se koristiti seeded korisnici:

- `member / test`
- `trainer / test`

Korisnik `member` ima aktivnu teretanu `FitZone Sarajevo`, historiju check-in zapisa i progres mjerenja, sto omogucava demonstraciju personalizovanih preporuka.
