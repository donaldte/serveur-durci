# shellcheck shell=bash
# Pare-feu du serveur, chargé par deployer.sh.

etape "Pare-feu (ufw)"
paquets ufw python3

if ! grep -q '^DEFAULT_INPUT_POLICY="DROP"$' /etc/default/ufw; then
    faire "ufw : connexions entrantes refusées par défaut" \
        ufw default deny incoming
fi

if ! grep -q '^DEFAULT_OUTPUT_POLICY="ACCEPT"$' /etc/default/ufw; then
    faire "ufw : connexions sortantes autorisées" \
        ufw default allow outgoing
fi

regles=""
if command -v ufw > /dev/null; then
    regles=$(LC_ALL=C ufw show added)
fi

for port in 22 80 443; do
    if ! grep -Fxq "ufw allow $port/tcp" <<< "$regles"; then
        faire "ufw : $port/tcp ouvert" ufw allow "$port/tcp"
    fi
done

# shlex restitue les arguments, y compris les noms de profils avec espaces.
supprimer_regle_ufw() {
    python3 - "$1" <<'PY'
import shlex
import subprocess
import sys

arguments = shlex.split(sys.argv[1])
if not arguments or arguments[0] != "ufw":
    raise SystemExit("Règle UFW invalide")
subprocess.run(
    ["/usr/sbin/ufw", "--force", "delete", *arguments[1:]],
    check=True,
)
PY
}

while IFS= read -r regle; do
    case "$regle" in
        "ufw allow 22/tcp"|"ufw allow 80/tcp"|"ufw allow 443/tcp")
            ;;
        ufw\ *)
            faire "ufw : retrait de $regle" supprimer_regle_ufw "$regle"
            ;;
    esac
done <<< "$regles"

if command -v ufw > /dev/null &&
    LC_ALL=C ufw status | grep -q '^Status: active'; then
    if filet_arme; then
        demander_confirmation
    fi
elif [ -t 0 ]; then
    activer_pare_feu
else
    attention "ufw inactif : lance le déploiement depuis un terminal pour confirmer son activation."
fi
