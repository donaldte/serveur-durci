# shellcheck shell=bash
# lib/commun.sh : les outils des modules. Chargé par deployer.sh, jamais lancé seul.
#
# Tout changement passe par « faire » : il est compté, écrit au journal, et seulement montré
# en mode essai (sudo ./deployer.sh --essai). Deux déploiements de suite : le deuxième doit
# finir par « Rien à changer ». C'est ça, un déploiement idempotent.
#
#   etape "titre"                    le début d'un module
#   faire "ce qui change" commande…  applique un changement (compté, au journal)
#   paquets nom…                     installe les paquets qui manquent
#   poser SOURCE DEST [MODE] [COMPTE]
#                                    copie un fichier du dépôt sur le serveur, s'il est différent
#   poser_teste SOURCE DEST MODE commande…
#                                    pareil, puis lance la commande de test ; si elle échoue,
#                                    l'ancien fichier est remis et le déploiement s'arrête
#   rendre MODELE                    remplace @NOM@, @DOMAINE@, @FQDN@ et @JAMAIS_BANNIES@,
#                                    et donne le chemin du fichier obtenu
#   service_actif NOM                le service tourne, et démarre au boot
#   recharger NOM                    le service relit sa configuration
#   activer_pare_feu                 active ufw avec le filet (il se coupe seul dans 5 minutes
#                                    si tu ne confirmes pas : sudo ./deployer.sh --confirmer)
#   filet_arme                       vrai si le filet attend encore ta confirmation
#   module_a_change                  vrai si le module en cours a changé quelque chose
#   info, attention, erreur          les messages (erreur arrête le déploiement)

JOURNAL=/var/log/serveur-durci.log
ETAT=/var/lib/serveur-durci
FILET=serveur-durci-filet
DEPOT=$(pwd)
ESSAI=0
CHANGEMENTS=0
CHANGEMENTS_MODULE=0
A_CONFIRMER=0
COMMIT=inconnu
TMP=""

if [ -t 1 ]; then
	GRAS=$'\033[1m' VERT=$'\033[32m' JAUNE=$'\033[33m' ROUGE=$'\033[31m' GRIS=$'\033[2m' FIN=$'\033[0m'
else
	GRAS="" VERT="" JAUNE="" ROUGE="" GRIS="" FIN=""
fi

maintenant() { date '+%Y-%m-%dT%H:%M:%S%z'; }

journal() {
	[ "$ESSAI" = 1 ] && return 0
	printf '%s %s\n' "$(maintenant)" "$*" >> "$JOURNAL"
}

etape() {
	CHANGEMENTS_MODULE=0
	printf '\n%s== %s%s\n' "$GRAS" "$*" "$FIN"
}

info() { printf '   %s\n' "$*"; }

attention() {
	printf '   %s! %s%s\n' "$JAUNE" "$*" "$FIN"
	journal "! $*"
}

erreur() {
	printf '   %s✗ %s%s\n' "$ROUGE" "$*" "$FIN" >&2
	journal "✗ $*"
	exit 1
}

faire() {
	local quoi="$1"
	shift
	CHANGEMENTS=$((CHANGEMENTS + 1))
	CHANGEMENTS_MODULE=$((CHANGEMENTS_MODULE + 1))
	if [ "$ESSAI" = 1 ]; then
		printf '   %s~ (essai) %s%s\n' "$JAUNE" "$quoi" "$FIN"
		return 0
	fi
	printf '   %s~%s %s\n' "$JAUNE" "$FIN" "$quoi"
	journal "~ $quoi"
	# Ce que la commande affiche va au journal ; ses erreurs restent à l'écran.
	if ! "$@" >> "$JOURNAL"; then
		erreur "échec : $quoi (la commande : $*)"
	fi
}

module_a_change() { [ "$CHANGEMENTS_MODULE" -gt 0 ]; }

paquets() {
	local paquet manquants=()
	for paquet in "$@"; do
		dpkg -s "$paquet" 2> /dev/null | grep -q '^Status: install ok installed' || manquants+=("$paquet")
	done
	[ "${#manquants[@]}" -eq 0 ] && return 0
	faire "paquets installés : ${manquants[*]}" installer_paquets "${manquants[@]}"
}

installer_paquets() {
	apt-get -o DPkg::Lock::Timeout=300 update -qq
	DEBIAN_FRONTEND=noninteractive apt-get -o DPkg::Lock::Timeout=300 install -y -qq "$@"
}

# identique SOURCE DEST MODE COMPTE : le fichier du serveur est-il déjà celui du dépôt ?
identique() {
	[ -f "$2" ] && cmp -s "$1" "$2" && [ "$(stat -c '%a %U' "$2")" = "$3 $4" ]
}

