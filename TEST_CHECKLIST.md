# 3F Training — Manual Test Checklist

> Eseguire prima di ogni release. Spuntare ogni voce dopo verifica OK.

---

## Auth

- [ ] Login con credenziali corrette → redirect al proprio shell (owner/staff/client)
- [ ] Login con credenziali errate → messaggio errore, nessun redirect
- [ ] Logout → redirect a `/login`, sessione invalidata
- [ ] Accesso diretto a route protetta senza login → redirect a `/login`
- [ ] Profilo pubblico `/u/:userId` accessibile senza login

---

## Owner — Dashboard & Onboarding

- [ ] Wizard onboarding visibile su studio senza sala/trainer/corso/piano
- [ ] Wizard scompare dopo aver completato tutti i 4 step
- [ ] Cambio sede dal selettore in alto → dati aggiornati

---

## Owner — Sale

- [ ] Lista sale visualizzata correttamente
- [ ] Aggiunta nuova sala (nome + capacità) → appare in lista
- [ ] Modifica sala esistente → dati aggiornati
- [ ] Eliminazione sala → rimossa dalla lista

---

## Owner — Corsi

- [ ] Lista corsi con tipo e responsabile
- [ ] Creazione corso (nome, tipo, class_owner, ore disdetta, descrizione) → appare in lista
- [ ] CourseDetailScreen: header, chip info, descrizione, prossime lezioni
- [ ] Lezioni ricorrenti create correttamente dalla staff sheet

---

## Owner — Team

- [ ] Lista trainer/class_owner visibile
- [ ] Aggiunta trainer via Edge Function → appare in lista
- [ ] `class_owner` riceve automaticamente anche ruolo `trainer`

---

## Owner — Clienti

- [ ] Lista clienti con stato piano (warning arancio se crediti ≤ 2 o scadenza ≤ 7 gg)
- [ ] Aggiunta cliente via Edge Function → appare in lista
- [ ] ClientDetailScreen: contatti, piano attivo, prenotazioni recenti con status

---

## Owner — Piani

- [ ] Lista piani con tipo/prezzo/crediti/durata
- [ ] Creazione piano `credits` → appare in lista
- [ ] Creazione piano `unlimited` → appare in lista
- [ ] Creazione piano `trial` → appare in lista
- [ ] Modifica piano → dati aggiornati
- [ ] Eliminazione piano → rimosso dalla lista
- [ ] Richiesta client in attesa → card visibile con Approva/Rifiuta
- [ ] Approvazione richiesta → `user_plans` creato, richiesta sparisce
- [ ] Rifiuto richiesta → richiesta sparisce

---

## Owner — Report

- [ ] Report visualizzato senza errori
- [ ] Dati aggregati coerenti con le prenotazioni presenti

---

## Owner — Notifiche

- [ ] Invio comunicazione senza titolo → validazione blocca
- [ ] Invio con solo titolo → notifica creata (body null)
- [ ] Invio con titolo + messaggio → notifica con tutti i campi
- [ ] Notifica appare immediatamente in lista (Realtime)
- [ ] Badge su tab Notifiche appare per staff/client dopo invio

---

## Staff — Calendario

- [ ] Lezioni del giorno visualizzate correttamente
- [ ] TableCalendar stilizzato brand, dot marker su giorni con lezioni
- [ ] Tap su giorno → lista lezioni aggiornata
- [ ] Pulsante "Presenze" naviga a `/staff/roster/:lessonId`

---

## Staff — Presenze (Roster)

- [ ] Header lezione con data/ora + badge "X/Y presenti"
- [ ] Lista iscritti con colore row (verde/rosso/bianco per stato)
- [ ] Bottoni ✓/✗/↩ aggiornano stato su Supabase
- [ ] Contatore presenti aggiornato in tempo reale

---

## Staff — Notifiche

- [ ] Lista notifiche visibile (solo studio corrente)
- [ ] Badge su tab scompare dopo apertura schermata
- [ ] Nuova notifica appare in lista senza refresh (Realtime)

---

## Client — Calendario

- [ ] Calendario con dot marker su giorni con lezioni
- [ ] Tap su lezione → dettaglio con info corso, orario, posti
- [ ] Prenotazione lezione con piano valido → booking confermato
- [ ] Prenotazione senza piano → errore o redirect ai piani
- [ ] Prenotazione lezione già piena → entrata in waitlist
- [ ] Cancellazione entro deadline → booking cancellato, credito restituito
- [ ] Cancellazione oltre deadline → bloccata con messaggio

---

## Client — Piani

- [ ] Lista piani disponibili con tipo/prezzo/crediti/durata
- [ ] Richiesta piano → banner "in attesa" visibile
- [ ] Doppia richiesta bloccata (bottone disabilitato)
- [ ] Ritiro richiesta → banner scompare

---

## Client — Prenotazioni

- [ ] Lista prenotazioni con status (booked/attended/no_show/cancelled)
- [ ] Prenotazione cancellata visibile con stato corretto

---

## Client — Notifiche

- [ ] Notifiche studio visibili (RLS: solo studio corrente)
- [ ] Notifica di studio diverso non visibile
- [ ] Badge scompare dopo apertura
- [ ] Stato vuoto con messaggio corretto se nessuna notifica

---

## Profilo

- [ ] Staff: modifica nome, bio, Instagram, specializzazioni, foto
- [ ] Staff: avatar aggiornato in Supabase Storage
- [ ] Client: piano attivo e prossime prenotazioni visibili (sola lettura)
- [ ] Profilo pubblico `/u/:userId`: SliverAppBar, bio, specializzazioni chip

---

## Multi-sede & RLS

- [ ] Owner con due sedi: switch sede → dati cambiano
- [ ] Notifica inviata da Sede 1 non visibile a client di Sede 2
- [ ] Prenotazione su lezione di Sede 1 non visibile da Sede 2

---

## Routing & Redirect

- [ ] Owner non può accedere a route `/staff/*` o `/client/*`
- [ ] Client non può accedere a route `/owner/*`
- [ ] Admin vede `/admin/dashboard`, `/admin/studios`, `/admin/users`
