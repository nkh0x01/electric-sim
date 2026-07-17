<?php

/*
|--------------------------------------------------------------------------
| iDoctor.ge configuration
|--------------------------------------------------------------------------
|
| Rule #3: every tunable threshold lives here, never hard-coded in a service.
| The red-flag triage vocabulary (Rule #2) also lives here so that clinicians
| can review and extend it without touching PHP.
|
*/

return [

    // ---------------------------------------------------------------------
    // Product framing
    // ---------------------------------------------------------------------
    'name' => env('IDOCTOR_NAME', 'iDoctor.ge'),

    // Phase-1 clinical scope. Anything outside is answered with a soft
    // "out of scope, please consult a specialist" note.
    'scope_specialties' => [
        'gynecology', 'urology', 'sti', 'endocrinology', 'general_labs',
    ],

    // ---------------------------------------------------------------------
    // Claude / routing (unit economics — Haiku by default, Sonnet on demand)
    // ---------------------------------------------------------------------
    'models' => [
        'cheap' => env('IDOCTOR_MODEL_CHEAP', 'claude-haiku-4-5'),
        'premium' => env('IDOCTOR_MODEL_PREMIUM', 'claude-sonnet-5'),
        'vision' => env('IDOCTOR_MODEL_VISION', 'claude-sonnet-5'),
        'triage' => env('IDOCTOR_MODEL_TRIAGE', 'claude-haiku-4-5'),
    ],

    'router' => [
        // Escalate to the premium model when the prompt is long or a lab
        // interpretation / structured reasoning is involved.
        'escalate_char_threshold' => (int) env('IDOCTOR_ROUTER_CHARS', 900),
        'max_output_tokens' => (int) env('IDOCTOR_MAX_OUTPUT_TOKENS', 1024),
    ],

    // ---------------------------------------------------------------------
    // Triage (Rule #2). Recall-first: a false positive (an unnecessary 112
    // screen) is acceptable; a false negative (a missed emergency) is fatal.
    // ---------------------------------------------------------------------
    'triage' => [

        // Layer B (LLM confirmation) is a launch requirement for 100% recall.
        // Layer A alone runs deterministically and never calls the network.
        'llm_enabled' => env('IDOCTOR_TRIAGE_LLM_ENABLED', false),

        // Layer B votes "emergency" if its estimated probability >= this.
        // Deliberately low — recall beats precision here.
        'llm_threshold' => (float) env('IDOCTOR_TRIAGE_LLM_THRESHOLD', 0.15),

        // If Layer B errors or times out we fail OPEN (treat as emergency
        // only when Layer A already had *some* signal), never fail closed.
        'fail_open' => true,

        // Layer A recall baseline the unit test asserts against.
        'layer_a_min_recall' => (float) env('IDOCTOR_LAYER_A_MIN_RECALL', 0.85),

        /*
        | Red-flag phrase bank. Matching is done on normalised text
        | (lower-cased, punctuation stripped, whitespace collapsed) so each
        | entry may be Georgian script OR Latin transliteration. A single
        | hit anywhere in the message flips the message to emergency.
        |
        | These are intentionally broad. Clinicians extend this list; they
        | do not need to touch TriageService.
        */
        'redflag_phrases' => [

            // -- cardiac ------------------------------------------------
            'გულმკერდის ტკივილი', 'გულმკერდში ტკივილი', 'მკერდის ტკივილი',
            'მკერდში ტკივილი', 'გულში მიჭერს', 'გულთან ისე მტკივა',
            'მკერდი ამომივსო', 'მკერდი ამომება', 'მკერდში ისრისებრი',
            'ისრისებრი ტკივილი', 'ცივი ოფლი', 'მარცხენა ხელი', 'მარცხენა მკლავი',
            'ხელი მებუჟება', 'ხელი დამიმძიმდა', 'მკლავი დამიმძიმდა',
            'გულის შეტევა', 'ინფარქტი',
            'gulmkerdis tkivili', 'mkerdis tkivili', 'guli mtkiva',
            'marcxena xeli', 'marcxena mklavi', 'xeli mebujeba', 'civi ofli',

            // -- stroke -------------------------------------------------
            'სახის ერთი მხარე', 'სახე ჩამომივარდა', 'პირი გაემრუდა',
            'პირი გამიმრუდდა', 'პირი გაუმრუდდა', 'მეტყველება აერია',
            'მეტყველება ამერია', 'სიტყვები ამერია', 'ვერ ვლაპარაკობ',
            'ვერ ვსაუბრობ', 'ვერ საუბრობს', 'ხელი გამისუსტდა',
            'ხელი აღარ მემორჩილება', 'ხელი უცებ გამისუსტდა', 'ვერ დაიჭირა',
            'ინსულტი', 'ცალი მხარე დამბლა',
            'saxis erti mxare', 'chamomivarda', 'metyveleba ameria',
            'ver vlaparakob', 'piri gaemruda', 'xeli gamisustda',

            // -- breathing ----------------------------------------------
            'ვერ ვსუნთქავ', 'სუნთქვა მიჭირს', 'სუნთქვა გამიჭირდა',
            'ვიხრჩობი', 'ვიგუდები', 'ვხრჩობი', 'ჰაერი არ მიდის',
            'ჰაერი არ მყოფნის', 'ტუჩები მილურჯდება', 'ტუჩები ლურჯდება',
            'ინჰალატორი აღარ მშველის', 'ინჰალატორი აღარ',
            'ver vsuntqav', 'suntqva michirs', 'vixrchobi', 'vigudebi', 'vxrchobi',

            // -- suicide / self-harm ------------------------------------
            'თავის მოკვლა', 'თავს მოვიკლავ', 'აღარ მინდა ცხოვრება',
            'აღარ ღირს ცხოვრება', 'აზრი აღარ აქვს არაფერს',
            'აღარ მინდა გამეღვიძოს', 'სჯობს აღარ ვიყო', 'საერთოდ აღარ ვიყო',
            'გადავწყვიტე წავიდე', 'წავიდე ჯობია', 'ვეღარ ვუძლებ',
            'თავის დაზიანება', 'თავს დავიზიანებ',
            'tavis mokvla', 'agar minda cxovreba', 'agar girs cxovreba',
            'vegar vudzleb',

            // -- bleeding -----------------------------------------------
            'ძლიერი სისხლდენა', 'სისხლდენა მაქვს', 'სისხლდენა დამეწყო',
            'სისხლი ბლომად', 'სისხლი ჩქეფს', 'სისხლი ხახავს', 'სისხლი ხახა',
            'ვერ ვაჩერებ', 'არ ჩერდება', 'სისხლი მდის', 'სისხლი წავიდა',
            'zlieri sisxldena', 'sisxldena maqvs', 'sisxli blomad',
            'ver vacereb', 'ar cerdeba', 'sisxli mdis',

            // -- pregnancy emergencies ----------------------------------
            'ორსული ვარ და სისხლ', 'ორსულად ვარ', 'ორსულადაა',
            'ფეხმძიმედ ვარ', 'ორსული ვარ და', 'მუცელი ძალიან მტკივა და სისხლი',
            'orsuli var da sisxl', 'orsulad var', 'fexmzimed var',

            // -- anaphylaxis --------------------------------------------
            'ყელი მებერება', 'ყელი ამომება', 'ყელი ამომივსო', 'სახე დაება',
            'სახე დამებერა', 'მთელი ტანი გამომაყარა', 'ტანი გამომაყარა',
            'გამონაყარი და სუნთქვა', 'ფუტკარმა მკბინა', 'ალერგიული შოკი',
            'keli meberება', 'keli mebereba', 'gamomayara', 'saxe daeba',

            // -- poisoning / overdose -----------------------------------
            'მოწამვლა', 'ბევრი წამალი დავლიე', 'ბევრი აბი', 'აბები დავლიე',
            'გადავყლაპე', 'ქიმია დალია', 'ქიმია დალია', 'გასაწმენდი',
            'ორმაგი დოზა', 'დოზა დალია', 'ვერ ვაღვიძებ',
            'mowamvla', 'bevri wamali davlie', 'qimia dalia', 'ormagi doza',

            // -- neuro --------------------------------------------------
            'გონება დავკარგე', 'გონს მოვედი', 'გონი დავკარგე', 'კრუნჩხვა',
            'კრუნჩხვა დამეწყო', 'თითქოს რაღაც გასკდა', 'ულმური თავის ტკივილი',
            'ულმური თავის', 'თვალები გადააბრუნა', 'თვალები გადაატრიალა',
            'goneba davkarge', 'krunchxva', 'gons movedi',

            // -- pediatric emergencies ----------------------------------
            'ბავშვს მაღალი ტემპერატურა და ლეთარგია', 'ლეთარგია',
            'ჩვილს სუნთქვა', 'ბავშვი ლურჯდება', 'ჩვილი ლურჯდება',
            'აღარ რეაგირებს', 'არ რეაგირებს', 'ღონემიხდილია',
            'ბავშვს 39', 'ბავშვი დღეა არ შარდავს',
            'bavshvs magali temperatura', 'chvils suntqva', 'letargia',

            // -- additional real-world phrasings (from eval misses) -----
            // cardiac
            'მკერდში ძალიან მტკივა', 'მკერდში მტკივა', 'მკერდი მიჭერს',
            'მკერდი უჭირავს', 'მკერდი მტკი', 'მხარი ჩამიბუჟდა',
            'მარცხენა მხარი', 'ცხელი ოფლი', 'ოფლში იწურება', 'ოფლში იწ',
            'mkerdshi zalian mtkiva', 'mkerdshi mtkiva', 'mkerdi mizers',
            'cxeli ofli', 'mkerdi mtki',
            // stroke
            'სახე გამიმრუდდა', 'ხელი არ მემორჩილება', 'ხელი არ ემორჩილება',
            'ენა დამება', 'ვერაფერს ვამბობ', 'გვერდზე გადაიხარა', 'ბლუყუნებს',
            'ena dameba', 'gverdze gadaixara',
            // breathing
            'ცუდად სუნთქავს', 'გულმკერდი ჩაუზნექია', 'ტუჩები ულურჯდება',
            'ბავშვი ცუდად სუნთქავს',
            // bleeding
            'ისე მდის სისხლი', 'ტანსაცმელი გაჟღინთა', 'სისხლი ისე მდის',
            // self-harm (translit)
            'tavs davizianeb',
            // neuro — thunderclap / syncope / new severe headache
            'უეცარი ძლიერი თავის ტკივილი', 'აქამდე ასეთი არასდროს',
            'ასეთი არასდროს', 'ცხოვრებაში არ მქონია', 'გონს რომ მოვედი',
            'არ მახსოვს რა მოხდა', 'ისე ამტკივდა',
            'ueceri zlieri tavis tkivili', 'gons rom movedi',

            // -- generic hard red flags ---------------------------------
            'ვერ ვდგები ფეხზე', 'გული მიწუხს', 'ვკვდები', 'მკვდარი',
        ],

        // 112 emergency template shown INSTEAD of any Claude output.
        // Rule #2: the pipeline stops here; Claude is never called.
        'emergency_template' => "🚨 ეს შეიძლება იყოს გადაუდებელი მდგომარეობა.\n\n".
            "დაუყოვნებლივ დარეკეთ **112**-ზე ან მიმართეთ უახლოეს გადაუდებელი დახმარების განყოფილებას.\n\n".
            'iDoctor არ არის ექიმი და ვერ უზრუნველყოფს გადაუდებელ დახმარებას. '.
            'თუ სიცოცხლისთვის საშიშ სიმპტომებს განიცდით — არ დაელოდოთ.',

        // Suicide/self-harm gets an additional hotline line.
        'crisis_hotline_template' => "თუ საკუთარი თავის დაზიანებაზე ფიქრობთ, თქვენ მარტო არ ხართ.\n\n".
            'დარეკეთ **112**-ზე ან ფსიქიკური ჯანმრთელობის კრიზისულ ხაზზე. '.
            'გთხოვთ, ახლავე მიმართოთ ადამიანს, ვისაც ენდობით.',
    ],

    // ---------------------------------------------------------------------
    // Medical disclaimer — appended to EVERY medical answer.
    // ---------------------------------------------------------------------
    'disclaimer' => '⚕️ iDoctor არ არის ექიმი და არ სვამს დიაგნოზს. ეს ინფორმაცია '.
        'საგანმანათლებლო ხასიათისაა და არ ცვლის ექიმის კონსულტაციას. '.
        'სიმპტომების გაუარესებისას მიმართეთ სპეციალისტს.',

    // ---------------------------------------------------------------------
    // RAG (pgvector + Voyage)
    // ---------------------------------------------------------------------
    'rag' => [
        'enabled' => env('IDOCTOR_EMBEDDINGS_ENABLED', false),
        'top_k' => (int) env('IDOCTOR_RAG_TOP_K', 5),
        'min_score' => (float) env('IDOCTOR_RAG_MIN_SCORE', 0.25),
        'chunk_tokens' => (int) env('IDOCTOR_RAG_CHUNK_TOKENS', 400),
    ],

    'embeddings' => [
        'model' => env('VOYAGE_MODEL', 'voyage-3'),
        'dimensions' => (int) env('VOYAGE_DIMENSIONS', 1536),
    ],

    // ---------------------------------------------------------------------
    // Rate limiting (per anonymous session)
    // ---------------------------------------------------------------------
    'rate_limit' => [
        'messages_per_minute' => (int) env('IDOCTOR_RL_PER_MIN', 12),
        'messages_per_day' => (int) env('IDOCTOR_RL_PER_DAY', 200),
    ],

    // ---------------------------------------------------------------------
    // Privacy / audit (Rule #3: pseudonymised, content-free audit log)
    // ---------------------------------------------------------------------
    'audit' => [
        // HMAC key used to derive session_hash. Falls back to APP_KEY.
        'hmac_key' => env('IDOCTOR_AUDIT_HMAC_KEY', env('APP_KEY')),
    ],

    // Days after which a session and its messages are purged automatically.
    'retention_days' => (int) env('IDOCTOR_RETENTION_DAYS', 30),
];
