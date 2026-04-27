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
