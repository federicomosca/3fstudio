# 3F Training

App Flutter per la gestione di prenotazioni e corsi di **AL.FA.SE asd** — due sedi a Palermo (Vincenzo Alagna, owner). Nata per sostituire WhatsApp/Excel con uno strumento semplice e dimostrabile in 5 minuti.

## Stack

- **Frontend**: Flutter (Dart) — Material 3
- **Backend**: Supabase (PostgreSQL + Auth + Storage + Edge Functions)
- **State management**: Riverpod (FutureProvider, AsyncNotifier, StateProvider)
- **Routing**: GoRouter con ShellRoute per ruolo

## Ruoli utente (additivi per studio)

| Ruolo | Accesso |
|---|---|
| `admin` | Pannello globale (multi-studio) |
| `gym_owner` | Dashboard owner, CRUD sale/corsi/team/clienti/piani |
| `class_owner` | Staff shell — responsabile di uno o più corsi |
| `trainer` | Staff shell — vede solo le proprie lezioni |
| `client` | Calendario pubblico + prenotazioni |

Un utente può avere più ruoli contemporaneamente (es. Vincenzo è owner + class_owner + trainer).

**Nessuna registrazione pubblica.** Gli utenti vengono creati da Vincenzo tramite la Edge Function `admin-create-user`.

## Sedi

- **Sede 1**: Via Aquileia, 34 – Palermo (principale)
- **Sede 2**: Via Regione Siciliana, 3604 – Palermo

## Brand

- Nome app: **3F Training**
- Logo: cerchio azzurro chiaro (`#EDF2F8`), testo "3F" blu medio, scritta "TRAINING" navy scuro, archi e triangoli cyan
- Palette principale:
  - `navy   = #0A1A0E` — sfondo scuro, AppBar, NavBar (verde foresta)
  - `blue   = #1EA850` — accento principale (verde)
  - `cyan   = #50D080` — accento secondario (verde chiaro)
  - `lightBg = #EDF7EF` — sfondo light mode
- Alias per retrocompatibilità: `charcoal = navy`, `lime = blue`
- **Dark mode forzata** (`ThemeMode.dark` in main.dart)
- Tagline: *"Qui non ti alleni. Impari ad allenarti."*
- Stile fitness: kettlebell, flow motion, corpo libero, calisthenics, pesistica, cardio

## Struttura progetto

```
lib/
  core/
    models/         # Lesson, UserRole, AppRoles, UserProfile
    providers/      # studio_provider (studioId, appRoles, supabase client)
    router/         # app_router.dart — GoRouter con redirect per ruolo
    theme/          # app_theme.dart — charcoal+lime, Material 3
  features/
    auth/           # login_screen, auth_provider (solo signIn/signOut)
    booking/        # booking_provider, prenotazione/cancellazione
    calendar/       # CalendarScreen (client), lessons_provider, lesson_card
    client/         # ClientCalendarScreen, MyBookingsScreen
    owner/          # Dashboard, Sale, Corsi, Team, Clienti, Piani, Report
    profile/        # ProfileScreen (staff editabile / client sola lettura)
                    # PublicProfileScreen (/u/:userId)
    staff/          # StaffCalendarScreen, RosterScreen, MyCoursesScreen
    admin/          # AdminDashboard, StudiosScreen, GlobalUsersScreen
  shared/
    widgets/        # Shell (Admin/Owner/Staff/Client), LessonCard, ComingSoon
assets/
  icon/             # app_icon.png, app_icon_fg.png (1024×1024, generati da Dart)
tool/
  generate_icon/    # Script Dart puro per generare i PNG dell'icona
supabase/
  functions/
    admin-create-user/  # Edge Function con service role key
scripts/
  mock.mjs          # Seed dati AL.FA.SE asd
```

## Database (Supabase)

Tabelle: `studios`, `users`, `user_studio_roles`, `rooms`, `courses`, `lessons`, `plans`, `user_plans`, `bookings`, `waitlist`

Tipi di corso: `group`, `personal`  
Tipi di piano: `credits`, `unlimited`, `trial`  
Stati booking: `booked`, `cancelled`, `attended`, `no_show`

RLS abilitato su tutte le tabelle. Ogni studio vede solo i propri dati.

Colonne aggiuntive su `public.users`:
- `avatar_url text` — URL in Supabase Storage (bucket `avatars`, pubblico)
- `instagram_url text`
- `bio text`
- `specializations text[]`

## Routing

