# shellcheck shell=bash
# modules/30-fail2ban.sh : fail2ban bannit les robots qui essaient d'entrer par SSH. Ticket P1-04.
#
# À FAIRE (P1-04) : efface cette ligne quand le module est écrit.
# Ce module doit :
#   1. installer fail2ban (paquets fail2ban) ;
#   2. poser fichiers/fail2ban/serveur-durci.local dans /etc/fail2ban/jail.d/ (mode 644), après
#      avoir remplacé @JAMAIS_BANNIES@ par les adresses de config.env : rendre FICHIER donne le
#      fichier prêt. Le test : fail2ban-client -t ;
#   3. s'assurer que fail2ban tourne et démarre au boot (service_actif fail2ban) ;
#   4. si quelque chose a changé, lui faire relire sa configuration (recharger fail2ban).
# Les outils : lib/commun.sh.
etape "fail2ban"
info "pas encore écrit (ticket P1-04)"
