# Audit Pre-Production - G-CRM

Date: 2026-06-24  
Projet: `G-CRM` (Flutter + Firebase + Node services)  
Objectif: Evaluer l'aptitude production sur securite, logique metier, bus/realtime, observabilite et operations.

## Verdict Global

**Go-live recommande: NON (Go/No-Go = NO-GO)**  
Des blocants critiques existent et peuvent entrainer compromission de secrets, fuite/corruption de donnees multi-tenant, envois non autorises et incidents operationnels.

## Synthese Executive

- **Risque securite eleve**: secrets en dur et autorisations trop larges.
- **Risque metier eleve**: incoherence des statuts CRM et pertes de verite metier.
- **Risque realtime eleve**: architecture WhatsApp concurrente (duplication/perte possible).
- **Risque ops eleve**: absence de CI/CD minimal, monitoring et plan backup/restore.
- **Risque de deploiement**: configuration Firestore potentiellement cassante.

## Findings Priorises

### P0 - Critique (a traiter immediatement)

1. **Secrets hardcodes (client + backend)**
   - Fichiers: `lib/app_config.dart`, `functions/index.js`, `lib/firebase_options.dart`, `android/app/google-services.json`
   - Impact: abuse API, couts, compromission de canaux (SMS/WhatsApp/Email).
   - Action: retirer du code, rotation de toutes les cles, stocker en Secret Manager/env vars.

2. **Regles Firestore insuffisamment restrictives (risque multi-tenant)**
   - Fichier: `firestore.rules`
   - Impact: lecture/ecriture possibles entre entreprises (IDOR horizontal).
   - Action: regles basees sur `enterpriseId` + role + ownership + validation schema.

3. **Endpoints Node non proteges + CORS ouvert**
   - Fichiers: `sms-service/index.js`, `whatsapp-service/index.js`, `whatsapp-service/routes/whatsapp.js`
   - Impact: appels non autorises, envois frauduleux, DoS/metadonnees exposees.
   - Action: auth JWT Firebase verifyIdToken + RBAC + CORS allowlist + rate limiting.

4. **Double pipeline WhatsApp (non deterministic)**
   - Fichiers: `functions/index.js`, `whatsapp-service/services/queueService.js`, `lib/services/whatsapp_service.dart`
   - Impact: duplication/perte/messages hors ordre/incoherence d'etat.
   - Action: choisir un seul orchestrateur de queue et normaliser machine d'etat.

5. **Bug SMS probable en production (`index` hors scope)**
   - Fichier: `sms-service/index.js`
   - Impact: echec d'envoi en masse.
   - Action: corriger bug + test d'integration `/send`.

### P1 - Eleve (a traiter avant go-live)

1. **Incoherence des statuts metier CRM**
   - Fichiers: `lib/models/prospect.dart`, `lib/services/database_service.dart`, `lib/views/agent/agent_dashboard.dart`, `lib/views/enterprise/enterprise_dashboard.dart`
   - Impact: KPI faux, filtres incoherents, mauvaise priorisation commerciale.
   - Action: enum unique de statuts + migration donnees + mapping i18n UI.

2. **Resets destructifs de statut lors d'affectation**
   - Fichier: `lib/services/database_service.dart`
   - Impact: perte d'historique de qualification.
   - Action: separer "etat prospect" et "etat tache", ne pas reset sans action explicite.

3. **Logs/erreurs trop verbeux (fuite PII et infos sensibles)**
   - Fichiers: `lib/services/database_service.dart`, `lib/services/whatsapp_service.dart`, services Node
   - Impact: exposition de donnees en logs.
   - Action: redaction PII/secrets, logs structures, erreurs generiques cote client.

4. **Absence d'idempotence et retry robuste**
   - Fichiers: flux WhatsApp/SMS queue
   - Impact: doublons et echecs non recuperes.
   - Action: `idempotencyKey`, `attemptCount`, backoff exponentiel, DLQ, watchdog jobs bloques.

### P2 - Moyen

