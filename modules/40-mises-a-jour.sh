# shellcheck shell=bash
# modules/40-mises-a-jour.sh : les mises à jour de sécurité s'installent seules. Ticket P1-05.
#
# Pour apt, c'est le DERNIER fichier lu qui gagne : 52serveur-durci passe après
# 20auto-upgrades et 50unattended-upgrades, les fichiers du paquet.
etape "Mises à jour automatiques"
paquets unattended-upgrades
poser_teste fichiers/apt/52serveur-durci /etc/apt/apt.conf.d/52serveur-durci 644 apt-config dump
service_actif apt-daily.timer
service_actif apt-daily-upgrade.timer
if [ -f /var/run/reboot-required ]; then
	attention "une mise à jour attend un redémarrage : choisis ton moment, puis sudo reboot (docs/runbook.md)"
fi
