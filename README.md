# atelier-dns

Script de préparation du cours « Le DNS » (BTS SIO SISR, 1re année).
`preparer.sh` met la machine virtuelle Ubuntu en état pour les manipulations
du cours.

## Utilisation (étudiant)

Dans la VM, en début d'activité :

```bash
cd ~
git clone https://github.com/manastria/atelier-dns.git
cd atelier-dns
bash preparer.sh
```

Le script demande lui-même le mot de passe d'administrateur (pas de `sudo`
à taper). Il peut être relancé sans risque. Il se termine par
`VM prête pour le cours « Le DNS ».`

Pour annuler le réglage du résolveur :

```bash
bash preparer.sh --remettre
```

## Ce que fait le script

1. **Installe `whois`** (partie 6 du cours) s'il manque. Nécessite un accès
   à Internet.
2. **Règle `ReadEtcHosts=no`** dans `/etc/systemd/resolved.conf.d/10-atelier-dns.conf`,
   puis redémarre `systemd-resolved`.
3. **Vérifie** que le système lit toujours `/etc/hosts` (comme `ping` et
   Firefox) alors que le résolveur local ne le lit plus (comme `nslookup`
   et `dig`).

## Pourquoi `ReadEtcHosts=no`

Sur Ubuntu, le résolveur local (`systemd-resolved`, adresse `127.0.0.53`) lit
lui-même `/etc/hosts` et en répond aux questions DNS, avec un délai de
quelques secondes. Une ligne ajoutée au fichier hosts finit donc par être
« trouvée » par `nslookup` et `dig`, alors que le cours veut montrer que le
fichier hosts n'est pas le DNS. Avec le réglage, `nslookup` répond `NXDOMAIN`
tout de suite, et `ping` continue de trouver le nom.

Testé sur Ubuntu 26.04 (systemd 259), 25 novembre 2026 :

| Quelques secondes après l'ajout de la ligne | `ping` | `nslookup` | `dig` |
|---|---|---|---|
| réglage par défaut | trouve | `NXDOMAIN`, puis trouve après quelques secondes | `NXDOMAIN` |
| `ReadEtcHosts=no` | trouve | `NXDOMAIN`, toujours | `NXDOMAIN`, toujours |
