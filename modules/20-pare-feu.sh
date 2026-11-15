# shellcheck shell=bash
# modules/20-pare-feu.sh : le pare-feu (ufw). Ce qui n'est pas ouvert ici est fermé. Ticket P1-03.
#
# À FAIRE (P1-03) : efface cette ligne quand le module est écrit.
# Ce module doit, dans l'ordre :
#   1. installer ufw (paquets ufw) ;
#   2. refuser par défaut ce qui entre (ufw default deny incoming) et permettre ce qui sort
#      (ufw default allow outgoing) : /etc/default/ufw dit ce qui est réglé ;
#   3. ouvrir 22/tcp, 80/tcp et 443/tcp, et retirer toute autre règle : « ufw show added »
#      donne les règles actuelles, une par ligne (ufw allow 22/tcp). Ouvre d'abord, retire
#      ensuite : le 22 ne doit jamais se fermer, même un instant ;
#   4. si ufw n'est pas actif (ufw status), l'activer avec activer_pare_feu (le filet de
#      5 minutes), mais seulement si tu es là pour confirmer, donc dans un terminal : [ -t 0 ].
#      Sinon (la CI qui déploie), un message : attention "…".
# Chaque changement passe par « faire » : il est compté, et le deuxième déploiement dit
# « Rien à changer ». Exemple : faire "ufw : 80/tcp ouvert" ufw allow 80/tcp
# Les outils : lib/commun.sh.
etape "Pare-feu (ufw)"
info "pas encore écrit (ticket P1-03)"