```
/login
/u/:userId                        ← profilo pubblico (bypass auth redirect)

/admin/dashboard
/admin/studios
/admin/users

/owner/dashboard
/owner/courses                    ← lista corsi
/owner/courses/:courseId          ← dettaglio corso + prossime lezioni
/owner/rooms                      ← CRUD sale
/owner/team                       ← lista trainer + aggiungi
/owner/clients                    ← lista clienti + aggiungi
/owner/clients/:clientId          ← dettaglio cliente (piano + prenotazioni)
/owner/plans
/owner/report
/owner/profile

/staff/calendar                   ← calendario lezioni del trainer
/staff/roster/:lessonId           ← presenze lezione (mark attended/no_show)
/staff/courses
/staff/schedule
/staff/profile

/client/calendar
/client/bookings
/client/profile
```

## Schermate implementate

### Owner
- **OwnerDashboardScreen** — wizard onboarding a 4 step (sala → trainer → corso → piano), scompare quando completo
- **RoomsScreen** — lista sale con popup modifica/elimina, bottom sheet add/edit (nome + capacità)
- **CoursesScreen** — lista con tipo e responsabile, bottom sheet nuovo corso (nome, tipo, class_owner dropdown, ore disdetta, descrizione)
- **CourseDetailScreen** — header charcoal con tipo, chip info, descrizione, prossime lezioni con date-block lime
- **TeamScreen** — lista trainer/class_owner, bottom sheet aggiungi via Edge Function
- **ClientsScreen** — lista con stato piano (warning arancio se crediti ≤ 2 o scadenza entro 7 gg), bottom sheet aggiungi
- **ClientDetailScreen** — header con iniziale, sezione contatti, card piano attivo, lista prenotazioni recenti con status

### Staff
- **StaffCalendarScreen** — TableCalendar brand-styled, lista lezioni del giorno, pulsante "Presenze" naviga a `/staff/roster/:lessonId`
- **RosterScreen** — header lezione (data/ora + badge "X/Y presenti"), lista iscritti con row colorata (verde/rosso/bianco), bottoni ✓/✗/↩ per segnare presenze, aggiornamento Supabase live

### Client / Shared
- **CalendarScreen** — TableCalendar con dot marker per giorni con lezioni
- **ProfileScreen** — role-aware: staff (editabile, foto, bio, Instagram, specializzazioni) / client (piano attivo, prossime prenotazioni)
- **PublicProfileScreen** — SliverAppBar espandibile, bio, specializzazioni chip

## Creazione utenti (Edge Function)

```
POST supabase/functions/admin-create-user
Body: { full_name, email, password, role, studio_id, phone? }
role: 'trainer' | 'class_owner' | 'client'
```
Verifica che il chiamante sia owner dello studio, crea utente auth + profilo + ruolo.  
`class_owner` riceve automaticamente anche il ruolo `trainer`.

## Icona app

Generata con script Dart puro (`tool/generate_icon/`):
- Sfondo charcoal `#1A1A1A`
- Testo "3F" lime `#C5D800`
- Bordo arrotondato lime
- Adaptive icon Android: sfondo charcoal + foreground trasparente con "3F"

```bash
# Rigenera PNG
cd tool/generate_icon
dart run bin/generate_icon.dart

# Reinstalla icone su Android/iOS
cd ../..
dart run flutter_launcher_icons
```

## Comandi utili

```bash
flutter pub get                    # dipendenze
flutter run                        # lancia app
flutter analyze                    # lint (deve dare 0 issues)
flutter build apk                  # build Android
dart run flutter_launcher_icons    # rigenera icone launcher

# Seed database
node scripts/mock.mjs

# Genera icona
cd tool/generate_icon && dart run bin/generate_icon.dart
```

## Dipendenze principali

```yaml
supabase_flutter: ^2.0.0
flutter_riverpod: ^3.3.1
go_router: ^14.6.0
table_calendar: ^3.1.2
intl: ^0.19.0
image_picker: ^1.1.2
cached_network_image: ^3.4.1

dev:
  flutter_launcher_icons: ^0.14.3
```

## Note implementative

- **UTC timestamps**: tutte le query Supabase usano `.toUtc().toIso8601String()` — senza `.toUtc()` il filtro per giorno non funziona
- **Creazione utenti**: usare sempre la Edge Function, mai `supabase.auth.signUp()` (sovrascrive la sessione dell'owner)
- **Widget pubblici vs privati**: i widget da importare cross-file non devono avere il prefisso `_` (es. `UserAvatar`, `SpecChip`, `InstagramChip` in profile_screen.dart)
- **Lint `unnecessary_underscores`**: usare `(context, i)` invece di `(_, __)` nei builder
- **`maybeSingle()` non richiede cast**: restituisce già `Map<String, dynamic>?`, non fare `as Map<String, dynamic>?`
- **`DropdownButtonFormField`**: usare `initialValue:` invece del deprecato `value:`
- **npm bloccato su Windows**: usare script Dart al posto di Node.js (vedi `tool/generate_icon/`)
