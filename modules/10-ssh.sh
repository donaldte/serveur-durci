# shellcheck shell=bash
# modules/10-ssh.sh : SSH par clé seulement, sans rien d'inutile. Ticket P1-06.
#
# Pour sshd, la PREMIÈRE valeur lue gagne : notre fichier s'appelle 10-… pour passer avant
# 50-cloud-init.conf. « sshd -t » teste la configuration avant qu'ssh la relise : si elle est
# fausse, l'ancien fichier est remis (poser_teste). Ta session en cours ne coupe pas.
etape "SSH"
[ -d /run/sshd ] || install -d -m 755 /run/sshd
poser_teste fichiers/ssh/10-serveur-durci.conf /etc/ssh/sshd_config.d/10-serveur-durci.conf 644 sshd -t
if module_a_change; then
	recharger ssh
fi
