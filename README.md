# CRP Restaurants Script

## Beschrijving
Een restaurant management systeem voor FiveM servers. Het script maakt het mogelijk voor spelers om:
- Bestellingen te plaatsen bij verschillende restaurants
- Betalingen te verwerken via kassa's
- Bestellingen te beheren als medewerker
- Real-time order notificaties te ontvangen



## Let op: Work in Progress
Dit script is nog in ontwikkeling. De volgende zaken moeten nog worden toegevoegd/verbeterd:

### Security
- [ ] Rate limiting op betalingen
- [ ] Betere validatie van order data
- [ ] Anti-exploit checks
- [ ] Logging systeem voor transacties
- [ ] Betere error handling

### Features
- [ ] Thuisbezorgd app met lb-phone

### Bekende Issues
- Soms dubbele notificaties bij nieuwe bestellingen

## Vereisten
- QBX Core -- kan altijd overgeschreven worden naar ESX
- ox_lib
- sleepless_interact

## Installatie
1. Zorg dat alle dependencies zijn geïnstalleerd
2. Kopieer de bestanden naar je resources map
3. Voeg `ensure crp-restaurants` toe aan je server.cfg
4. Start de server

## Development
Voor development:
1. Run `pnpm install` in de web directory
2. Start de dev server met `pnpm dev`
3. Zet `ui_page` in fxmanifest.lua op localhost:3000