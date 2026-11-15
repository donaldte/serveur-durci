#!/usr/bin/env bash
# deployer.sh : met ce serveur dans l'état que décrit ce dépôt. Se relance sans risque.
#
#   sudo ./deployer.sh              applique ce qui manque, module par module (dossier modules/)
#   sudo ./deployer.sh --essai      montre ce qui changerait, sans rien changer
#   sudo ./deployer.sh --confirmer  après la première activation du pare-feu : le garde actif
#
# Pour déployer la dernière version poussée sur GitHub : sudo serveur-durci-deployer
set -Eeuo pipefail
export LC_ALL=C.UTF-8 PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
cd "$(dirname "$(readlink -f "$0")")"
# shellcheck source=lib/commun.sh
source lib/commun.sh

case "${1:-}" in
"") ;;
--essai) ESSAI=1 ;;
--confirmer)
	confirmer_pare_feu
	exit 0
	;;
*)
	sed -n '2,8p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
[ "$(id -u)" -eq 0 ] || erreur "à lancer avec sudo : sudo $0"

charger_config
verrouiller
debut
trap terminer EXIT
trap 'echec "$LINENO" "$BASH_COMMAND"' ERR

for module in modules/[0-9][0-9]-*.sh; do
	# shellcheck source=/dev/null
	source "$module"
done
