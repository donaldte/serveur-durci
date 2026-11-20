# shellcheck shell=bash
# Accès GitHub Actions limité au déploiement d'un commit.

etape "Déploiement continu"
publique=fichiers/deploiement/github-actions.pub

if [ ! -s "$publique" ]; then
    info "Pas de clé publique GitHub Actions configurée."
    return 0
fi

ssh-keygen -lf "$publique" > /dev/null ||
    erreur "Clé publique GitHub Actions invalide."

read -r type cle commentaire < "$publique"
[ "$type" = ssh-ed25519 ] ||
    erreur "Une clé publique ssh-ed25519 est attendue."

if ! id deploy > /dev/null 2>&1; then
    faire "compte deploy créé" useradd -m -s /bin/bash deploy
fi

poser_teste fichiers/deploiement/sudoers \
    /etc/sudoers.d/serveur-durci \
    440 visudo -c

dossier_ssh=/home/deploy/.ssh
cles_autorisees=$dossier_ssh/authorized_keys

if [ ! -d "$dossier_ssh" ] ||
    [ "$(stat -c '%a %U %G' "$dossier_ssh")" != "700 deploy deploy" ]; then
    faire "permissions du dossier SSH de deploy" \
        install -d -m 700 -o deploy -g deploy "$dossier_ssh"
fi

nouveau="$TMP/authorized_keys"
: > "$nouveau"

# Conserver les autres clés et remplacer une éventuelle ancienne
# déclaration de cette même clé par sa version bridée.
if [ -f "$cles_autorisees" ]; then
    awk -v type="$type" -v cle="$cle" '
        {
            correspond = 0
            for (i = 1; i < NF; i++) {
                if ($i == type && $(i + 1) == cle) {
                    correspond = 1
                }
            }
            if (!correspond) {
                print
            }
        }
    ' "$cles_autorisees" > "$nouveau"
fi

printf '%s %s %s %s\n' \
    'restrict,command="sudo -n /usr/local/sbin/serveur-durci-deployer \"$SSH_ORIGINAL_COMMAND\""' \
    "$type" "$cle" "$commentaire" >> "$nouveau"

poser "$nouveau" "$cles_autorisees" 600 deploy
