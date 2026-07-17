<!DOCTYPE html>
<html lang="ka">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta name="theme-color" content="#0f766e">
    <title>iDoctor.ge — ჯანმრთელობის ნავიგატორი</title>
    <link rel="manifest" href="/manifest.json">
    <link rel="icon" href="/icons/icon-192.png">
    <style>
        :root { --teal:#0f766e; --teal-d:#115e59; --bg:#f8fafc; --ink:#0f172a; --muted:#64748b; --danger:#dc2626; }
        * { box-sizing: border-box; }
        body { margin:0; font-family: system-ui, -apple-system, "Noto Sans Georgian", sans-serif; background:var(--bg); color:var(--ink); }
        header { background:var(--teal); color:#fff; padding:12px 16px; display:flex; align-items:center; justify-content:space-between; }
        header h1 { font-size:16px; margin:0; font-weight:700; }
        header .sub { font-size:11px; opacity:.85; }
        #chat { max-width:720px; margin:0 auto; padding:16px; padding-bottom:150px; }
        .msg { margin:10px 0; display:flex; }
        .msg.user { justify-content:flex-end; }
        .bubble { max-width:82%; padding:10px 14px; border-radius:14px; line-height:1.5; white-space:pre-wrap; font-size:15px; }
        .user .bubble { background:var(--teal); color:#fff; border-bottom-right-radius:4px; }
        .bot .bubble { background:#fff; border:1px solid #e2e8f0; border-bottom-left-radius:4px; }
        .disclaimer { color:var(--muted); font-size:12px; margin-top:6px; border-top:1px dashed #cbd5e1; padding-top:6px; }
        .emergency { background:#fef2f2; border:2px solid var(--danger); color:#7f1d1d; border-radius:14px; padding:16px; font-weight:600; }
        .emergency .call { display:inline-block; margin-top:8px; background:var(--danger); color:#fff; padding:10px 18px; border-radius:10px; text-decoration:none; font-size:18px; }
        .fb { margin-top:6px; display:flex; gap:8px; }
        .fb button { border:1px solid #e2e8f0; background:#fff; border-radius:8px; padding:2px 8px; cursor:pointer; font-size:13px; }
        .lab-card { background:#fff; border:1px solid #e2e8f0; border-radius:12px; padding:12px; margin:10px 0; }
        .lab-row { display:flex; justify-content:space-between; font-size:14px; padding:3px 0; border-bottom:1px solid #f1f5f9; }
        .flag { font-weight:700; }
        .flag.high { color:var(--danger); } .flag.low { color:#2563eb; } .flag.normal { color:#16a34a; } .flag.unknown { color:var(--muted); }
        footer { position:fixed; bottom:0; left:0; right:0; background:#fff; border-top:1px solid #e2e8f0; padding:10px; }
        .composer { max-width:720px; margin:0 auto; display:flex; gap:8px; align-items:flex-end; }
        textarea { flex:1; resize:none; border:1px solid #cbd5e1; border-radius:12px; padding:10px; font-size:15px; font-family:inherit; max-height:120px; }
        .btn { background:var(--teal); color:#fff; border:none; border-radius:12px; padding:10px 16px; cursor:pointer; font-size:15px; }
        .btn:disabled { opacity:.5; cursor:not-allowed; }
        .icon-btn { background:#f1f5f9; color:var(--ink); border:none; border-radius:12px; padding:10px 12px; cursor:pointer; }
        .toolbar { max-width:720px; margin:6px auto 0; display:flex; gap:8px; justify-content:space-between; font-size:12px; }
        .toolbar a, .toolbar button { color:var(--muted); background:none; border:none; cursor:pointer; text-decoration:underline; font-size:12px; }
        #visitCardBtn { display:none; }
        .modal { position:fixed; inset:0; background:rgba(15,23,42,.6); display:flex; align-items:center; justify-content:center; padding:16px; z-index:50; }
        .modal .box { background:#fff; border-radius:16px; padding:20px; max-width:460px; }
        .modal h2 { margin-top:0; font-size:18px; }
        .modal p { color:var(--muted); font-size:14px; line-height:1.6; }
        .hidden { display:none !important; }
    </style>
</head>
<body>
<header>
    <div>
        <h1>iDoctor.ge</h1>
        <div class="sub">ქართული ჯანმრთელობის ნავიგატორი — არ არის ექიმი</div>
    </div>
    <button class="icon-btn" id="visitCardBtn" title="ვიზიტის ბარათი">🩺 ბარათი</button>
</header>

<div id="chat">
    <div class="msg bot"><div class="bubble">გამარჯობა 👋 მე ვარ iDoctor — დაგეხმარებით ინფორმაციის გაგებაში და სწორ ექიმთან მიმართვაში. მე არ ვსვამ დიაგნოზს. რით შემიძლია დაგეხმაროთ?</div></div>
</div>

<footer>
    <div class="composer">
        <button class="icon-btn" id="labBtn" title="ანალიზის ატვირთვა">📎</button>
        <input type="file" id="labFile" accept="image/*,application/pdf" class="hidden">
        <textarea id="input" rows="1" placeholder="დაწერეთ თქვენი კითხვა..."></textarea>
        <button class="btn" id="sendBtn">გაგზავნა</button>
    </div>
    <div class="toolbar">
        <span id="status"></span>
        <button id="deleteBtn">🗑️ ჩემი მონაცემების წაშლა</button>
    </div>
</footer>

<!-- Consent modal -->
<div class="modal" id="consentModal">
    <div class="box">
        <h2>თანხმობა</h2>
        <p>
            iDoctor არ არის ექიმი და არ სვამს დიაგნოზს. ეს სერვისი საგანმანათლებლო ხასიათისაა.
            გადაუდებელ შემთხვევაში დარეკეთ <b>112</b>-ზე. თქვენი შეტყობინებები ინახება
            დაშიფრულად და შეგიძლიათ ნებისმიერ დროს წაშალოთ.
        </p>
        <p>გაგრძელებით თქვენ ეთანხმებით ამ პირობებს.</p>
        <button class="btn" id="consentBtn" style="width:100%">ვეთანხმები და ვაგრძელებ</button>
    </div>
</div>

<script>
const api = (p) => `/api${p}`;
let sessionId = null;
let lastMessageId = null;

async function init() {
    const r = await fetch(api('/session'), {method:'POST', headers:{'Content-Type':'application/json'}, body:'{}'});
    const j = await r.json();
    sessionId = j.session_id;
}

document.getElementById('consentBtn').onclick = async () => {
    await fetch(api(`/session/${sessionId}/consent`), {method:'POST'});
    document.getElementById('consentModal').classList.add('hidden');
    document.getElementById('input').focus();
};

function addBubble(role, text) {
    const wrap = document.createElement('div');
    wrap.className = 'msg ' + (role === 'user' ? 'user' : 'bot');
    const b = document.createElement('div');
    b.className = 'bubble';
    b.textContent = text;
    wrap.appendChild(b);
    document.getElementById('chat').appendChild(wrap);
    window.scrollTo(0, document.body.scrollHeight);
    return b;
}

function addFeedback(bubble) {
    const fb = document.createElement('div');
    fb.className = 'fb';
    for (const [kind, label] of [['up','👍'],['down','👎'],['report','⚠️ შეცდომა']]) {
        const btn = document.createElement('button');
        btn.textContent = label;
        btn.onclick = async () => {
            await fetch(api('/feedback'), {method:'POST', headers:{'Content-Type':'application/json'},
                body: JSON.stringify({session_id: sessionId, message_id: lastMessageId, kind})});
            btn.disabled = true;
        };
        fb.appendChild(btn);
    }
    bubble.parentElement.appendChild(fb);
}

async function send() {
    const input = document.getElementById('input');
    const text = input.value.trim();
    if (!text || !sessionId) return;
    input.value = '';
    document.getElementById('sendBtn').disabled = true;
    addBubble('user', text);

    const botBubble = addBubble('bot', '');
    let acc = '';
    let emergency = false;

    try {
        const resp = await fetch(api('/chat'), {
            method:'POST',
            headers:{'Content-Type':'application/json', 'Accept':'text/event-stream'},
            body: JSON.stringify({session_id: sessionId, message: text})
        });
        const reader = resp.body.getReader();
        const decoder = new TextDecoder();
        let buf = '';
        while (true) {
            const {done, value} = await reader.read();
            if (done) break;
            buf += decoder.decode(value, {stream:true});
            const events = buf.split('\n\n');
            buf = events.pop();
            for (const chunk of events) {
                const ev = parseSSE(chunk);
                if (!ev) continue;
                if (ev.event === 'delta') { acc += ev.data.text; botBubble.textContent = acc; }
                else if (ev.event === 'emergency') { emergency = true; renderEmergency(botBubble, ev.data.text); }
                else if (ev.event === 'disclaimer') { addDisclaimer(botBubble, ev.data.text); }
                else if (ev.event === 'done') {
                    lastMessageId = ev.data.message_id || null;
                    if (ev.data.show_visit_card) document.getElementById('visitCardBtn').style.display = 'block';
                    if (!emergency) addFeedback(botBubble);
                }
                else if (ev.event === 'error') { botBubble.textContent = errorText(ev.data.message); }
            }
            window.scrollTo(0, document.body.scrollHeight);
        }
    } catch (e) {
        botBubble.textContent = 'კავშირის შეცდომა. სცადეთ თავიდან.';
    } finally {
        document.getElementById('sendBtn').disabled = false;
    }
}

function parseSSE(chunk) {
    let event = 'message', data = '';
    for (const line of chunk.split('\n')) {
        if (line.startsWith('event:')) event = line.slice(6).trim();
        else if (line.startsWith('data:')) data += line.slice(5).trim();
    }
    if (!data) return null;
    try { return {event, data: JSON.parse(data)}; } catch { return null; }
}

function renderEmergency(bubble, text) {
    bubble.parentElement.classList.remove('bot');
    bubble.className = 'emergency';
    bubble.textContent = text;
    const call = document.createElement('a');
    call.className = 'call'; call.href = 'tel:112'; call.textContent = '📞 დარეკე 112';
    bubble.appendChild(document.createElement('br'));
    bubble.appendChild(call);
}

function addDisclaimer(bubble, text) {
    const d = document.createElement('div');
    d.className = 'disclaimer'; d.textContent = text;
    bubble.appendChild(d);
}

function errorText(code) {
    return ({consent_required:'გთხოვთ, ჯერ დაეთანხმოთ პირობებს.',
        rate_limited:'ძალიან ბევრი შეტყობინება. სცადეთ ცოტა ხანში.',
        llm_unavailable:'სერვისი დროებით მიუწვდომელია.'})[code] || 'შეცდომა.';
}

// --- lab upload ---
document.getElementById('labBtn').onclick = () => document.getElementById('labFile').click();
document.getElementById('labFile').onchange = async (e) => {
    const file = e.target.files[0];
    if (!file) return;
    addBubble('user', '📎 ' + file.name);
    const loading = addBubble('bot', 'ანალიზს ვამუშავებ...');
    const fd = new FormData();
    fd.append('session_id', sessionId); fd.append('file', file);
    try {
        const r = await fetch(api('/lab'), {method:'POST', body: fd});
        const j = await r.json();
        if (j.status === 'parsed') renderLab(loading, j);
        else loading.textContent = (j.error || 'ვერ დამუშავდა.');
    } catch { loading.textContent = 'ატვირთვის შეცდომა.'; }
    e.target.value = '';
};

function renderLab(bubble, j) {
    bubble.textContent = '';
    const card = document.createElement('div');
    card.className = 'lab-card';
    for (const row of (j.classified || [])) {
        const el = document.createElement('div');
        el.className = 'lab-row';
        const ref = (row.ref_low ?? '') + '–' + (row.ref_high ?? '');
        el.innerHTML = `<span>${row.name}: <b>${row.value}</b> ${row.unit||''} <span style="color:#94a3b8">(${ref})</span></span>`
            + `<span class="flag ${row.flag}">${labelFlag(row.flag)}</span>`;
        card.appendChild(el);
    }
    bubble.appendChild(card);
    const interp = document.createElement('div');
    interp.style.whiteSpace = 'pre-wrap';
    interp.textContent = j.interpretation || '';
    bubble.appendChild(interp);
}
function labelFlag(f){ return {high:'მაღალი',low:'დაბალი',normal:'ნორმა',unknown:'—'}[f]||f; }

// --- visit card ---
document.getElementById('visitCardBtn').onclick = async () => {
    const bubble = addBubble('bot', 'ვიზიტის ბარათს ვქმნი...');
    const r = await fetch(api('/visit-card'), {method:'POST', headers:{'Content-Type':'application/json'},
        body: JSON.stringify({session_id: sessionId})});
    const j = await r.json();
    bubble.textContent = j.summary || '';
    if ((j.questions_for_doctor||[]).length) {
        const h = document.createElement('div'); h.style.marginTop='8px'; h.innerHTML = '<b>კითხვები ექიმისთვის:</b>';
        const ul = document.createElement('ul');
        j.questions_for_doctor.forEach(q => { const li=document.createElement('li'); li.textContent=q; ul.appendChild(li); });
        bubble.appendChild(h); bubble.appendChild(ul);
    }
    const link = document.createElement('a');
    link.href = j.pdf_url; link.textContent = '⬇️ PDF-ის ჩამოტვირთვა'; link.target = '_blank';
    bubble.appendChild(link);
};

// --- delete data (GDPR) ---
document.getElementById('deleteBtn').onclick = async () => {
    if (!confirm('წავშალო თქვენი ყველა შეტყობინება და მონაცემი?')) return;
    await fetch(api(`/session/${sessionId}/data`), {method:'DELETE'});
    location.reload();
};

document.getElementById('sendBtn').onclick = send;
document.getElementById('input').addEventListener('keydown', (e) => {
    if (e.key === 'Enter' && !e.shiftKey) { e.preventDefault(); send(); }
});

if ('serviceWorker' in navigator) navigator.serviceWorker.register('/sw.js').catch(()=>{});
init();
</script>
</body>
</html>
