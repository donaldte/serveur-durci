# Runbook : quand quelque chose casse

Chaque fiche : ce qu'on voit, la première commande, puis la réparation. On garde son calme et
une session ouverte : tant qu'une session SSH est ouverte, on peut réparer.

## Je ne peux plus entrer en SSH

**Ce qu'on voit** : `ssh labo` attend, puis `Connection timed out` (un pare-feu qui jette), ou
`Connection refused` (fail2ban, qui rejette).

1. **Juste après une activation du pare-feu ?** Ne touche à rien : le filet coupe ufw dans
   5 minutes (jusqu'à 6). Réessaie ensuite, puis cherche pourquoi le 22 n'était pas ouvert
   (`sudo ufw show added`).
2. **Banni par fail2ban ?** `Connection refused` depuis chez toi, mais ça marche depuis un autre
   réseau (le partage de connexion du téléphone). fail2ban coupe aussi les sessions déjà ouvertes
   depuis ton adresse. Depuis la session qui marche :
   ```bash
   sudo fail2ban-client status sshd                  # la liste des adresses bannies
   sudo fail2ban-client set sshd unbanip <ton IP>    # te débannir
   ```
   Puis ajoute ton adresse à `JAMAIS_BANNIES` dans `config.env`, et redéploie.
3. **Personne n'entre plus ?** Demande au formateur (sa clé passe par le même port 22). En
   dernier recours : la console de l'hébergeur (OVH : KVM ; Contabo : VNC), ou son mode rescue.

## Le déploiement s'arrête

**Ce qu'on voit** : `✗ arrêt : … a échoué (modules/…, ligne …)`, ou `✗ … refusé par …`.

```bash
sudo tail -n 30 /var/log/serveur-durci.log    # ce qui s'est passé, dans l'ordre
sudo ./deployer.sh --essai                    # ce qui reste à faire, sans rien changer
```

- Un fichier **refusé par son test** (`sshd -t`, `nginx -t`, `fail2ban-client -t`, `visudo -c`) :
  l'ancien a été remis, le service tourne toujours. Corrige le fichier dans le dépôt, pousse,
  redéploie. Tu peux le tester avant de pousser : `sudo ./tests/configurations.sh`.
- `le dépôt du serveur a été modifié à la main` : quelqu'un a changé `/opt/serveur-durci`.
  Refais la modification dans ton dépôt, puis `sudo git -C /opt/serveur-durci checkout -- .`.
- `un autre déploiement tourne déjà` : la CI déploie peut-être en ce moment. Attends une minute.

## Le site ne répond plus

```bash
curl -sI https://<nom>.formationdevops.xyz/ | head -3
sudo nginx -t
sudo systemctl status nginx --no-pager
sudo journalctl -u nginx -n 20 --no-pager
sudo systemctl status mboa-boutique --no-pager    # 502 Bad Gateway : l'application derrière
```

## Le certificat

Let's Encrypt donne des certificats de 90 jours ; certbot les renouvelle tout seul, deux fois par jour
s'il le faut, par le port 80 (d'où la règle 80/tcp, et le dossier `/var/www/letsencrypt`).

```bash
sudo certbot certificates                       # la date d'expiration
systemctl list-timers | grep certbot            # le renouvellement automatique
sudo certbot renew --dry-run                    # un renouvellement pour de faux
```

## Une mise à jour attend un redémarrage

Le déploiement le dit (`une mise à jour attend un redémarrage`), et le fichier
`/var/run/reboot-required` existe. On choisit un moment calme, puis :

```bash
cat /var/run/reboot-required.pkgs     # les paquets qui le demandent (souvent le noyau)
sudo reboot
```

Après : `ssh labo`, le site répond, `sudo ./deployer.sh --essai` dit « Rien ne changerait ».

## La CI est rouge

Ouvre l'onglet **Actions** du dépôt, clique sur la croix rouge, puis sur l'étape en échec.

- **ShellCheck** : chaque erreur a un code (`SC2086`…). Sa page explique l'erreur et la
  correction : `https://www.shellcheck.net/wiki/SC2086`.
- **Configurations** : le message du programme qui refuse le fichier (`sshd`, `nginx`, `fail2ban`…).
  Le même test, sur le serveur : `sudo ./tests/configurations.sh`.
- **Pas de secret** : un fichier secret a été poussé. Retire-le (`git rm --cached`), pousse, et
  change le secret : il reste dans l'historique de GitHub.
