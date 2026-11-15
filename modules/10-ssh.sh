# shellcheck shell=bash
# modules/10-ssh.sh : SSH par clé seulement, sans rien d'inutile. Ticket P1-06.
#
# À FAIRE (P1-06) : efface cette ligne quand le module est écrit.
# Ce module doit :
#   1. poser fichiers/ssh/10-serveur-durci.conf dans /etc/ssh/sshd_config.d/ (mode 644), testé
#      par « sshd -t » : poser_teste SOURCE DESTINATION MODE COMMANDE_DE_TEST. Si le test échoue,
#      l'ancien fichier est remis et ta session ne coupe pas ;
#   2. si quelque chose a changé (module_a_change), faire relire sa configuration à ssh
#      (recharger ssh).
# sshd -t a besoin du dossier /run/sshd : [ -d /run/sshd ] || install -d -m 755 /run/sshd
# Les outils : lib/commun.sh. Un module complet pour t'inspirer : modules/50-site.sh.
etape "SSH"
info "pas encore écrit (ticket P1-06)"
