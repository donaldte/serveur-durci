# shellcheck shell=bash
# Installation quotidienne des mises à jour automatiques.

etape "Mises à jour automatiques"
paquets unattended-upgrades

poser_teste fichiers/apt/52serveur-durci \
    /etc/apt/apt.conf.d/52serveur-durci \
    644 apt-config dump

service_actif apt-daily.timer
service_actif apt-daily-upgrade.timer

if [ -f /var/run/reboot-required ]; then
    attention "Un redémarrage est nécessaire après une mise à jour. Planifie-le pour vérifier le retour des services."
fi
