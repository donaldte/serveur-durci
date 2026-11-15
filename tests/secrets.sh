#!/usr/bin/env bash
# tests/secrets.sh : rien de secret dans le dépôt. Lancé par la CI à chaque push.
# Un dépôt public se lit par tout le monde, pour toujours : une clé privée poussée une seule
# fois est à changer, même effacée ensuite (elle reste dans l'historique).
set -euo pipefail
cd "$(dirname "$(readlink -f "$0")")/.."
probleme=0
if git ls-files --error-unmatch config.env > /dev/null 2>&1; then
	echo "✗ config.env est dans le dépôt : il ne doit rester que sur le serveur (git rm --cached config.env)"
	probleme=1
fi
motif='-----BEGIN ([A-Z0-9]+ )?PRIVATE KEY-----'
if git grep -lE -e "$motif" -- . ':!tests/secrets.sh' > /dev/null; then
	echo "✗ une clé privée est dans le dépôt :"
	git grep -lE -e "$motif" -- . ':!tests/secrets.sh' | sed 's/^/    /'
	probleme=1
fi
if [ "$probleme" = 0 ]; then
	echo "✓ pas de secret dans le dépôt"
fi
exit "$probleme"
