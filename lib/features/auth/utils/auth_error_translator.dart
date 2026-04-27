String translateAuthError(String msg) {
  final m = msg.toLowerCase();
  if (m.contains('invalid login') || m.contains('invalid credentials')) {
    return 'Email o password non corretti.';
  }
  if (m.contains('email not confirmed')) {
    return 'Email non confermata. Controlla la casella di posta.';
  }
  if (m.contains('too many requests')) {
    return 'Troppi tentativi. Riprova tra qualche minuto.';
  }
  if (m.contains('network') || m.contains('connection')) {
    return 'Errore di connessione. Controlla la rete.';
  }
  return msg;
}
