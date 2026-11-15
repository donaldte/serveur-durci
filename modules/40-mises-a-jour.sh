# shellcheck shell=bash
# modules/40-mises-a-jour.sh : les mises à jour de sécurité s'installent seules. Ticket P1-05.
#
# À FAIRE (P1-05) : efface cette ligne quand le module est écrit.
# Ce module doit :
#   1. installer unattended-upgrades (paquets unattended-upgrades) ;
#   2. poser fichiers/apt/52serveur-durci dans /etc/apt/apt.conf.d/ (mode 644), testé par
#      « apt-config dump » (il échoue si le fichier est mal écrit) ;
#   3. s'assurer que les deux minuteurs d'apt tournent : apt-daily.timer (la liste des paquets)
#      et apt-daily-upgrade.timer (l'installation) ;
#   4. prévenir si une mise à jour attend un redémarrage : le fichier /var/run/reboot-required
#      existe alors (attention "…").
# Les outils : lib/commun.sh.
etape "Mises à jour automatiques"
info "pas encore écrit (ticket P1-05)"
