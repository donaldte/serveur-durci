# Mes choix, et pourquoi

Une décision par section : ce qu'on a choisi, ce qu'on a écarté, et la raison. Quand un choix
change, on le note ici avant de changer le code.

## Le serveur ne change que par GitHub

**Choix** : le dépôt décrit le serveur. On modifie le dépôt, on pousse, on déploie ; jamais de
modification à la main sur le serveur (`serveur-durci-deployer` refuse de déployer si
`/opt/serveur-durci` a été modifié).

**Pourquoi** : un serveur modifié à la main ne se reconstruit pas. Avec le dépôt, on sait ce qui
tourne, depuis quand, et qui l'a changé (l'historique Git), et on reconstruit un serveur neuf en
une commande.

## Un déploiement se relance sans risque

**Choix** : chaque module vérifie avant d'agir, et ne change que ce qui manque. Deux
déploiements de suite : le deuxième dit « Rien à changer ».

**Pourquoi** : on peut relancer après une panne, ou toutes les heures, sans rien casser. Et
`--essai` montre l'écart entre le serveur et le dépôt.

## Une configuration est testée avant d'être relue

**Choix** : `sshd -t`, `nginx -t`, `fail2ban-client -t`, `apt-config dump`, `visudo -c` avant de
recharger. Si le test échoue, l'ancien fichier est remis. La CI fait les mêmes tests à chaque push.

**Pourquoi** : une configuration SSH cassée, c'est un serveur où plus personne n'entre au prochain
redémarrage. Une configuration sudo cassée, c'est plus de sudo du tout.

## Le pare-feu : ufw, trois ports, et un filet

**Choix** : ufw, tout ce qui entre est refusé, sauf 22 (SSH), 80 (HTTP et les renouvellements
Let's Encrypt) et 443 (HTTPS). Toute autre règle est retirée. La première activation arme un
minuteur qui coupe ufw dans 5 minutes, sauf confirmation depuis une deuxième session.

**Écarté** : ouvrir le 22 à une seule adresse (`ufw allow from <mon IP>`) : nos adresses de
maison changent, et le formateur doit pouvoir entrer. En entreprise, on passe par un bastion ou
un VPN.

**Pourquoi le filet** : la seule erreur de pare-feu qu'on ne répare pas soi-même, c'est celle qui
nous enferme dehors.

## fail2ban : mes réglages

À COMPLÉTER : tes chiffres (maxretry, findtime, bantime), ce que tu as écarté, et pourquoi.
Pense à ce qui arrive sur Internet à un port 22 ouvert, et à ce qui t'arrive si tu te trompes
de clé cinq fois de suite.

## Le redémarrage après une mise à jour

À COMPLÉTER : ton choix pour Unattended-Upgrade::Automatic-Reboot (fichiers/apt/52serveur-durci),
ce que tu as écarté, et pourquoi. Une mise à jour du noyau ne sert qu'après un redémarrage ;
un redémarrage, c'est ton site coupé une minute.

## SSH : ce qu'on change, et ce qu'on ne change pas

**Choix** : clés seulement, root jamais par mot de passe (`prohibit-password`), 30 secondes pour
s'authentifier, pas de X11.

**Écarté** : `PermitRootLogin no`, parce que certaines machines du labo sont administrées par
root avec une clé : `no` les fermerait. `MaxAuthTries 3`, parce qu'un client qui propose plusieurs
clés peut épuiser ses essais avant la bonne : fail2ban s'occupe des robots.

## Les secrets ne vont pas sur GitHub

**Choix** : `config.env` (e-mail, adresses à ne jamais bannir) reste sur le serveur
(`.gitignore`). La clé privée de déploiement est un secret GitHub, jamais un fichier du dépôt.
`tests/secrets.sh` le vérifie à chaque push.

**Pourquoi** : le dépôt est public, et un secret poussé une fois reste dans l'historique.

## Le déploiement continu : une clé qui ne fait qu'une chose

**Choix** : GitHub Actions entre sous le compte `deploy` avec sa propre clé, bridée dans
`authorized_keys` (`restrict,command=…`) : elle ne peut lancer que `serveur-durci-deployer`, et sudo
n'accepte qu'un commit en argument. La CI déploie le commit qu'elle vient de tester, pas « le
dernier ». Elle vérifie la clé du serveur (`HOTE_CONNU`) : jamais `StrictHostKeyChecking=no`.

**Le risque qu'on accepte** : qui peut pousser sur `main` devient root sur le serveur. On protège
donc `main` (Settings → Branches) et son compte GitHub (double authentification).
