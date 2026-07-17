<!DOCTYPE html>
<html lang="ka">
<head>
    <meta charset="utf-8">
    <style>
        /* DejaVu Sans ships Georgian glyphs and is bundled with dompdf. */
        * { font-family: "DejaVu Sans", sans-serif; }
        body { color:#0f172a; font-size:12px; line-height:1.6; }
        h1 { font-size:18px; color:#0f766e; margin-bottom:2px; }
        .sub { color:#64748b; font-size:10px; margin-bottom:16px; }
        h2 { font-size:13px; border-bottom:1px solid #cbd5e1; padding-bottom:3px; margin-top:18px; }
        ul { margin:4px 0; padding-left:18px; }
        .meta { color:#64748b; font-size:10px; }
        .disclaimer { margin-top:24px; color:#64748b; font-size:10px; border-top:1px dashed #cbd5e1; padding-top:8px; }
    </style>
</head>
<body>
    <h1>ვიზიტის ბარათი — iDoctor.ge</h1>
    <div class="sub">შექმნილია: {{ optional($generated)->format('Y-m-d H:i') }}</div>

    <h2>მოკლე აღწერა</h2>
    <div>{{ $card->summary }}</div>

    @if(!empty($card->symptoms))
        <h2>სიმპტომები</h2>
        <ul>
            @foreach($card->symptoms as $s)
                <li>{{ $s }}</li>
            @endforeach
        </ul>
    @endif

    @if(!empty($card->questions_for_doctor))
        <h2>კითხვები ექიმისთვის</h2>
        <ul>
            @foreach($card->questions_for_doctor as $q)
                <li>{{ $q }}</li>
            @endforeach
        </ul>
    @endif

    @if($card->suggested_specialty)
        <h2>რეკომენდებული სპეციალისტი</h2>
        <div class="meta">{{ $card->suggested_specialty }}</div>
    @endif

    <div class="disclaimer">{{ $disclaimer }}</div>
</body>
</html>
