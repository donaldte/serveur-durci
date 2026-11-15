# shellcheck shell=bash
# modules/00-base.sh : les outils du déploiement. Complet : rien à écrire ici.
etape "Base"
paquets git curl ca-certificates
poser outils/serveur-durci-deployer /usr/local/sbin/serveur-durci-deployer 755
