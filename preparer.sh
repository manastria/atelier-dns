#!/bin/bash
# Préparation de la VM pour le cours « Le DNS » (BTS SIO SISR, 1re année).
#
#   bash preparer.sh             prépare la VM (peut être relancé sans risque)
#   bash preparer.sh --remettre  annule le réglage du résolveur
#
# Deux choses sont faites :
#   1. installer `whois` (partie 6) s'il manque ;
#   2. dire au résolveur local de ne plus lire /etc/hosts (ReadEtcHosts=no).
#
# Pourquoi le point 2 : sur Ubuntu, le résolveur local (systemd-resolved, adresse
# 127.0.0.53) lit lui-même /etc/hosts et en répond aux questions DNS, avec un
# délai de quelques secondes. `nslookup` et `dig` finissent alors par « trouver »
# un nom qui n'est que dans le fichier hosts, ce qui brouille la partie 2 :
# le fichier hosts n'est pas le DNS. Avec ce réglage, ils répondent NXDOMAIN
# tout de suite ; `ping` et Firefox lisent toujours le fichier hosts, car ce
# sont les programmes qui le consultent avant de poser la question au DNS.

CONF_DIR=/etc/systemd/resolved.conf.d
CONF=$CONF_DIR/10-atelier-dns.conf

# Les droits d'administrateur sont demandés ici, pas à l'étudiant.
if [ "$(id -u)" -ne 0 ]; then
    exec sudo bash "$0" "$@"
fi

attendre_resolveur() {
    # Après un redémarrage de systemd-resolved, NetworkManager lui redonne
    # le serveur DNS du labo : on attend qu'il soit de retour.
    for _ in $(seq 1 15); do
        if resolvectl dns 2>/dev/null | grep -q '^Link .*: [0-9a-f]'; then
            return 0
        fi
        sleep 1
    done
    return 1
}

if [ "${1:-}" = "--remettre" ]; then
    rm -f "$CONF"
    systemctl restart systemd-resolved
    attendre_resolveur || echo "Attention : le serveur DNS n'est pas revenu, redémarrer la VM."
    echo "Réglage annulé : le résolveur relit /etc/hosts (comportement d'origine)."
    exit 0
fi

echo "1/3 Installation de whois"
if command -v whois >/dev/null 2>&1; then
    echo "    déjà installé"
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq && apt-get install -y -qq whois >/dev/null 2>&1 \
        && echo "    installé" \
        || { echo "ÉCHEC : whois n'a pas pu être installé (accès à Internet ? proxy ?)"; exit 1; }
fi

echo "2/3 Le résolveur local ne lit plus /etc/hosts"
mkdir -p "$CONF_DIR"
printf '[Resolve]\nReadEtcHosts=no\n' > "$CONF"
systemctl restart systemd-resolved
if attendre_resolveur; then
    echo "    résolveur redémarré, serveur DNS du labo revenu"
else
    echo "ÉCHEC : le serveur DNS n'est pas revenu après le redémarrage du résolveur."
    echo "        Redémarrer la VM, puis relancer ce script."
    exit 1
fi

echo "3/3 Vérification"
nom=verif-atelier-dns.invalid
echo "127.0.0.1   $nom" >> /etc/hosts
lu_par_systeme=$(getent hosts "$nom" >/dev/null 2>&1 && echo oui || echo non)
lu_par_resolveur=$(dig +short @127.0.0.53 "$nom" 2>/dev/null)
sed -i "/$nom/d" /etc/hosts
if [ "$lu_par_systeme" = oui ] && [ -z "$lu_par_resolveur" ]; then
    echo "    OK : le système lit /etc/hosts, le résolveur local ne le lit pas."
else
    echo "ÉCHEC : comportement inattendu (système : $lu_par_systeme, résolveur : '${lu_par_resolveur:-vide}')."
    exit 1
fi
echo
echo "VM prête pour le cours « Le DNS »."
