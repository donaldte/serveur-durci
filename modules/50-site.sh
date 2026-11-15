# shellcheck shell=bash
# modules/50-site.sh : ton site en HTTPS, derrière nginx. Complet : ton travail est dans
# fichiers/nginx/site.conf (ticket P1-07).
#
# Pas encore de certificat ? Le site passe d'abord en HTTP seulement (fichiers/nginx/defi-http.conf),
# le temps que Let's Encrypt vérifie que le nom est à toi, puis le vrai site est posé.
# nginx -t teste chaque version avant qu'nginx la relise : si elle est fausse, l'ancienne revient.
etape "Le site : https://$FQDN"
MODELE=fichiers/nginx/site.conf
SITE=/etc/nginx/sites-available/serveur-durci
LIEN=/etc/nginx/sites-enabled/serveur-durci
DEFIS=/var/www/letsencrypt
CERTIFICAT=/etc/letsencrypt/live/$FQDN/fullchain.pem

if grep -q 'À FAIRE' "$MODELE"; then
	info "$MODELE dit encore « À FAIRE » (ticket P1-07) : le site n'est pas touché"
	return 0
fi
paquets nginx certbot
[ -d "$DEFIS" ] || faire "dossier des défis de Let's Encrypt : $DEFIS" install -d -m 755 "$DEFIS"

# poser_site MODELE : pose le site, l'active et le teste ; s'il est faux, l'état d'avant revient.
poser_site() {
	local rendu
	rendu=$(rendre "$1")
	if [ -L "$LIEN" ]; then
		poser_teste "$rendu" "$SITE" 644 nginx -t
		return 0
	fi
	poser "$rendu" "$SITE" 644
	faire "site serveur-durci activé" ln -s "$SITE" "$LIEN"
	if [ "$ESSAI" = 0 ] && ! nginx -t > "$TMP/nginx" 2>&1; then
		rm -f "$LIEN"
		erreur "nginx refuse le site : $(grep -m1 -E 'emerg|error' "$TMP/nginx")"
	fi
}

# 1. Le certificat, s'il n'y en a pas encore.
if [ ! -s "$CERTIFICAT" ]; then
	[ -n "$EMAIL" ] || erreur "pas de certificat pour $FQDN : mets ton EMAIL dans config.env, Let's Encrypt en a besoin"
	poser_site fichiers/nginx/defi-http.conf
	service_actif nginx
	if module_a_change; then
		recharger nginx
	fi
	faire "certificat Let's Encrypt pour $FQDN" certbot certonly --webroot -w "$DEFIS" -d "$FQDN" \
		-m "$EMAIL" --agree-tos --no-eff-email --non-interactive
fi

# 2. Le vrai site.
poser_site "$MODELE"

# 3. Un seul site pour ce nom : les autres (celui du TP 5, par exemple) sont désactivés.
#    Leur fichier reste dans sites-available.
for autre in /etc/nginx/sites-enabled/*; do
	[ "$autre" = "$LIEN" ] && continue
	[ -e "$autre" ] || [ -L "$autre" ] || continue
	if grep -Eq "^[[:space:]]*server_name[^;]*[[:space:]]$FQDN([[:space:];]|\$)" "$autre" 2> /dev/null; then
		if [ -L "$autre" ]; then
			faire "site $(basename "$autre") désactivé : $FQDN est servi par serveur-durci" rm -f "$autre"
		else
			faire "site $(basename "$autre") désactivé (gardé dans sites-available)" \
				mv "$autre" "/etc/nginx/sites-available/$(basename "$autre").avant-serveur-durci"
		fi
	fi
done

service_actif nginx
if module_a_change; then
	recharger nginx
fi
