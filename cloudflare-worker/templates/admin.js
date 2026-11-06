export const ADMIN_PANEL_HTML = `<!DOCTYPE html>
<html lang="tr">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>StilYa Admin Panel</title>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background: #0f0f0f; color: #e0e0e0; min-height: 100vh; }

  .login-screen { display: flex; align-items: center; justify-content: center; min-height: 100vh; }
  .login-box { background: #1a1a1a; border: 1px solid #333; border-radius: 12px; padding: 40px; width: 360px; }
  .login-box h1 { font-size: 24px; margin-bottom: 24px; text-align: center; color: #C9A962; }
  .login-box input { width: 100%; padding: 12px 16px; background: #222; border: 1px solid #444; border-radius: 8px; color: #fff; font-size: 14px; margin-bottom: 16px; }
  .login-box button { width: 100%; padding: 12px; background: #C9A962; color: #000; border: none; border-radius: 8px; font-weight: 600; font-size: 14px; cursor: pointer; }
  .login-box button:hover { background: #d4b56e; }

  .dashboard { display: none; }
  .header { background: #1a1a1a; border-bottom: 1px solid #333; padding: 16px 24px; display: flex; align-items: center; justify-content: space-between; }
  .header h1 { font-size: 20px; color: #C9A962; }
  .header .logout { background: none; border: 1px solid #555; color: #aaa; padding: 6px 14px; border-radius: 6px; cursor: pointer; font-size: 13px; }
  .header .logout:hover { border-color: #888; color: #fff; }

  .container { max-width: 900px; margin: 0 auto; padding: 24px; }

  .card { background: #1a1a1a; border: 1px solid #333; border-radius: 12px; padding: 24px; margin-bottom: 20px; }
  .card h2 { font-size: 16px; color: #C9A962; margin-bottom: 16px; border-bottom: 1px solid #333; padding-bottom: 8px; }

  .form-row { display: flex; gap: 12px; margin-bottom: 12px; align-items: flex-end; }
  .form-group { flex: 1; }
  .form-group label { display: block; font-size: 12px; color: #888; margin-bottom: 4px; text-transform: uppercase; letter-spacing: 0.5px; }
  .form-group input, .form-group select { width: 100%; padding: 10px 12px; background: #222; border: 1px solid #444; border-radius: 8px; color: #fff; font-size: 14px; }

  .btn { padding: 10px 20px; border: none; border-radius: 8px; font-weight: 600; font-size: 13px; cursor: pointer; white-space: nowrap; }
  .btn-primary { background: #C9A962; color: #000; }
  .btn-primary:hover { background: #d4b56e; }
  .btn-danger { background: #B94A48; color: #fff; }
  .btn-danger:hover { background: #c55553; }
  .btn-success { background: #2D5F3F; color: #fff; }
  .btn-success:hover { background: #387a4f; }
  .btn-secondary { background: #333; color: #ddd; }
  .btn-secondary:hover { background: #444; }
  .btn:disabled { opacity: 0.5; cursor: not-allowed; }

  .result-box { background: #111; border: 1px solid #333; border-radius: 8px; padding: 16px; margin-top: 12px; font-family: 'SF Mono', monospace; font-size: 13px; line-height: 1.6; white-space: pre-wrap; word-break: break-all; max-height: 400px; overflow-y: auto; display: none; }
  .result-box.visible { display: block; }
  .result-box .label { color: #888; }
  .result-box .value { color: #C9A962; }
  .result-box .error { color: #B94A48; }
  .result-box .success { color: #2D5F3F; }

  .toggle-row { display: flex; align-items: center; justify-content: space-between; padding: 12px 0; border-bottom: 1px solid #222; }
  .toggle-row:last-child { border-bottom: none; }
  .toggle-label { font-size: 14px; }
  .toggle-label small { color: #666; display: block; font-size: 12px; margin-top: 2px; }
  .toggle-switch { position: relative; width: 48px; height: 26px; }
  .toggle-switch input { opacity: 0; width: 0; height: 0; }
  .toggle-switch .slider { position: absolute; top: 0; left: 0; right: 0; bottom: 0; background: #444; border-radius: 13px; cursor: pointer; transition: 0.2s; }
  .toggle-switch .slider:before { content: ""; position: absolute; height: 20px; width: 20px; left: 3px; bottom: 3px; background: #fff; border-radius: 50%; transition: 0.2s; }
  .toggle-switch input:checked + .slider { background: #2D5F3F; }
  .toggle-switch input:checked + .slider:before { transform: translateX(22px); }

  .stats-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 12px; margin-bottom: 16px; }
  .stat-item { background: #222; border-radius: 8px; padding: 16px; text-align: center; }
  .stat-item .num { font-size: 28px; font-weight: 700; color: #C9A962; }
  .stat-item .lbl { font-size: 11px; color: #888; text-transform: uppercase; margin-top: 4px; }

  .user-info-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 8px 24px; }
  .user-info-item { padding: 6px 0; border-bottom: 1px solid #222; }
  .user-info-item .key { font-size: 11px; color: #888; text-transform: uppercase; }
  .user-info-item .val { font-size: 14px; color: #e0e0e0; margin-top: 2px; }

  .toast { position: fixed; bottom: 24px; right: 24px; padding: 12px 20px; border-radius: 8px; font-size: 13px; font-weight: 500; z-index: 999; transform: translateY(80px); opacity: 0; transition: all 0.3s; }
  .toast.show { transform: translateY(0); opacity: 1; }
  .toast.success { background: #2D5F3F; color: #fff; }
  .toast.error { background: #B94A48; color: #fff; }
</style>
</head>
<body>

<!-- Login -->
<div class="login-screen" id="loginScreen">
  <div class="login-box">
    <h1>StilYa Admin</h1>
    <input type="password" id="adminKeyInput" placeholder="Admin Secret Key" autofocus>
    <button onclick="doLogin()">Giriş Yap</button>
  </div>
</div>

<!-- Dashboard -->
<div class="dashboard" id="dashboard">
  <div class="header">
    <h1>StilYa Admin Panel</h1>
    <button class="logout" onclick="doLogout()">Çıkış</button>
  </div>

  <div class="container">

    <!-- User Lookup -->
    <div class="card">
      <h2>👤 Kullanıcı Ara</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Firebase UID veya E-posta</label>
          <input type="text" id="lookupUid" placeholder="UID veya e-posta girin">
        </div>
        <button class="btn btn-primary" onclick="fetchUser()">Getir</button>
      </div>
      <div class="form-row">
        <div class="form-group">
          <label>İsimle Ara</label>
          <input type="text" id="lookupName" placeholder="Kullanıcı adı girin">
        </div>
        <button class="btn btn-secondary" onclick="searchByName()">Ara</button>
      </div>
      <div class="result-box" id="userResult"></div>
    </div>

    <!-- Credit Management -->
    <div class="card">
      <h2>💰 Kredi Yönetimi</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Firebase UID</label>
          <input type="text" id="creditUid" placeholder="Kullanıcı ID'si">
        </div>
        <div class="form-group" style="max-width: 140px;">
          <label>İşlem</label>
          <select id="creditAction">
            <option value="set">Set (Ayarla)</option>
            <option value="add">Add (Ekle)</option>
          </select>
        </div>
        <div class="form-group" style="max-width: 120px;">
          <label>Kredi Tipi</label>
          <select id="creditType">
            <option value="credits">Free</option>
            <option value="purchasedCredits">Purchased</option>
          </select>
        </div>
        <div class="form-group" style="max-width: 100px;">
          <label>Miktar</label>
          <input type="number" id="creditAmount" value="10" min="0">
        </div>
        <button class="btn btn-success" onclick="updateCredits()">Uygula</button>
      </div>
      <div class="result-box" id="creditResult"></div>
    </div>

    <!-- Ban Management -->
    <div class="card">
      <h2>🚫 Ban Yönetimi</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Hedef (UID veya IP)</label>
          <input type="text" id="banTarget" placeholder="User ID veya IP adresi">
        </div>
        <div class="form-group" style="max-width: 130px;">
          <label>Tip</label>
          <select id="banType">
            <option value="user">User</option>
            <option value="ip">IP</option>
          </select>
        </div>
        <button class="btn btn-danger" onclick="banTarget()">Banla</button>
        <button class="btn btn-secondary" onclick="unbanTarget()">Unban</button>
      </div>
      <div class="result-box" id="banResult"></div>
    </div>

    <!-- Rate Limiting -->
    <div class="card">
      <h2>⏱ Rate Limiting</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Firebase UID</label>
          <input type="text" id="rlUid" placeholder="Kullanıcı ID (boş bırakırsan genel limiti görürsün)">
        </div>
        <div class="form-group" style="max-width: 120px;">
          <label>Limit / Saat</label>
          <input type="number" id="rlLimit" value="15" min="-1" placeholder="0=engelle, -1=kaldır">
        </div>
        <button class="btn btn-primary" onclick="setUserRateLimit()">Uygula</button>
        <button class="btn btn-secondary" onclick="getUserRateLimit()">Sorgula</button>
      </div>
      <div style="font-size: 11px; color: #666; margin-top: 4px;">0 = tamamen engelle &middot; -1 = override kaldır (genel limite dön)</div>
      <div class="result-box" id="rlResult"></div>
    </div>

    <!-- A/B Test Whitelist -->
    <div class="card">
      <h2>🧪 A/B Test Whitelist</h2>
      <div class="form-row">
        <div class="form-group">
          <label>Firebase UID</label>
          <input type="text" id="abtestUid" placeholder="Kredi düşmeden test yapacak kullanıcı ID">
        </div>
        <button class="btn btn-success" onclick="setABTest(true)">Ekle</button>
        <button class="btn btn-danger" onclick="setABTest(false)">Kaldır</button>
        <button class="btn btn-secondary" onclick="getABTest()">Sorgula</button>
      </div>
      <div style="font-size: 11px; color: #666; margin-top: 4px;">Whitelisted kullanıcılar ab_test=true gönderince kredi düşmez. Diğer herkes için ab_test parametresi yok sayılır.</div>
      <div class="result-box" id="abtestResult"></div>
    </div>

    <!-- Server Config -->
    <div class="card">
      <h2>⚙️ Sunucu Ayarları</h2>
      <div id="configLoading" style="color: #666; font-size: 13px;">Yükleniyor...</div>
      <div id="configToggles" style="display: none;">
        <div class="toggle-row">
          <div class="toggle-label">
            Uygulama Aktif
            <small>Kapatırsan tüm kullanıcılar engellenir</small>
          </div>
          <label class="toggle-switch">
            <input type="checkbox" id="toggleAppEnabled" onchange="updateConfig('DISABLE_APP', !this.checked)">
            <span class="slider"></span>
          </label>
        </div>
        <div class="toggle-row">
          <div class="toggle-label">
            Model Foto Üretimi
            <small>Selfie'den tam boy model fotoğrafı üretme</small>
          </div>
          <label class="toggle-switch">
            <input type="checkbox" id="toggleModelPhoto" onchange="updateConfig('DISABLE_MODEL_PHOTO', !this.checked)">
            <span class="slider"></span>
          </label>
        </div>
        <div class="toggle-row">
          <div class="toggle-label">
            Debug Mode
            <small>Detaylı hata mesajları</small>
          </div>
          <label class="toggle-switch">
            <input type="checkbox" id="toggleDebug" onchange="updateConfig('IS_DEBUG', this.checked ? 'true' : 'false')">
            <span class="slider"></span>
          </label>
        </div>
        <div class="toggle-row">
          <div class="toggle-label">
            Genel Rate Limit
            <small>Kullanıcı başına saatlik AI istek limiti</small>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <input type="number" id="rateLimitInput" min="1" max="100" value="15" style="width: 60px; padding: 6px 10px; background: #222; border: 1px solid #444; border-radius: 6px; color: #fff; font-size: 14px; text-align: center;">
            <button class="btn btn-primary" style="padding: 6px 12px;" onclick="updateConfig('RATE_LIMIT_PER_HOUR', document.getElementById('rateLimitInput').value)">Kaydet</button>
          </div>
        </div>
        <div class="toggle-row">
          <div class="toggle-label">
            Haftalık Ücretsiz Kredi
            <small>Kullanıcılara haftada verilen ücretsiz kredi (1-10)</small>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <input type="number" id="freeCreditsInput" min="0" max="10" value="3" style="width: 60px; padding: 6px 10px; background: #222; border: 1px solid #444; border-radius: 6px; color: #fff; font-size: 14px; text-align: center;">
            <button class="btn btn-primary" style="padding: 6px 12px;" onclick="updateConfig('FREE_WEEKLY_CREDITS', document.getElementById('freeCreditsInput').value)">Kaydet</button>
          </div>
        </div>
        <div class="toggle-row">
          <div class="toggle-label">
            Pro Haftalık Kredi
            <small>Pro abonelere haftada verilen kredi (10-100)</small>
          </div>
          <div style="display: flex; align-items: center; gap: 8px;">
            <input type="number" id="proCreditsInput" min="10" max="100" value="50" style="width: 60px; padding: 6px 10px; background: #222; border: 1px solid #444; border-radius: 6px; color: #fff; font-size: 14px; text-align: center;">
            <button class="btn btn-primary" style="padding: 6px 12px;" onclick="updateConfig('PRO_WEEKLY_CREDITS', document.getElementById('proCreditsInput').value)">Kaydet</button>
          </div>
        </div>
        <div style="margin-top: 16px;">
          <div class="form-group">
            <label>Bakım Mesajı (boş bırakırsan kapalı)</label>
            <input type="text" id="maintenanceMsg" placeholder="Uygulama bakımda, lütfen daha sonra tekrar dene">
          </div>
          <button class="btn btn-primary" style="margin-top: 8px;" onclick="updateConfig('MAINTENANCE_MESSAGE', document.getElementById('maintenanceMsg').value)">Mesajı Kaydet</button>
        </div>
      </div>
    </div>

    <!-- Usage Dashboard -->
    <div class="card">
      <h2>📊 Kullanım Dashboard</h2>
      <div class="stats-grid" id="statsGrid">
        <div class="stat-item"><div class="num" id="statToday">-</div><div class="lbl">Bugün</div></div>
        <div class="stat-item"><div class="num" id="statWeekly">-</div><div class="lbl">Bu Hafta</div></div>
        <div class="stat-item"><div class="num" id="statActiveUsers">-</div><div class="lbl">Aktif User</div></div>
        <div class="stat-item"><div class="num" id="statAvgPerUser">-</div><div class="lbl">Ort/User</div></div>
        <div class="stat-item"><div class="num" id="statWeeklyCost">-</div><div class="lbl">Haftalık Maliyet</div></div>
        <div class="stat-item"><div class="num" id="statBannedIPs">-</div><div class="lbl">Banlı IP</div></div>
        <div class="stat-item"><div class="num" id="statBannedUsers">-</div><div class="lbl">Banlı User</div></div>
      </div>
      <div id="topUsersBox" style="display:none; margin-top: 16px;">
        <h3 style="font-size: 13px; color: #888; margin-bottom: 8px;">🔥 Top Kullanıcılar (Bu Hafta)</h3>
        <table style="width:100%; font-size: 13px; border-collapse: collapse;">
          <thead><tr style="color: #888; border-bottom: 1px solid #333;"><th style="text-align:left; padding: 4px 8px;">#</th><th style="text-align:left; padding: 4px 8px;">User ID</th><th style="text-align:right; padding: 4px 8px;">Kredi</th></tr></thead>
          <tbody id="topUsersBody"></tbody>
        </table>
      </div>
      <button class="btn btn-secondary" style="margin-top: 12px;" onclick="fetchStats()">Yenile</button>
    </div>

    <!-- Trend Collections -->
    <div class="card">
      <h2>🔥 Trend Koleksiyonları</h2>

      <!-- Create Form -->
      <div style="margin-bottom: 20px;">
        <div class="form-row">
          <div class="form-group">
            <label>Kategori</label>
            <select id="trendCategory">
              <option value="casual">Casual</option>
              <option value="elegant">Elegant</option>
              <option value="streetwear">Streetwear</option>
              <option value="sporty">Sporty</option>
              <option value="bohemian">Bohemian</option>
              <option value="minimal">Minimal</option>
            </select>
          </div>
          <div class="form-group">
            <label>Cinsiyet</label>
            <select id="trendGender">
              <option value="female">Kadın</option>
              <option value="male">Erkek</option>
              <option value="unisex">Unisex</option>
            </select>
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Etiketler (virgülle ayır)</label>
            <input type="text" id="trendTags" placeholder="spring, pastel, office">
          </div>
          <div class="form-group">
            <label>Sıra No</label>
            <input type="number" id="trendSortOrder" value="0" min="0" style="width: 80px;">
          </div>
        </div>
        <div class="form-row">
          <div class="form-group">
            <label>Görseller (dosya seç veya yapıştır)</label>
            <input type="file" id="trendImages" multiple accept="image/*" style="padding: 8px;">
          </div>
        </div>
        <div id="trendPasteZone" style="border: 2px dashed #444; border-radius: 10px; padding: 20px; text-align: center; cursor: pointer; margin-bottom: 12px; transition: border-color 0.2s;" tabindex="0">
          <div style="color: #888; font-size: 13px;">📋 Görselleri buraya yapıştır (Ctrl+V / Cmd+V)</div>
          <div id="trendPastedPreview" style="display: flex; flex-wrap: wrap; gap: 8px; margin-top: 10px; justify-content: center;"></div>
        </div>
        <div class="form-row" style="align-items: center;">
          <button class="btn btn-primary" id="trendCreateBtn" onclick="createTrend()">Oluştur</button>
          <button class="btn btn-secondary" onclick="clearPastedImages()" style="margin-left: 8px;">Temizle</button>
        </div>
        <div id="trendUploadProgress" style="display:none; margin-top: 8px; font-size: 13px; color: #C9A962;">Yükleniyor...</div>
      </div>

      <!-- Trend List -->
      <div id="trendList" style="margin-top: 16px;"></div>
      <button class="btn btn-secondary" style="margin-top: 12px;" onclick="loadTrends()">Yenile</button>
    </div>

  </div>
</div>

<div class="toast" id="toast"></div>

<script>
const BASE = location.origin;
let ADMIN_KEY = '';

function doLogin() {
  ADMIN_KEY = document.getElementById('adminKeyInput').value.trim();
  if (!ADMIN_KEY) return;
  // Verify by fetching stats
  fetch(BASE + '/stats?key=' + encodeURIComponent(ADMIN_KEY))
    .then(r => { if (!r.ok) throw new Error('Invalid key'); return r.json(); })
    .then(() => {
      sessionStorage.setItem('ak', ADMIN_KEY);
      showDashboard();
    })
    .catch(() => toast('Geçersiz admin key', 'error'));
}

function doLogout() {
  ADMIN_KEY = '';
  sessionStorage.removeItem('ak');
  document.getElementById('dashboard').style.display = 'none';
  document.getElementById('loginScreen').style.display = 'flex';
  document.getElementById('adminKeyInput').value = '';
}

function showDashboard() {
  document.getElementById('loginScreen').style.display = 'none';
  document.getElementById('dashboard').style.display = 'block';
  fetchStats();
  loadConfig();
  loadTrends();
}

// ── API helpers ──
async function adminFetch(path, opts = {}) {
  const sep = path.includes('?') ? '&' : '?';
  const url = BASE + path + sep + 'key=' + encodeURIComponent(ADMIN_KEY);
  const res = await fetch(url, {
    ...opts,
    headers: { 'Content-Type': 'application/json', ...(opts.headers || {}) },
  });
  return res;
}

// ── User Lookup ──
function renderUserInfo(u, uid) {
  let html = '<div class="user-info-grid">';
  const fields = [
    ['UID', uid],
    ['Email', u.email || '-'],
    ['Display Name', u.displayName || '-'],
    ['Gender', u.gender || '-'],
    ['Age Range', u.ageRange || '-'],
    ['Free Credits', u.credits ?? 0],
    ['Purchased Credits', u.purchasedCredits ?? 0],
    ['Pro Credits', u.proCredits ?? 0],
    ['Total', (u.credits || 0) + (u.purchasedCredits || 0) + (u.proCredits || 0)],
    ['Is Pro', u.isPro ? '✅ Yes' : '❌ No'],
    ['Weekly Reset', u.weeklyCreditsLastReset ? new Date(u.weeklyCreditsLastReset).toLocaleDateString('tr') : '-'],
    ['Created', u.createdAt ? new Date(u.createdAt).toLocaleDateString('tr') : '-'],
    ['Model Photo Count', u.modelPhotoGenCount ?? 0],
    ['Referral Code', u.referralCode || '-'],
    ['Style Preferences', (u.stylePreferences || []).join(', ') || '-'],
    ['This Week Usage', u.weeklyCreditsUsed ?? 0],
    ['Total Try-Ons', u.totalCreditsUsed ?? 0],
  ];
  fields.forEach(([k, v]) => { html += '<div class="user-info-item"><div class="key">' + k + '</div><div class="val">' + v + '</div></div>'; });
  html += '</div>';
  return html;
}

async function fetchUser() {
  const uid = document.getElementById('lookupUid').value.trim();
  if (!uid) return toast('UID veya e-posta girin', 'error');
  const box = document.getElementById('userResult');
  box.classList.add('visible');
  box.innerHTML = 'Yükleniyor...';
  try {
    const res = await adminFetch('/admin/user/' + encodeURIComponent(uid));
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    if (data.users) {
      // Multiple results (search)
      if (data.count === 0) { box.innerHTML = '<span class="error">Kullanıcı bulunamadı</span>'; return; }
      let html = '<div style="margin-bottom:8px;color:#888;">' + data.count + ' sonuç bulundu</div>';
      data.users.forEach(u => { html += renderUserInfo(u, u._uid); html += '<hr style="border-color:#333;margin:12px 0;">'; });
      box.innerHTML = html;
      if (data.count === 1) document.getElementById('creditUid').value = data.users[0]._uid;
    } else if (!data.user) {
      box.innerHTML = '<span class="error">Kullanıcı bulunamadı</span>';
    } else {
      const resolvedUid = data.uid || uid;
      box.innerHTML = renderUserInfo(data.user, resolvedUid);
      document.getElementById('creditUid').value = resolvedUid;
    }
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

async function searchByName() {
  const name = document.getElementById('lookupName').value.trim();
  if (!name) return toast('İsim girin', 'error');
  const box = document.getElementById('userResult');
  box.classList.add('visible');
  box.innerHTML = 'Aranıyor...';
  try {
    const res = await adminFetch('/admin/search?field=displayName&q=' + encodeURIComponent(name));
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    if (data.user) {
      box.innerHTML = renderUserInfo(data.user, data.uid);
      document.getElementById('creditUid').value = data.uid;
    } else if (data.users && data.count > 0) {
      let html = '<div style="margin-bottom:8px;color:#888;">' + data.count + ' sonuç bulundu</div>';
      data.users.forEach(u => { html += renderUserInfo(u, u._uid); html += '<hr style="border-color:#333;margin:12px 0;">'; });
      box.innerHTML = html;
    } else {
      box.innerHTML = '<span class="error">Kullanıcı bulunamadı</span>';
    }
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

// ── Credits ──
async function updateCredits() {
  const uid = document.getElementById('creditUid').value.trim();
  const action = document.getElementById('creditAction').value;
  const type = document.getElementById('creditType').value;
  const amount = parseInt(document.getElementById('creditAmount').value, 10);
  if (!uid) return toast('UID girin', 'error');
  if (isNaN(amount) || amount < 0) return toast('Geçerli miktar girin', 'error');
  const box = document.getElementById('creditResult');
  box.classList.add('visible');
  box.innerHTML = 'İşleniyor...';
  try {
    const res = await adminFetch('/admin/credits', {
      method: 'POST',
      body: JSON.stringify({ uid, action, type, amount }),
    });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = '<span class="success">✓ ' + data.message + '</span>';
    toast('Kredi güncellendi', 'success');
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

// ── Ban ──
async function banTarget() {
  const target = document.getElementById('banTarget').value.trim();
  const type = document.getElementById('banType').value;
  if (!target) return toast('Hedef girin', 'error');
  const box = document.getElementById('banResult');
  box.classList.add('visible');
  box.innerHTML = 'İşleniyor...';
  try {
    const res = await adminFetch('/admin/ban', { method: 'POST', body: JSON.stringify({ target, type }) });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = '<span class="success">✓ ' + data.message + '</span>';
    toast('Banlandı', 'success');
    fetchStats();
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

async function unbanTarget() {
  const target = document.getElementById('banTarget').value.trim();
  const type = document.getElementById('banType').value;
  if (!target) return toast('Hedef girin', 'error');
  const box = document.getElementById('banResult');
  box.classList.add('visible');
  box.innerHTML = 'İşleniyor...';
  try {
    const res = await adminFetch('/admin/unban', { method: 'POST', body: JSON.stringify({ target, type }) });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = '<span class="success">✓ ' + data.message + '</span>';
    toast('Unban yapıldı', 'success');
    fetchStats();
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

// ── Config ──
async function loadConfig() {
  try {
    const res = await adminFetch('/admin/config');
    if (!res.ok) throw new Error('Config yüklenemedi');
    const data = await res.json();
    document.getElementById('toggleAppEnabled').checked = data.appEnabled !== false;
    document.getElementById('toggleModelPhoto').checked = data.modelPhotoEnabled !== false;
    document.getElementById('toggleDebug').checked = data.debugMode === true;
    document.getElementById('freeCreditsInput').value = data.freeWeeklyCredits ?? 3;
    document.getElementById('proCreditsInput').value = data.proWeeklyCredits ?? 50;
    document.getElementById('rateLimitInput').value = data.rateLimitPerHour ?? 15;
    document.getElementById('rlLimit').value = data.rateLimitPerHour ?? 15;
    document.getElementById('maintenanceMsg').value = data.maintenanceMessage || '';
    document.getElementById('configLoading').style.display = 'none';
    document.getElementById('configToggles').style.display = 'block';
  } catch (e) {
    document.getElementById('configLoading').textContent = 'Config yüklenemedi: ' + e.message;
  }
}

async function updateConfig(key, value) {
  try {
    const res = await adminFetch('/admin/config', {
      method: 'POST',
      body: JSON.stringify({ key, value: String(value) }),
    });
    if (!res.ok) throw new Error(await res.text());
    toast('Ayar güncellendi', 'success');
  } catch (e) {
    toast('Hata: ' + e.message, 'error');
    loadConfig(); // revert UI
  }
}

// ── Rate Limit ──
async function setUserRateLimit() {
  const uid = document.getElementById('rlUid').value.trim();
  const limit = parseInt(document.getElementById('rlLimit').value, 10);
  if (!uid) {
    // No UID = update global limit
    await updateConfig('RATE_LIMIT_PER_HOUR', String(limit));
    return;
  }
  const box = document.getElementById('rlResult');
  box.classList.add('visible');
  box.innerHTML = 'İşleniyor...';
  try {
    const res = await adminFetch('/admin/ratelimit', {
      method: 'POST',
      body: JSON.stringify({ uid, limit }),
    });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = '<span class="success">✓ ' + data.message + '</span>';
    toast('Rate limit güncellendi', 'success');
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

async function getUserRateLimit() {
  const uid = document.getElementById('rlUid').value.trim();
  if (!uid) return toast('UID girin', 'error');
  const box = document.getElementById('rlResult');
  box.classList.add('visible');
  box.innerHTML = 'Yükleniyor...';
  try {
    const res = await adminFetch('/admin/ratelimit/' + encodeURIComponent(uid));
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    let html = '<div class="user-info-grid">';
    const fields = [
      ['Genel Limit', data.globalLimit + '/saat'],
      ['User Override', data.userOverride !== null ? data.userOverride + '/saat' : 'Yok (genel)'],
      ['Aktif Limit', data.effectiveLimit + '/saat'],
      ['Bu Saat Kullanım', data.usageThisHour],
      ['Kalan', data.remaining],
    ];
    fields.forEach(([k, v]) => { html += '<div class="user-info-item"><div class="key">' + k + '</div><div class="val">' + v + '</div></div>'; });
    html += '</div>';
    box.innerHTML = html;
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

// ── A/B Test Whitelist ──
async function setABTest(enabled) {
  const uid = document.getElementById('abtestUid').value.trim();
  if (!uid) return toast('UID girin', 'error');
  const box = document.getElementById('abtestResult');
  box.classList.add('visible');
  box.innerHTML = 'İşleniyor...';
  try {
    const res = await adminFetch('/admin/abtest', {
      method: 'POST',
      body: JSON.stringify({ uid, enabled }),
    });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = '<span class="success">✓ ' + data.message + '</span>';
    toast(enabled ? 'Kullanıcı whitelist\\'e eklendi' : 'Kullanıcı whitelist\\'ten kaldırıldı', 'success');
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

async function getABTest() {
  const uid = document.getElementById('abtestUid').value.trim();
  if (!uid) return toast('UID girin', 'error');
  const box = document.getElementById('abtestResult');
  box.classList.add('visible');
  box.innerHTML = 'Yükleniyor...';
  try {
    const res = await adminFetch('/admin/abtest/' + encodeURIComponent(uid));
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    box.innerHTML = data.whitelisted
      ? '<span class="success">✓ Bu kullanıcı whitelist\\'te — ab_test=true ile kredi düşmez</span>'
      : '<span class="label">✗ Bu kullanıcı whitelist\\'te DEĞİL — normal kredi düşer</span>';
  } catch (e) {
    box.innerHTML = '<span class="error">' + e.message + '</span>';
  }
}

// ── Trends ──
let pastedImages = [];

// Paste zone event listeners
document.addEventListener('DOMContentLoaded', () => {
  const pasteZone = document.getElementById('trendPasteZone');
  if (!pasteZone) return;

  // Cmd+V / Ctrl+V paste handler (on the zone itself)
  pasteZone.addEventListener('paste', handlePaste);
  // Also listen globally so paste works anywhere on page
  document.addEventListener('paste', (e) => {
    // Only handle if dashboard is visible and paste zone exists
    if (document.getElementById('dashboard').style.display !== 'none') {
      handlePaste(e);
    }
  });

  // Drag & drop support
  pasteZone.addEventListener('dragover', (e) => { e.preventDefault(); pasteZone.style.borderColor = '#C9A962'; });
  pasteZone.addEventListener('dragleave', () => { pasteZone.style.borderColor = '#444'; });
  pasteZone.addEventListener('drop', (e) => {
    e.preventDefault();
    pasteZone.style.borderColor = '#444';
    if (e.dataTransfer.files) {
      for (const file of e.dataTransfer.files) {
        if (file.type.startsWith('image/')) pastedImages.push(file);
      }
      renderPastedPreviews();
    }
  });
});

function handlePaste(e) {
  const items = e.clipboardData && e.clipboardData.items;
  if (!items) return;
  let found = false;
  for (const item of items) {
    if (item.type.startsWith('image/')) {
      const file = item.getAsFile();
      if (file) { pastedImages.push(file); found = true; }
    }
  }
  if (found) {
    e.preventDefault();
    renderPastedPreviews();
  }
}

function renderPastedPreviews() {
  const preview = document.getElementById('trendPastedPreview');
  preview.innerHTML = '';
  pastedImages.forEach((file, idx) => {
    const url = URL.createObjectURL(file);
    const wrapper = document.createElement('div');
    wrapper.style.cssText = 'position:relative; display:inline-block;';
    wrapper.innerHTML = '<img src="' + url + '" style="width:60px; height:60px; object-fit:cover; border-radius:6px; border:1px solid #444;">'
      + '<div onclick="removePastedImage(' + idx + ')" style="position:absolute; top:-6px; right:-6px; width:18px; height:18px; background:#B94A48; border-radius:50%; color:#fff; font-size:11px; display:flex; align-items:center; justify-content:center; cursor:pointer;">✕</div>';
    preview.appendChild(wrapper);
  });
}

function removePastedImage(idx) {
  pastedImages.splice(idx, 1);
  renderPastedPreviews();
}

function clearPastedImages() {
  pastedImages = [];
  renderPastedPreviews();
}

async function createTrend() {
  const category = document.getElementById('trendCategory').value;
  const gender = document.getElementById('trendGender').value;
  const tags = document.getElementById('trendTags').value.trim();
  const sortOrder = document.getElementById('trendSortOrder').value;
  const filesInput = document.getElementById('trendImages');

  // Combine file input + pasted images
  const fileInputFiles = filesInput.files ? Array.from(filesInput.files) : [];
  const allFiles = [...fileInputFiles, ...pastedImages];

  if (allFiles.length === 0) return toast('En az 1 görsel seçin veya yapıştırın', 'error');

  const btn = document.getElementById('trendCreateBtn');
  const progress = document.getElementById('trendUploadProgress');
  btn.disabled = true;
  progress.style.display = 'block';
  progress.textContent = 'Yükleniyor... (' + allFiles.length + ' görsel)';

  try {
    const formData = new FormData();
    formData.append('category', category);
    formData.append('gender', gender);
    formData.append('tags', tags);
    formData.append('sortOrder', sortOrder);

    for (let i = 0; i < allFiles.length; i++) {
      formData.append('image_' + i, allFiles[i]);
    }

    const sep = '/admin/trends'.includes('?') ? '&' : '?';
    const url = BASE + '/admin/trends' + sep + 'key=' + encodeURIComponent(ADMIN_KEY);
    const res = await fetch(url, { method: 'POST', body: formData });
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    toast(data.message || 'Koleksiyon oluşturuldu', 'success');

    // Clear form
    document.getElementById('trendTags').value = '';
    filesInput.value = '';
    pastedImages = [];
    renderPastedPreviews();
    loadTrends();
  } catch (e) {
    toast('Hata: ' + e.message, 'error');
  } finally {
    btn.disabled = false;
    progress.style.display = 'none';
  }
}

async function loadTrends() {
  const container = document.getElementById('trendList');
  container.innerHTML = '<div style="color: #888; font-size: 13px;">Yükleniyor...</div>';
  try {
    const res = await adminFetch('/admin/trends');
    if (!res.ok) throw new Error(await res.text());
    const data = await res.json();
    const collections = data.collections || [];

    if (collections.length === 0) {
      container.innerHTML = '<div style="color: #666; font-size: 13px;">Henüz koleksiyon yok</div>';
      return;
    }

    let html = '<table style="width:100%; font-size: 13px; border-collapse: collapse;">';
    html += '<thead><tr style="color: #888; border-bottom: 1px solid #333;">';
    html += '<th style="text-align:left; padding: 6px 8px;">Önizleme</th>';
    html += '<th style="text-align:left; padding: 6px 8px;">Kategori</th>';
    html += '<th style="text-align:left; padding: 6px 8px;">Cinsiyet</th>';
    html += '<th style="text-align:center; padding: 6px 8px;">Görsel</th>';
    html += '<th style="text-align:center; padding: 6px 8px;">Durum</th>';
    html += '<th style="text-align:right; padding: 6px 8px;">İşlem</th>';
    html += '</tr></thead><tbody>';

    collections.forEach(c => {
      const previewUrl = c.imageUrls && c.imageUrls.length > 0
        ? 'https://api.stilya.app/assets/' + c.imageUrls[0].replace('public/', '')
        : '';
      const statusColor = c.isActive ? '#2D5F3F' : '#666';
      const statusText = c.isActive ? 'Aktif' : 'Pasif';
      const toggleText = c.isActive ? 'Pasife Al' : 'Aktife Al';
      const toggleClass = c.isActive ? 'btn-secondary' : 'btn-success';

      html += '<tr style="border-bottom: 1px solid #222;">';
      html += '<td style="padding: 6px 8px;">';
      if (previewUrl) html += '<img src="' + previewUrl + '" style="width: 48px; height: 48px; object-fit: cover; border-radius: 6px;">';
      html += '</td>';
      html += '<td style="padding: 6px 8px;">' + (c.category || '-') + '</td>';
      html += '<td style="padding: 6px 8px;">' + (c.gender || '-') + '</td>';
      html += '<td style="text-align:center; padding: 6px 8px;">' + (c.imageUrls ? c.imageUrls.length : 0) + '</td>';
      html += '<td style="text-align:center; padding: 6px 8px; color: ' + statusColor + ';">' + statusText + '</td>';
      html += '<td style="text-align:right; padding: 6px 8px;">';
      html += '<button class="btn ' + toggleClass + '" style="font-size: 11px; padding: 4px 10px; margin-right: 4px;" onclick="toggleTrendActive(' + "'" + c.id + "'" + ', ' + !c.isActive + ')">' + toggleText + '</button>';
      html += '<button class="btn btn-danger" style="font-size: 11px; padding: 4px 10px;" onclick="deleteTrend(' + "'" + c.id + "'" + ')">Sil</button>';
      html += '</td>';
      html += '</tr>';
    });

    html += '</tbody></table>';
    container.innerHTML = html;
  } catch (e) {
    container.innerHTML = '<div style="color: #B94A48; font-size: 13px;">Hata: ' + e.message + '</div>';
  }
}

async function toggleTrendActive(id, isActive) {
  try {
    const sep = '/admin/trends/' + id;
    const url = BASE + sep + '?key=' + encodeURIComponent(ADMIN_KEY);
    const res = await fetch(url, {
      method: 'PUT',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ isActive }),
    });
    if (!res.ok) throw new Error(await res.text());
    toast(isActive ? 'Aktife alındı' : 'Pasife alındı', 'success');
    loadTrends();
  } catch (e) {
    toast('Hata: ' + e.message, 'error');
  }
}

async function deleteTrend(id) {
  if (!confirm('Bu koleksiyonu silmek istediğine emin misin?')) return;
  try {
    const url = BASE + '/admin/trends/' + id + '?key=' + encodeURIComponent(ADMIN_KEY);
    const res = await fetch(url, { method: 'DELETE' });
    if (!res.ok) throw new Error(await res.text());
    toast('Koleksiyon silindi', 'success');
    loadTrends();
  } catch (e) {
    toast('Hata: ' + e.message, 'error');
  }
}

// ── Stats ──
async function fetchStats() {
  try {
    const res = await adminFetch('/stats');
    if (!res.ok) return;
    const data = await res.json();
    document.getElementById('statBannedIPs').textContent = data.bannedIPs ?? 0;
    document.getElementById('statBannedUsers').textContent = data.bannedUsers ?? 0;

    const u = data.usage || {};
    document.getElementById('statToday').textContent = u.today ?? 0;
    document.getElementById('statWeekly').textContent = u.thisWeek ?? 0;
    document.getElementById('statActiveUsers').textContent = u.activeUsersThisWeek ?? 0;
    document.getElementById('statAvgPerUser').textContent = u.avgCreditsPerUser ?? 0;
    document.getElementById('statWeeklyCost').textContent = '$' + (u.estWeeklyCostUSD ?? 0);

    // Top users table
    const topBox = document.getElementById('topUsersBox');
    const tbody = document.getElementById('topUsersBody');
    tbody.innerHTML = '';
    if (u.topUsers && u.topUsers.length > 0) {
      topBox.style.display = 'block';
      u.topUsers.forEach((t, i) => {
        const tr = document.createElement('tr');
        tr.style.borderBottom = '1px solid #222';
        const warn = t.used >= 40 ? ' style="color: #B94A48;"' : t.used >= 25 ? ' style="color: #F57C00;"' : '';
        tr.innerHTML = '<td style="padding: 4px 8px; color: #666;">' + (i+1) + '</td>'
          + '<td style="padding: 4px 8px; font-family: monospace; font-size: 11px;">'
          + '<span style="user-select: all;">' + t.uid + '</span>'
          + '<button onclick="copyUid(this,\\x27' + t.uid + '\\x27)" style="background:none;border:none;cursor:pointer;margin-left:6px;font-size:12px;padding:2px;">📋</button>'
          + '</td>'
          + '<td style="text-align: right; padding: 4px 8px;"' + warn + '>' + t.used + '</td>';
        tbody.appendChild(tr);
      });
    } else {
      topBox.style.display = 'none';
    }
  } catch (e) {}
}

// ── Copy UID helper ──
function copyUid(btn, uid) {
  navigator.clipboard.writeText(uid);
  btn.textContent = '✓';
  setTimeout(() => btn.textContent = '📋', 1000);
}

// ── Toast ──
function toast(msg, type) {
  const el = document.getElementById('toast');
  el.textContent = msg;
  el.className = 'toast ' + type + ' show';
  setTimeout(() => el.classList.remove('show'), 3000);
}

// Auto-login from session
(function() {
  const saved = sessionStorage.getItem('ak');
  if (saved) { ADMIN_KEY = saved; showDashboard(); }
  // Enter key on login
  document.getElementById('adminKeyInput').addEventListener('keydown', e => { if (e.key === 'Enter') doLogin(); });
})();
</script>
</body>
</html>`;