1. **Configuration Firestore deploy potentiellement invalide**
   - Fichier: `firebase.json` (`rules` pointe sur `y`)
   - Impact: deploiement de regles incorrectes / blocage lecture-ecriture.
   - Action: pointer vers `firestore.rules`, ajouter check CI bloquant.

2. **Build release Android signe en debug**
   - Fichier: `android/app/build.gradle.kts`
   - Impact: non conforme production.
   - Action: configurer keystore release et pipeline de signature.

3. **Ecritures Firestore excessives cote UI**
   - Fichier: `lib/views/agent/prospect_detail_screen.dart`
   - Impact: cout, conflits, latence.
   - Action: vrai debounce + sauvegarde explicite.

4. **Prospects orphelins a la suppression agent**
   - Fichier: `lib/services/database_service.dart`
   - Impact: pertes de suivi commercial.
   - Action: transaction de suppression + reassignment/unassign.

### P3 - Faible a surveiller

1. **Durcissement HTTP incomplet**
   - Action: `helmet`, limites payload, timeouts, anti-bruteforce.

2. **Faible reproductibilite dependances Node**
   - Observation: lockfiles non versionnes.
   - Action: versionner lockfiles, activer scans SCA (Dependabot/Snyk/npm audit).

## Etat des Exigences Demandees

- **Securite**: niveau insuffisant pour production (P0 ouverts).
- **Pertinence/logique**: incoherences metier majeures.
- **Elements de bus/realtime**: architecture non unifiee, idempotence faible.
- **Incoherences**: statuts CRM, flux affectation, UX de mise a jour.
- **Notifications reelles**: fiabilite insuffisante (risque doublons/pertes).

## Plan d'Execution Vers Production

### Sprint 0 (24-48h) - Containment

- Rotation immediate de toutes les cles exposees.
- Retrait des secrets du code source.
- Restriction des endpoints Node (auth obligatoire + CORS allowlist).
- Gel temporaire des envois bulk si necessaire.

### Sprint 1 (J+3 a J+7) - Securite & Integrite Donnees

- Refonte `firestore.rules` (least privilege, RBAC, ownership).
- Correctifs critiques SMS/WhatsApp (bug `index`, idempotence, retry).
- Unification des statuts CRM (enum + migration + tests).
- Correction `firebase.json` et procedure de deploiement Firestore.

### Sprint 2 (J+8 a J+14) - Fiabilite Ops & Release

- CI minimal: lint + tests + checks securite + build.
- Observabilite: Sentry/Crashlytics + logs structures + alerting backlog/echec.
- Release Android signee proprement.
- Runbook incident + runbook backup/restore valide.

## Definition of Done (Go-Live Gate)

Le passage en prod est autorise seulement si:

1. Aucun secret n'est present dans le code/versionning.
2. Regles Firestore valides + tests d'autorisation passent.
3. Endpoints critiques proteges (auth + RBAC + CORS + rate-limit).
4. Pipeline CI vert (lint, tests, build, scans).
5. Flux notifications: idempotence et retries verifies en test de charge.
6. Monitoring/alerting actif + runbook incident disponible.
7. Validation metier: KPI/statuts coherents apres migration.

## Backlog Technique Recommande (Top 10)

1. Supprimer secrets hardcodes et rotater credentials.
2. Refaire `firestore.rules` par tenant/role.
3. Authentifier et autoriser tous endpoints Node.
4. Fix bug `sms-service/index.js` (`index`).
5. Unifier pipeline WhatsApp autour d'un orchestrateur unique.
6. Introduire idempotence + retries + DLQ.
7. Normaliser statuts CRM (enum + migration).
8. Corriger `firebase.json` rules path.
9. Ajouter CI/CD minimal et scans securite.
10. Mettre monitoring/alerting et runbooks.

---

## Conclusion

Le projet est prometteur fonctionnellement, mais **pas pret pour une mise en production immediate**.  
Avec les corrections P0/P1 ci-dessus, un go-live maitrise est possible en 1 a 2 sprints.
