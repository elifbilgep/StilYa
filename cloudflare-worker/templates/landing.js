import { LEGAL_PAGE_STYLE } from './legal-style.js';

export const LANDING_PAGE_HTML = `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>STILYA — Satın Almadan Önce Dene</title>
  <meta name="description" content="Kıyafetleri satın almadan önce yapay zeka ile kendi üzerinde dene. Sanal deneme kabini.">
  ${LEGAL_PAGE_STYLE}
  <style>
    body { display: flex; align-items: center; justify-content: center; min-height: 100vh; text-align: center; }
    .container { padding: 48px 24px; }
    .logo { font-size: 42px; font-weight: 700; letter-spacing: -1px; margin-bottom: 12px; }
    .tagline { font-size: 18px; color: #6B6B6B; margin-bottom: 40px; font-style: italic; }
    .badge { display: inline-block; margin-top: 8px; padding: 14px 32px; background: #1A1A1A; color: #FAF9F6; border-radius: 12px; font-size: 15px; font-weight: 600; text-decoration: none; transition: opacity 0.2s; }
    .badge:hover { opacity: 0.85; }
    .screens { display: flex; gap: 16px; justify-content: center; margin: 40px 0; max-width: 680px; margin-left: auto; margin-right: auto; }
    .screen { flex: 1; min-width: 0; max-width: 200px; text-align: center; }
    .screen img { width: 100%; border-radius: 16px; object-fit: cover; image-orientation: from-image; }
    .screen-label { font-size: 13px; font-weight: 600; color: #2D2D2D; margin-top: 12px; }
    .screen-desc { font-size: 11px; color: #6B6B6B; margin-top: 2px; }
    .links { margin-top: 48px; }
    .links a { font-size: 13px; color: #6B6B6B; margin: 0 12px; }
    .footer { margin-top: 32px; font-size: 12px; color: #999; }
    .lang-switch { position: absolute; top: 20px; right: 24px; display: flex; gap: 4px; background: #EEECEA; border-radius: 8px; padding: 3px; }
    .lang-switch button { border: none; background: transparent; padding: 6px 12px; font-size: 13px; font-weight: 600; color: #6B6B6B; border-radius: 6px; cursor: pointer; transition: all 0.2s; }
    .lang-switch button.active { background: #fff; color: #1A1A1A; box-shadow: 0 1px 3px rgba(0,0,0,0.1); }
  </style>
  <script>
    const texts = {
      tr: { tagline: "Satın almadan önce dene", labels: ["Kıyafet Seç","Kombin Oluştur","Sonucu Gör"], descs: ["Tek parça veya kombin","Üst + alt bir arada","Kendi üzerinde dene"], badge: "App Store'dan İndir", privacy: "Gizlilik Politikası", terms: "Kullanım Koşulları", contact: "Bize ulaşın: ", footer: "© 2026 STILYA. Tüm hakları saklıdır." },
      en: { tagline: "Try before you buy", labels: ["Pick a Garment","Create Combo","See the Result"], descs: ["Single item or combo","Top + bottom together","Try it on yourself"], badge: "Download on App Store", privacy: "Privacy Policy", terms: "Terms of Use", contact: "Contact us: ", footer: "© 2026 STILYA. All rights reserved." }
    };
    function switchLang(lang) {
      const t = texts[lang];
      document.getElementById('tagline').textContent = t.tagline;
      document.querySelectorAll('.screen-label').forEach((el, i) => el.textContent = t.labels[i]);
      document.querySelectorAll('.screen-desc').forEach((el, i) => el.textContent = t.descs[i]);
      document.getElementById('badge').textContent = t.badge;
      document.getElementById('link-privacy').textContent = t.privacy;
      document.getElementById('link-terms').textContent = t.terms;
      document.getElementById('contact').innerHTML = t.contact + '<a href="mailto:elif.codes@gmail.com" style="color: #2D2D2D; font-weight: 500;">elif.codes@gmail.com</a>';
      document.getElementById('footer').textContent = t.footer;
      document.querySelectorAll('.lang-switch button').forEach(b => b.classList.toggle('active', b.dataset.lang === lang));
    }
  </script>
</head>
<body>
  <div class="container" style="position: relative;">
    <div class="lang-switch">
      <button class="active" data-lang="tr" onclick="switchLang('tr')">TR</button>
      <button data-lang="en" onclick="switchLang('en')">EN</button>
    </div>
    <div class="logo">STILYA</div>
    <div class="tagline" id="tagline">Satın almadan önce dene</div>

    <div class="screens">
      <div class="screen">
        <img src="/assets/home.png" alt="STILYA Ana Ekran" loading="lazy">
        <div class="screen-label">Kıyafet Seç</div>
        <div class="screen-desc">Tek parça veya kombin</div>
      </div>
      <div class="screen">
        <img src="/assets/combo.png" alt="STILYA Kombin Oluştur" loading="lazy">
        <div class="screen-label">Kombin Oluştur</div>
        <div class="screen-desc">Üst + alt bir arada</div>
      </div>
      <div class="screen">
        <img src="/assets/result.png" alt="STILYA Sonuç" loading="lazy">
        <div class="screen-label">Sonucu Gör</div>
        <div class="screen-desc">Kendi üzerinde dene</div>
      </div>
    </div>

    <a class="badge" id="badge" href="https://apps.apple.com/lb/app/stilya/id6759225147" target="_blank">App Store'dan İndir</a>

    <div class="links">
      <a href="/privacy" id="link-privacy">Gizlilik Politikası</a>
      <a href="/terms" id="link-terms">Kullanım Koşulları</a>
    </div>
    <div class="contact" id="contact" style="margin-top: 32px; font-size: 13px; color: #6B6B6B;">Bize ulaşın: <a href="mailto:elif.codes@gmail.com" style="color: #2D2D2D; font-weight: 500;">elif.codes@gmail.com</a></div>
    <div class="footer" id="footer">&copy; 2026 STILYA. Tüm hakları saklıdır.</div>
  </div>
</body>
</html>`;
