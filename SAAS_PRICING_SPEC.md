# Évolution du modèle économique CRM SaaS

## Principe fondamental

Le SaaS ne facture pas uniquement les communications.

Le SaaS facture principalement :

* la prospection assistée ;
* l'organisation commerciale ;
* le suivi des agents ;
* l'automatisation du workflow ;
* la transformation des contacts en opportunités ;
* le pilotage des performances commerciales.

Ainsi, même lorsqu'un appel ou un message est exécuté depuis le téléphone de l'utilisateur, l'action consomme une ressource métier du CRM.

---

# Quotas d'essai à l'inscription

Chaque nouvelle entreprise bénéficie automatiquement d'un crédit de découverte.

## Crédits inclus

### Appels manuels

250 appels

Définition :

* clic sur Appeler
* saisie du verdict
* passage au prospect suivant

Chaque cycle consomme 1 crédit.

---

### SMS manuels

250 SMS

Définition :

* ouverture du SMS depuis une fiche prospect
* validation de l'envoi

Chaque action consomme 1 crédit.

---

### WhatsApp manuel

100 messages

Définition :

* ouverture WhatsApp depuis un prospect
* envoi d'un message

Chaque action consomme 1 crédit.

---

# UX des compteurs

Dans le tableau de bord entreprise afficher :

* Appels restants
* SMS restants
* WhatsApp restants

Exemple :

Appels : 135 / 250

SMS : 97 / 250

WhatsApp : 42 / 100

Afficher une jauge visuelle.

---

# Alertes automatiques

À 80 %

Afficher :

"Vous avez utilisé 80 % de vos crédits."

---

À 90 %

Afficher :

"Vos crédits seront bientôt épuisés."

---

À 100 %

Bloquer les actions concernées.

---

# Blocage intelligent

Lorsqu'un agent tente :

* d'appeler
* d'envoyer un SMS
* d'envoyer un WhatsApp

alors que le quota est épuisé :

Afficher :

"Les crédits de prospection de votre entreprise sont épuisés. Contactez votre administrateur."

---

# Notification administrateur

À chaque seuil critique :

* 80 %
* 90 %
* 100 %

Envoyer :

* notification SaaS
* email

à l'administrateur de l'entreprise.

---

# Importation de prospects depuis un fichier

## Objectif

Permettre aux entreprises d'échanger facilement des prospects.

---

# Export CRM

Le CRM doit permettre :

Exporter des prospects dans un exel ou pdf

---

# Structure du fichier

Le fichier doit contenir :

* prénom
* nom
* téléphone
* email
* entreprise
* statut
* notes
* date de création


# Import CRM natif

Lorsqu'un fichier CRM propriétaire est importé :

Le système doit :

* reconnaître automatiquement le format
* extraire les données
* afficher un aperçu
* proposer l'importation


# Import CSV universel

Le système doit également accepter :

* CSV
* XLSX

---

# Détection automatique des colonnes

Reconnaître automatiquement :

* Nom
* Prénom
* Téléphone
* Email

Même si les colonnes portent des noms différents.

---

# Conversion en prospects

Après import :

Afficher :

Nombre de contacts détectés.

Puis permettre :

* Importer comme prospects
* Attribuer à un agent
* Répartir automatiquement entre plusieurs agents

---

# Répartition automatique

Exemple :

500 prospects

5 agents

Résultat :

100 prospects par agent

Répartition équitable.

---

# Campagnes groupées

Fonctionnalités premium.

---

## Emails groupés

Permettre :

* sélection multiple
* campagnes
* modèles
* programmation

---

## SMS groupés

Permettre :

* envoi massif
* segmentation

---

## WhatsApp groupés

Permettre :

* campagnes WhatsApp
* modèles

---

# Nouveaux abonnements

## STARTER

2500 FCFA / mois

* 800 prospects
* 3 agents
* 600 emails groupés
* 200 SMS groupés
* 150 WhatsApp groupés
* 600 appels manuels
* 600 SMS manuels
* 400 WhatsApp manuels

---

## PRO

5000 FCFA / mois

* 5000 prospects
* 10 agents
* 3000 emails groupés
* 400 SMS groupés
* 600 WhatsApp groupés
* 3500 appels manuels
* 3500 SMS manuels
* 1800 WhatsApp manuels

---

## BUSINESS

10000 FCFA / mois

* 20000 prospects
* 50 agents
* 10000 emails groupés
* 1000 SMS groupés
* 2000 WhatsApp groupés
* 10000 appels manuels
* 10000 SMS manuels
* 5000 WhatsApp manuels
* appels IA

---

# Objectif UX

L'utilisateur ne doit jamais découvrir brutalement qu'il n'a plus de crédits.

Le système doit :

* prévenir
* afficher les quotas partout
* notifier l'administrateur
* proposer un upgrade en un clic

afin d'augmenter le taux de conversion vers les abonnements payants.

Onglets mes abonnement dans paramètre de l'entreprise., possibilté d'annuler un abonnement et d'activer un autre. '

