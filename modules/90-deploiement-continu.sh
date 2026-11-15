# shellcheck shell=bash
# modules/90-deploiement-continu.sh : chaque push sur main se déploie tout seul. Défi P1-10.
#
# À FAIRE (P1-10, le défi) : efface cette ligne quand le module est écrit.
# GitHub Actions entrera sur ton serveur sous le compte deploy (celui du TP 4), avec sa propre
# clé, qui ne pourra lancer qu'une commande : serveur-durci-deployer <commit>. Ce module doit :
#   1. ne rien faire s'il n'y a pas de clé dans fichiers/deploiement/github-actions.pub
#      (return 0 sort du module) ;
#   2. créer le compte deploy s'il n'existe pas, sans mot de passe (useradd -m -s /bin/bash) ;
#   3. poser fichiers/deploiement/sudoers dans /etc/sudoers.d/serveur-durci (mode 440), testé par
#      « visudo -c » : un sudoers cassé, c'est plus de sudo du tout ;
#   4. mettre la clé dans /home/deploy/.ssh/authorized_keys, bridée, sur une seule ligne :
#        restrict,command="sudo -n /usr/local/sbin/serveur-durci-deployer \"$SSH_ORIGINAL_COMMAND\"" ssh-ed25519 AAAA…
#      sans effacer les autres clés de deploy (celle du TP 4) ; .ssh en 700, le fichier en 600,
#      le tout à deploy (poser SOURCE DESTINATION 600 deploy).
# Le reste se règle sur GitHub : le ticket P1-10 (less /opt/mboa/TICKETS-PROJET1).
etape "Déploiement continu"
info "pas encore écrit (défi P1-10)"
