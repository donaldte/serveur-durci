# shellcheck shell=bash
# Configuration SSH du serveur, testée avant rechargement.

etape "SSH"

if [ ! -d /run/sshd ]; then
    faire "dossier /run/sshd" install -d -m 755 /run/sshd
fi

poser_teste fichiers/ssh/10-serveur-durci.conf \
    /etc/ssh/sshd_config.d/10-serveur-durci.conf \
    644 sshd -t

if module_a_change; then
    recharger ssh
fi
