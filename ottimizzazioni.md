# Ottimizzazioni

## 2026-04-27 — CalendarScreen: riduzione query al caricamento

### Problema
Al primo render di `CalendarScreen` (prima schermata dopo il login) venivano
eseguite 9 round-trip HTTP verso Supabase in parallelo, di cui molte ridondanti.

### Fix 1 — Query duplicate su `user_plans` (3 → 1)

**File:** `lib/core/providers/user_plans_provider.dart` (nuovo)
`lib/features/booking/providers/booking_provider.dart`

`hasActivePlanProvider`, `hasTrialCreditsProvider` e `hasTrialTimePlanProvider`
eseguivano la stessa identica query su `user_plans`. Centralizzata in un unico
`userPlansProvider` (senza `autoDispose` → cache per tutta la sessione). I tre
provider derivano ora da `ref.watch(userPlansProvider.future)` senza toccare
il database.

**Risparmio:** 2 round-trip eliminati ad ogni apertura della schermata.

### Fix 2 — Invalidazioni corrette dopo scala-crediti

**File:** `lib/features/booking/providers/booking_provider.dart`

`cancelTrialWithDeduction` invalidava `hasTrialCreditsProvider` (il derivato),
lasciando `userPlansProvider` con dati stale. `cancelWithCreditDeduction` non
invalidava i piani affatto. Corretti entrambi per invalidare `userPlansProvider`,
così i tre provider derivati si aggiornano in cascata.

### Fix 3 — `userEnrolledCourseIdsProvider` senza query aggiuntiva

**File:** `lib/features/booking/providers/user_plans_provider.dart`
`lib/features/booking/providers/booking_provider.dart`

Il provider scaricava tutto lo storico prenotazioni (`bookings`) per estrarne i
`course_id` unici — potenzialmente centinaia di righe per un cliente attivo da
anni. Riscritto per derivare da `userPlansProvider` (già in memoria): i corsi
coperti sono quelli con `course_id != null` nei piani attivi.

Aggiunto `course_id` alla select di `userPlansProvider`.

**Risparmio:** 1 round-trip eliminato. Zero query aggiuntive per l'enrollment.

**Bonus:** corretto un bug preesistente — un cliente con piano corso-specifico
non vedeva il pulsante "Prenota" prima della prima lezione (l'enrollment era
derivato dalla storia prenotazioni, non dai piani).

---

## 2026-04-27 — LoginScreen: animazione tastiera e startup

### Fix 1 — Animazione tastiera lenta su LoginScreen

**File:** `lib/features/auth/screens/login_screen.dart`

`IntrinsicHeight` forzava un doppio passaggio di layout ad ogni frame
dell'animazione della tastiera (uno per misurare, uno per posizionare),
causando jank visibile all'apertura dei campi di testo.

Rimossi `LayoutBuilder` + `SingleChildScrollView(reverse: true)` +
`ConstrainedBox` + `IntrinsicHeight`. Sostituiti con:
- `Scaffold(resizeToAvoidBottomInset: false)`
- `Padding(bottom: MediaQuery.of(context).viewInsets.bottom)` attorno alla
  form card — segue la tastiera frame per frame con un singolo layout pass
- `ClipRect` su `_BrandSection` per gestire senza overflow i dispositivi
  piccoli (iPhone SE) dove tastiera + form consumano quasi tutta l'altezza

**Risparmio:** da 2 layout pass per frame → 1 durante l'animazione tastiera.

### Fix 2 — Init sequenziale in `main()`

**File:** `lib/main.dart`

`initializeDateFormatting('it_IT')` e `Supabase.initialize()` venivano
eseguiti in sequenza pur essendo indipendenti. Sostituiti con `Future.wait`.

**Risparmio:** ~50–150ms al cold start (si paga il più lento, non la somma).

### Fix 3 — Sentry sample rates

**File:** `lib/main.dart`

`tracesSampleRate: 1.0` e `profilesSampleRate: 1.0` instrumentavano il 100%
delle operazioni HTTP/DB aggiungendo overhead misurabile a runtime.
Abbassati a `tracesSampleRate: 0.2` e `profilesSampleRate: 0.1`.

### Fix 4 — Auth flash al cold start

**File:** `lib/core/router/app_router.dart`

`authStateProvider` parte da `AsyncLoading`: il redirect valutava
`isLoggedIn = false` e navigava a `/login` per un frame, poi redirectava
alla home per chi era già loggato — flash visibile.

Aggiunto `if (authAsync.isLoading) return null` come prima istruzione del
redirect. Cambiato `initialLocation` da `/client/calendar` a `/login`,
così durante il loading l'utente resta sulla login screen (sfondo charcoal
uniforme) e la navigazione avviene solo dopo il primo evento auth.
