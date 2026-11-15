# shellcheck shell=bash
# modules/20-pare-feu.sh : le pare-feu (ufw). Ce qui n'est pas ouvert ici est fermé. Ticket P1-03.
etape "Pare-feu (ufw)"
paquets ufw
if ! command -v ufw > /dev/null; then
	info "(essai) ufw n'est pas encore installé : la suite se verra au vrai déploiement"
	return 0
fi

# Les seuls ports ouverts sur Internet. Le 22 d'abord : c'est par lui que tu entres.
PORTS=(22/tcp 80/tcp 443/tcp)

# 1. Le garde-fou : jamais de pare-feu sans SSH.
case " ${PORTS[*]} " in
*" 22/tcp "*) ;;
*) erreur "22/tcp n'est pas dans PORTS : tu t'enfermerais dehors" ;;
esac

# 2. Par défaut, ce qui entre est refusé et ce qui sort est permis.
if ! grep -q '^DEFAULT_INPUT_POLICY="DROP"' /etc/default/ufw; then
	faire "ufw : ce qui entre est refusé par défaut" ufw default deny incoming
fi
if ! grep -q '^DEFAULT_OUTPUT_POLICY="ACCEPT"' /etc/default/ufw; then
	faire "ufw : ce qui sort est permis par défaut" ufw default allow outgoing
fi

# 3. Les règles de PORTS, et aucune autre : le dépôt décrit le serveur.
#    On ouvre d'abord, on retire ensuite : le 22 ne se ferme jamais, même un instant.
mapfile -t regles < <(ufw show added | sed -n 's/^ufw //p')
voulues=()
for port in "${PORTS[@]}"; do
	voulues+=("allow $port")
	if ! printf '%s\n' "${regles[@]}" | grep -qxF "allow $port"; then
		faire "ufw : $port ouvert" ufw allow "$port"
	fi
done
for regle in "${regles[@]}"; do
	printf '%s\n' "${voulues[@]}" | grep -qxF "$regle" && continue
	read -ra mots <<< "$regle"
	faire "ufw : règle retirée (ufw $regle)" ufw delete "${mots[@]}"
done

# 4. Actif. La première fois, avec le filet, et seulement si tu es là pour confirmer.
if ! ufw status | grep -q '^Status: active'; then
	if [ ! -t 0 ]; then
		attention "le pare-feu n'est pas actif : la première fois, active-le toi-même, dans ta session SSH (sudo $DEPOT/deployer.sh)"
	else
		activer_pare_feu
	fi
elif filet_arme; then
	demander_confirmation
fi
