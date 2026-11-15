<!-- À COMPLÉTER : remplace partout TON-PRENOM par ton prénom et TON-COMPTE par ton compte GitHub, puis efface cette ligne. -->
# serveur-durci · TON-PRENOM

[![CI](https://github.com/TON-COMPTE/serveur-durci/actions/workflows/ci.yml/badge.svg)](https://github.com/TON-COMPTE/serveur-durci/actions/workflows/ci.yml)

Mon serveur de production, décrit en code : un Ubuntu 24.04 durci et automatisé, qui sert
**https://TON-PRENOM.formationdevops.xyz**. Une commande le remet dans l'état décrit ici, autant
de fois qu'on veut : le deuxième passage dit « Rien à changer ».

Projet 1 de la formation DevOps Runbookly, fait à partir du modèle du formateur.

## Ce que fait chaque module

| Module | Ce qu'il règle |
|---|---|
| `00-base` | les outils du déploiement, et la commande `serveur-durci-deployer` |
| `10-ssh` | SSH par clé seulement, root jamais par mot de passe, 30 secondes pour s'authentifier, pas de X11 |
| `20-pare-feu` | ufw : 22, 80 et 443 ouverts, tout le reste fermé ; un filet de 5 minutes à la première activation |
| `30-fail2ban` | 5 échecs SSH en 10 minutes : banni 1 heure, deux fois plus longtemps à chaque récidive |
| `40-mises-a-jour` | les mises à jour de sécurité s'installent seules, chaque jour ; pas de redémarrage automatique |
| `50-site` | nginx en reverse proxy devant la boutique, HTTPS Let's Encrypt, HTTP vers HTTPS, en-têtes de sécurité |
| `90-deploiement-continu` | chaque push sur `main`, une fois testé par la CI, se déploie tout seul |

## Comment ça marche

```text
mon ordinateur ── git push ──▶ GitHub ──▶ la CI : ShellCheck, secrets, configurations
                                   │
                                   ▼  (main, tests verts)
le serveur : serveur-durci-deployer ◀── la CI, avec la clé bridée de deploy (ou moi, en SSH)
             └─ git fetch, puis ./deployer.sh : chaque module applique ce qui manque
```

Le serveur ne se modifie jamais à la main : on modifie le dépôt, on pousse, on déploie.
Ce qui est propre au serveur et ne doit pas aller sur GitHub (mon e-mail, mon adresse) est dans
`config.env`, qui reste sur le serveur (`.gitignore`).

## Déployer

La première fois, sur le serveur :

```bash
sudo git clone https://github.com/TON-COMPTE/serveur-durci.git /opt/serveur-durci
cd /opt/serveur-durci
sudo cp config.env.exemple config.env
sudo nano config.env
sudo ./deployer.sh
```

Le pare-feu s'active avec un filet : il se coupe tout seul dans 5 minutes. Ouvre une deuxième
session SSH ; si elle marche, `sudo ./deployer.sh --confirmer`.

Ensuite : modifier le dépôt, pousser sur `main`, puis sur le serveur

```bash
sudo serveur-durci-deployer     # prend main sur GitHub, et déploie
```

Avec le déploiement continu, la CI le fait toute seule après chaque push.

## Vérifier

```bash
sudo ./deployer.sh --essai              # « Rien ne changerait » : le serveur est comme le dépôt
sudo ./tests/configurations.sh          # les configurations, testées sans toucher au serveur
sudo tail -n 20 /var/log/serveur-durci.log
```

## En cas de problème

[docs/runbook.md](docs/runbook.md) : enfermé dehors, banni par fail2ban, déploiement arrêté,
site en panne, certificat, redémarrage, CI rouge.

## Mes choix

[docs/decisions.md](docs/decisions.md) : pourquoi chaque réglage.

## Licence

MIT : voir [LICENSE](LICENSE).
