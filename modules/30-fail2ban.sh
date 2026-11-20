# shellcheck shell=bash
# Protection des connexions SSH par fail2ban.

etape "fail2ban"
paquets fail2ban

configuration=$(rendre fichiers/fail2ban/serveur-durci.local)
poser_teste "$configuration" \
    /etc/fail2ban/jail.d/serveur-durci.local \
    644 fail2ban-client -t

service_actif fail2ban

if module_a_change; then
    recharger fail2ban
fi
