# iDoctor.ge — MVP backend

ქართულენოვანი AI ჯანმრთელობის ნავიგატორი. **არ არის ექიმი** — ხსნის ინფორმაციას,
აგროვებს ანამნეზს და მიმართავს სწორ სპეციალისტთან.

Laravel 12 · PostgreSQL 16 + pgvector · Claude API · Voyage embeddings.

> ეს არის მომუშავე MVP, აწყობილი სპეციფიკაციიდან (`iDoctor_MVP_Tech_Brief`-ის
> არქიტექტურა). launch-ამდე საჭიროა: ექიმ-advisor-ის რევიზია (KB + ლაბ. ნორმები),
> იურისტის go/no-go და Layer B-ს ჩართვა რეალურ API-ზე (§ 100% recall gate).

---

## სამი ურყევი წესი (კოდში ჩაშენებული)

1. **ლაბ. ნორმები** — მხოლოდ `lab_reference_ranges` ცხრილიდან. „ნორმაშია თუ არა"
   წყდება `LabParser::classify()`-ში, დეტერმინისტულად — **არასდროს LLM-ით**.
2. **Red-flag ტრიაჟი** — ეშვება Claude-მდე (`ChatController::send` → `TriageService::detect`
   პირველი). emergency-ზე pipeline ჩერდება, Claude საერთოდ არ იძახება → 112 ეკრანი.
3. **threshold-ები კონფიგში** (`config/idoctor.php`). ყველა პასუხი ფსევდონიმიზებულ,
   content-free audit log-ში (`session_hash = HMAC`, `storage/logs/audit-*.log`).

## Pipeline

```
rate-limit → TriageService(A+B) → [emergency? → 112, STOP] → RouterService
          → RagService → LabParser (თუ ფაილია) → ChatOrchestrator → Claude stream → AuditLogger
```

---

## გაშვება

```bash
composer install
cp .env.example .env && php artisan key:generate

# PostgreSQL 16 + pgvector
createdb idoctor           # role/DB თქვენი გარემოს მიხედვით
php artisan migrate        # CREATE EXTENSION vector migration-შია

# ლაბ. ნორმები (CSV) + KB starter pack
php artisan db:seed

# API გასაღებები .env-ში: ANTHROPIC_API_KEY, VOYAGE_API_KEY

# RAG embeddings (სურვილისამებრ)
# .env: IDOCTOR_EMBEDDINGS_ENABLED=true
php artisan idoctor:embed-kb

php artisan serve   # http://localhost:8000
```

## ტესტები

```bash
php artisan test                          # ყველა
php artisan test --group=lab              # Rule #1: ნორმის მიბმა
php artisan test --group=triage           # Layer A recall baseline
php artisan test --group=triage-integration   # 100% recall gate (საჭიროებს API key)
```

### ტრიაჟის eval harness

```bash
php artisan idoctor:triage-eval           # Layer A only
php artisan idoctor:triage-eval --llm     # Layer A + B (საჭიროებს ANTHROPIC_API_KEY)
```

### მეტრიკა და readiness

```bash
php artisan idoctor:metrics --days=7      # content-free პროდუქტ-მეტრიკა (MAU, ტრიაჟის რეიტი, NPS-proxy)
curl localhost:8000/api/health            # readiness probe (db, ლაბ. ნორმები, ტრიაჟი, გასაღებები)
```

---

## 100% recall gate (LAUNCH BLOCKER)

623-სცენარიან red-flag სუიტზე ტრიაჟმა უნდა მიაღწიოს **recall = 1.0**.

| ფენა | recall | სტატუსი |
|------|--------|---------|
| Layer A (keyword/regex, deterministic) | **1.000** (468/468) | ✅ offline სუიტზე |
| Layer A specificity | 0.994 (154/155) | ✅ (recall-first — 1 მისაღები false-positive) |
| Layer A + B (LLM) | — | ⏳ საჭიროებს `ANTHROPIC_API_KEY`-ს + `IDOCTOR_TRIAGE_LLM_ENABLED=true` |

recall-first დიზაინი: false-positive (ზედმეტი 112) მისაღებია, false-negative
(გამოტოვება) ფატალურია. Layer B ჩართულია launch-ისთვის, რომ დაიფაროს Layer A-ს
დარჩენილი phrasing-ები. missed emergency-ების სანახავად: `idoctor:triage-eval`.

---

## სტრუქტურა

| ფენა | ფაილები |
|------|---------|
| Services | `TriageService`, `ClaudeClient`, `RouterService`, `ChatOrchestrator`, `RagService`, `EmbeddingClient`, `LabParser`, `LabInterpreter`, `AuditLogger` |
| Controllers | `ChatController` (SSE), `SessionController` (consent/GDPR), `LabController`, `VisitCardController` (+PDF), `FeedbackController` |
| Models | `ChatSession`, `Message` (encrypted), `LabUpload`, `LabReferenceRange`, `VisitCard`, `Feedback`, `KbDocument`, `KbChunk` |
| Data | `database/data/lab_reference_ranges.csv` (44), `redflag_test_suite.csv` (623), `kb_starter_pack.md` (14 დოკ.) |
| Ops | `idoctor:metrics` (content-free მეტრიკა), `GET /api/health` (readiness probe) |
| Frontend | `resources/views/chat.blade.php` (SSE, consent, emergency UI, lab upload, feedback, visit card, PWA) |

## ფაზა-1 სფერო

გინეკოლოგია · უროლოგია · სგგდ · ენდოკრინოლოგია · ზოგადი ლაბ. ანალიზები.
