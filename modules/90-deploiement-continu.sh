# shellcheck shell=bash
# modules/90-deploiement-continu.sh : chaque push sur main se déploie tout seul. Défi P1-10.
#
# GitHub Actions entre sur le serveur avec sa propre clé, sous le compte deploy (celui du TP 4).
# Cette clé ne peut lancer qu'une commande : serveur-durci-deployer, avec le commit que la CI
# vient de tester. Sa partie publique est dans le dépôt, sa partie privée est un secret GitHub.
etape "Déploiement continu"
CLE_CI=fichiers/deploiement/github-actions.pub
if [ ! -s "$CLE_CI" ]; then
	info "pas de clé dans $CLE_CI : le déploiement continu n'est pas activé (défi P1-10)"
	return 0
fi
grep -Eqx 'ssh-ed25519 [A-Za-z0-9+/=]+( [^ ]+)?' "$CLE_CI" ||
	erreur "$CLE_CI doit tenir sur une ligne : ssh-ed25519 AAAA… commentaire (la partie PUBLIQUE)"

# 1. Le compte deploy : ni mot de passe, ni sudo général.
if ! getent passwd deploy > /dev/null; then
	faire "compte deploy créé" useradd -m -s /bin/bash deploy
fi

# 2. Ce que deploy peut lancer en root : le déploiement d'un commit, rien d'autre.
poser_teste fichiers/deploiement/sudoers /etc/sudoers.d/serveur-durci 440 visudo -c

# 3. La clé de GitHub Actions dans authorized_keys, bridée. Les autres clés de deploy
#    (celle de la CI du TP 4) restent.
cle=$(head -n1 "$CLE_CI")
blob=$(cut -d' ' -f2 <<< "$cle")
# Les guillemets simples sont voulus : c'est le shell de deploy qui remplacera $SSH_ORIGINAL_COMMAND.
# shellcheck disable=SC2016
bride='restrict,command="sudo -n /usr/local/sbin/serveur-durci-deployer \"$SSH_ORIGINAL_COMMAND\""'
autorisees=/home/deploy/.ssh/authorized_keys
{
	[ ! -f "$autorisees" ] || grep -vF "$blob" "$autorisees" || true
	printf '%s %s\n' "$bride" "$cle"
} > "$TMP/authorized_keys"
if [ ! -d /home/deploy/.ssh ]; then
	faire "dossier /home/deploy/.ssh" install -d -m 700 -o deploy -g deploy /home/deploy/.ssh
fi
poser "$TMP/authorized_keys" "$autorisees" 600 deploy

# 4. sshd doit laisser entrer deploy.
if sshd -T 2> /dev/null | grep -Eqi '^(allowusers|allowgroups) '; then
	sshd -T -C user=deploy,host=github.com,addr=192.0.2.10 2> /dev/null | grep -Eqi '^allowusers .*\bdeploy\b' ||
		attention "sshd n'accepte que certains comptes (AllowUsers, AllowGroups) : vérifie que deploy en fait partie (sudo sshd -T | grep -i allow)"
fi