poser() {
	local source="$1" destination="$2" mode="${3:-644}" compte="${4:-root}"
	[ -f "$source" ] || erreur "introuvable dans le dépôt : $source"
	identique "$source" "$destination" "$mode" "$compte" && return 0
	faire "$destination" install -D -m "$mode" -o "$compte" -g "$compte" "$source" "$destination"
}

poser_teste() {
	local source="$1" destination="$2" mode="$3" ancien=""
	shift 3
	[ -f "$source" ] || erreur "introuvable dans le dépôt : $source"
	identique "$source" "$destination" "$mode" root && return 0
	if [ "$ESSAI" = 1 ]; then
		faire "$destination" true
		return 0
	fi
	if [ -f "$destination" ]; then
		ancien="$TMP/ancien.$$"
		cp -p "$destination" "$ancien"
	fi
	faire "$destination" install -D -m "$mode" "$source" "$destination"
	if ! "$@" > "$TMP/test" 2>&1; then
		if [ -n "$ancien" ]; then
			cp -p "$ancien" "$destination"
		else
			rm -f "$destination"
		fi
		journal "test refusé : $* : $(tr '\n' ' ' < "$TMP/test")"
		erreur "$destination refusé par « $* » : l'ancien est remis. $(grep -m1 -iE 'error|erreur|emerg|invalid|bad|unknown|syntax' "$TMP/test" || head -n1 "$TMP/test")"
	fi
	[ -z "$ancien" ] || rm -f "$ancien"
}

rendre() {
	local sortie
	sortie=$(mktemp "$TMP/rendu.XXXXXX")
	sed -e "s|@NOM@|$NOM|g" -e "s|@DOMAINE@|$DOMAINE|g" -e "s|@FQDN@|$FQDN|g" \
		-e "s|@JAMAIS_BANNIES@|$JAMAIS_BANNIES|g" "$1" > "$sortie"
	printf '%s\n' "$sortie"
}

service_actif() {
	systemctl is-enabled --quiet "$1" 2> /dev/null || faire "$1 : démarre au boot" systemctl enable --quiet "$1"
	systemctl is-active --quiet "$1" || faire "$1 : démarré" systemctl start "$1"
}

recharger() {
	faire "$1 : configuration relue" systemctl reload-or-restart "$1"
}

# Le filet du pare-feu : un minuteur qui coupe ufw tout seul, si personne ne confirme.
filet_armer() {
	systemctl stop "$FILET.timer" > /dev/null 2>&1 || true
	systemctl reset-failed "$FILET.timer" "$FILET.service" > /dev/null 2>&1 || true
	systemd-run --quiet --collect --unit="$FILET" --on-active="$1" /usr/sbin/ufw disable
}
filet_arme() { systemctl is-active --quiet "$FILET.timer"; }
filet_desarmer() { systemctl stop "$FILET.timer" > /dev/null 2>&1 || true; }

# activer_pare_feu : active ufw avec le filet, et demande ta confirmation à la fin du déploiement.
activer_pare_feu() {
	faire "filet armé : ufw se coupera tout seul dans 5 minutes, sauf si tu confirmes" filet_armer 5min
	faire "ufw activé" ufw --force enable
	demander_confirmation
}
demander_confirmation() { A_CONFIRMER=1; }

charger_config() {
	NOM=$(hostname -s)
	DOMAINE=formationdevops.xyz
	EMAIL=""
	JAMAIS_BANNIES=""
	if [ -f "$DEPOT/config.env" ]; then
		# shellcheck source=/dev/null
		source "$DEPOT/config.env"
	else
		attention "pas de config.env : sudo cp config.env.exemple config.env, puis remplis-le (ticket P1-01)"
	fi
	FQDN="$NOM.$DOMAINE"
	[[ "$FQDN" =~ ^[a-z0-9]([a-z0-9-]*[a-z0-9])?(\.[a-z0-9]([a-z0-9-]*[a-z0-9])?)+$ ]] ||
		erreur "nom de serveur invalide : $FQDN (NOM et DOMAINE dans config.env)"
	[[ -z "$EMAIL" || "$EMAIL" =~ ^[^[:space:]@|]+@[^[:space:]@|]+\.[A-Za-z]{2,}$ ]] ||
		erreur "EMAIL invalide dans config.env : $EMAIL"
	local adresses adresse
	read -ra adresses <<< "$JAMAIS_BANNIES"
	for adresse in "${adresses[@]}"; do
		[[ "$adresse" =~ ^[0-9A-Fa-f.:/]+$ ]] || erreur "adresse invalide dans JAMAIS_BANNIES (config.env) : $adresse"
	done
}

