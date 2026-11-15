#!/usr/bin/env bash
# tests/configurations.sh : teste les fichiers de configuration du dépôt, sans toucher au serveur.
#
# Lancé par la CI (GitHub Actions) à chaque push, et sur ton serveur : sudo ./tests/configurations.sh
# Chaque fichier est testé par le programme qui le lira (sshd, fail2ban, apt, nginx, visudo),
# dans un dossier temporaire, avec un nom d'essai. Un fichier qui dit encore « À FAIRE » est passé.
set -euo pipefail
export LC_ALL=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd "$(dirname "$(readlink -f "$0")")/.."
[ "$(id -u)" -eq 0 ] || {
	echo "à lancer en root : sudo $0" >&2
	exit 1
}
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
FQDN=essai.example.org
echecs=0

ok() { printf '  ✓ %s\n' "$*"; }
passe() { printf '  · %s\n' "$*"; }
ko() {
	printf '  ✗ %s\n' "$1"
	[ -z "${2:-}" ] || sed 's/^/      /' "$2" | head -n 8
	echecs=$((echecs + 1))
}
pas_encore() { grep -q 'À FAIRE' "$1"; }
rendre() {
	sed -e "s|@NOM@|essai|g" -e "s|@DOMAINE@|example.org|g" -e "s|@FQDN@|$FQDN|g" \
		-e "s|@JAMAIS_BANNIES@|192.0.2.1|g" "$1"
}

# SSH : sshd lit le fichier, et il ne laisse pas entrer par mot de passe.
f=fichiers/ssh/10-serveur-durci.conf
if pas_encore "$f"; then
	passe "$f : pas encore écrit"
else
	ssh-keygen -q -t ed25519 -N '' -f "$tmp/cle-hote"
	{
		cat "$f"
		echo "HostKey $tmp/cle-hote"
	} > "$tmp/sshd_config"
	mkdir -p /run/sshd
	if ! sshd -t -f "$tmp/sshd_config" 2> "$tmp/sortie"; then
		ko "$f : sshd le refuse" "$tmp/sortie"
	elif ! sshd -T -f "$tmp/sshd_config" 2> /dev/null | grep -qx 'passwordauthentication no'; then
		ko "$f : il laisse encore entrer par mot de passe (PasswordAuthentication)"
	else
		ok "$f"
	fi
fi

# fail2ban : la configuration complète, avec notre fichier, passe le test de fail2ban.
f=fichiers/fail2ban/serveur-durci.local
if pas_encore "$f"; then
	passe "$f : pas encore écrit"
else
	cp -a /etc/fail2ban "$tmp/fail2ban"
	rendre "$f" > "$tmp/fail2ban/jail.d/serveur-durci.local"
	if fail2ban-client -c "$tmp/fail2ban" -t > "$tmp/sortie" 2>&1; then
		ok "$f"
	else
		ko "$f : fail2ban le refuse" "$tmp/sortie"
	fi
fi

# apt : le fichier se lit, et il demande bien les mises à jour automatiques.
f=fichiers/apt/52serveur-durci
if pas_encore "$f"; then
	passe "$f : pas encore écrit"
elif ! apt-config -c "$f" dump > "$tmp/apt" 2> "$tmp/sortie"; then
	ko "$f : apt ne sait pas le lire" "$tmp/sortie"
elif ! grep -qx 'APT::Periodic::Unattended-Upgrade "1";' "$tmp/apt"; then
	ko "$f : il ne demande pas APT::Periodic::Unattended-Upgrade \"1\""
else
	ok "$f"
fi

# nginx : chaque site, avec un certificat d'essai, dans une copie de /etc/nginx.
cp -a /etc/nginx "$tmp/nginx"
rm -f "$tmp/nginx/sites-enabled/"*
sed -i "s|/etc/nginx/|$tmp/nginx/|g" "$tmp/nginx/nginx.conf"
mkdir -p "$tmp/le/live/$FQDN"
openssl req -x509 -newkey rsa:2048 -nodes -days 1 -subj "/CN=$FQDN" \
	-keyout "$tmp/le/live/$FQDN/privkey.pem" -out "$tmp/le/live/$FQDN/fullchain.pem" 2> /dev/null
# Les fichiers que certbot ajoute (« # managed by Certbot ») : ceux du serveur s'il les a, sinon des équivalents.
if [ -f /etc/letsencrypt/options-ssl-nginx.conf ]; then
	cp /etc/letsencrypt/options-ssl-nginx.conf "$tmp/le/"
else
	printf 'ssl_session_cache shared:le_nginx_SSL:10m;\nssl_session_timeout 1440m;\nssl_protocols TLSv1.2 TLSv1.3;\n' > "$tmp/le/options-ssl-nginx.conf"
fi
if [ -f /etc/letsencrypt/ssl-dhparams.pem ]; then
	cp /etc/letsencrypt/ssl-dhparams.pem "$tmp/le/"
else
	openssl dhparam -dsaparam -out "$tmp/le/ssl-dhparams.pem" 2048 2> /dev/null
fi
# Une machine sans IPv6 (certains conteneurs) : les lignes « listen [::]… » sont testées sans.
sans_ipv6=""
if [ ! -e /proc/net/if_inet6 ]; then
	sans_ipv6='/^[[:space:]]*listen[[:space:]]*\[::\]/d'
	passe "pas d'IPv6 sur cette machine : nginx est testé sans les lignes listen [::]"
fi
for f in fichiers/nginx/defi-http.conf fichiers/nginx/site.conf; do
	if pas_encore "$f"; then
		passe "$f : pas encore écrit"
		continue
	fi
	rm -f "$tmp/nginx/sites-enabled/"*
	rendre "$f" | sed -e "s|/etc/letsencrypt/|$tmp/le/|g" -e "$sans_ipv6" > "$tmp/nginx/sites-enabled/site"
	if nginx -t -c "$tmp/nginx/nginx.conf" > "$tmp/sortie" 2>&1; then
		ok "$f"
	else
		ko "$f : nginx le refuse" "$tmp/sortie"
	fi
done

# sudoers (défi P1-10) : visudo le lit.
f=fichiers/deploiement/sudoers
if [ ! -f "$f" ] || pas_encore "$f"; then
	passe "$f : pas encore écrit"
elif visudo -cf "$f" > "$tmp/sortie" 2>&1; then
	ok "$f"
else
	ko "$f : visudo le refuse" "$tmp/sortie"
fi

if [ "$echecs" -gt 0 ]; then
	printf '\n%s fichier(s) refusé(s) : corrige-les avant de déployer.\n' "$echecs"
	exit 1
fi
printf '\nToutes les configurations écrites passent.\n'
