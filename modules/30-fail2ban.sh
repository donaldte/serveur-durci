# shellcheck shell=bash
# modules/30-fail2ban.sh : fail2ban bannit les robots qui essaient d'entrer par SSH. Ticket P1-04.
#
# Les réglages sont dans fichiers/fail2ban/serveur-durci.local ; @JAMAIS_BANNIES@ y est
# remplacé par les adresses de config.env (elles ne vont pas sur GitHub).
etape "fail2ban"
paquets fail2ban
poser_teste "$(rendre fichiers/fail2ban/serveur-durci.local)" /etc/fail2ban/jail.d/serveur-durci.local 644 fail2ban-client -t
service_actif fail2ban
if module_a_change; then
	recharger fail2ban
fi