verrouiller() {
	exec 9> /run/serveur-durci.lock
	flock -n 9 || erreur "un autre déploiement tourne déjà"
}

debut() {
	TMP=$(mktemp -d)
	[ "$ESSAI" = 1 ] || install -d -m 755 "$ETAT"
	COMMIT=$(git -C "$DEPOT" rev-parse HEAD 2> /dev/null || echo inconnu)
	journal "début mode=normal commit=$COMMIT par=${SUDO_USER:-root}"
	if [ "$ESSAI" = 1 ]; then
		printf '%sEssai sur %s%s : ce qui changerait, sans rien changer %s(commit %.7s)%s\n' \
			"$GRAS" "$FQDN" "$FIN" "$GRIS" "$COMMIT" "$FIN"
	else
		printf '%sDéploiement de %s%s %s(commit %.7s, par %s)%s\n' \
			"$GRAS" "$FQDN" "$FIN" "$GRIS" "$COMMIT" "${SUDO_USER:-root}" "$FIN"
	fi
}

# echec LIGNE COMMANDE : une commande d'un module a échoué. On dit laquelle, et où.
echec() {
	[ -z "${ECHEC_VU:-}" ] || return 0
	ECHEC_VU=1
	local i ou="deployer.sh, ligne $1"
	for i in "${!BASH_SOURCE[@]}"; do
		[ "$i" -gt 0 ] || continue
		case "${BASH_SOURCE[$i]}" in
		modules/*)
			ou="${BASH_SOURCE[$i]}, ligne ${BASH_LINENO[$((i - 1))]}"
			break
			;;
		esac
	done
	printf '   %s✗ arrêt : « %s » a échoué (%s)%s\n' "$ROUGE" "$2" "$ou" "$FIN" >&2
	journal "✗ « $2 » a échoué ($ou)"
}

terminer() {
	local code=$?
	trap - ERR
	[ -z "$TMP" ] || rm -rf "$TMP"
	journal "fin mode=normal code=$code changements=$CHANGEMENTS commit=$COMMIT"
	printf '\n'
	if [ "$code" -ne 0 ]; then
		printf "%s✗ Le déploiement s'est arrêté (code %s).%s Lis le message au-dessus. Le journal : sudo tail -n 30 %s\n" \
			"$ROUGE" "$code" "$FIN" "$JOURNAL"
		return 0
	fi
	if [ "$ESSAI" = 1 ]; then
		if [ "$CHANGEMENTS" -eq 0 ]; then
			printf '%s✓ Rien ne changerait :%s le serveur est déjà comme le dit le dépôt.\n' "$VERT" "$FIN"
		else
			printf '%s~ %s changement(s) à faire.%s Pour les appliquer : sudo ./deployer.sh\n' "$JAUNE" "$CHANGEMENTS" "$FIN"
		fi
	elif [ "$CHANGEMENTS" -eq 0 ]; then
		printf '%s✓ Rien à changer :%s le serveur est déjà comme le dit le dépôt.\n' "$VERT" "$FIN"
	else
		printf '%s✓ Fait : %s changement(s).%s Relance-le : le deuxième passage doit dire « Rien à changer ».\n' \
			"$VERT" "$CHANGEMENTS" "$FIN"
	fi
	if [ "$A_CONFIRMER" = 1 ]; then
		cat << EOF

${JAUNE}${GRAS}Le pare-feu est actif, et le filet est armé : il le coupera tout seul dans 5 minutes.${FIN}
  1. Garde cette session ouverte.
  2. Ouvre un NOUVEAU terminal et connecte-toi : ssh labo
  3. Ça marche ? Dans le nouveau terminal : ${GRAS}sudo $DEPOT/deployer.sh --confirmer${FIN}
     Ça ne marche pas ? Ne touche à rien : dans 5 minutes, le pare-feu se coupe tout seul.
EOF
	fi
}

confirmer_pare_feu() {
	[ "$(id -u)" -eq 0 ] || erreur "à lancer avec sudo : sudo $DEPOT/deployer.sh --confirmer"
	if ! ufw status 2> /dev/null | grep -q '^Status: active'; then
		erreur "le pare-feu n'est pas actif (le filet l'a peut-être déjà coupé) : relance sudo $DEPOT/deployer.sh"
	fi
	filet_desarmer
	install -d -m 755 "$ETAT"
	maintenant > "$ETAT/pare-feu-confirme"
	journal "pare-feu confirmé par ${SUDO_USER:-root}"
	printf '%s✓ Filet désarmé :%s le pare-feu reste actif.\n' "$VERT" "$FIN"
}
