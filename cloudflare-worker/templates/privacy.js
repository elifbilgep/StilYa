import { LEGAL_PAGE_STYLE } from './legal-style.js';

export const PRIVACY_POLICY_HTML = `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Gizlilik Politikası — STILYA</title>
  ${LEGAL_PAGE_STYLE}
  <script>
    function switchLang(lang) {
      document.querySelectorAll('.lang-tr').forEach(el => el.classList.toggle('visible', lang === 'tr'));
      document.querySelectorAll('.lang-en').forEach(el => el.classList.toggle('visible', lang === 'en'));
      document.querySelectorAll('.lang-switch button').forEach(b => b.classList.toggle('active', b.dataset.lang === lang));
      document.documentElement.lang = lang;
    }
  </script>
</head>
<body>
  <div class="container">
    <div class="lang-switch">
      <button class="active" data-lang="tr" onclick="switchLang('tr')">TR</button>
      <button data-lang="en" onclick="switchLang('en')">EN</button>
    </div>

    <div class="logo">STILYA</div>
    <div class="subtitle lang-tr visible">Satın almadan önce dene</div>
    <div class="subtitle lang-en">Try before you buy</div>

    <!-- TR -->
    <div class="lang-tr visible">
      <h1>Gizlilik Politikası</h1>
      <p class="date">Son güncelleme: 26 Şubat 2026</p>

      <p>STILYA ("biz", "uygulama") olarak gizliliğinize saygı duyuyor ve kişisel verilerinizi korumayı taahhüt ediyoruz. Bu politika, uygulamamızı kullanırken hangi verilerin toplandığını, nasıl kullanıldığını ve nasıl korunduğunu açıklar.</p>

      <h2>1. Toplanan Veriler</h2>
      <p>Uygulamamız aşağıdaki verileri toplar:</p>
      <ul>
        <li><strong>Hesap bilgileri:</strong> Ad, e-posta adresi (Apple veya Google ile giriş yapıldığında)</li>
        <li><strong>Fotoğraflar:</strong> Model fotoğrafınız ve kıyafet fotoğrafları (sanal deneme için)</li>
        <li><strong>Kullanım verileri:</strong> Kredi kullanımı, deneme sayısı, abonelik durumu</li>
        <li><strong>Cihaz bilgileri:</strong> Cihaz türü, işletim sistemi versiyonu (hata ayıklama için)</li>
      </ul>

      <h2>2. Verilerin Kullanımı</h2>
      <p>Topladığımız verileri şu amaçlarla kullanırız:</p>
      <ul>
        <li>Sanal kıyafet deneme hizmetini sunmak</li>
        <li>Hesabınızı yönetmek ve kredi sisteminizi takip etmek</li>
        <li>Abonelik ve satın alma işlemlerini yönetmek</li>
        <li>Uygulama performansını iyileştirmek</li>
        <li>Teknik sorunları tespit etmek ve gidermek</li>
      </ul>

      <h2>3. Fotoğraf Güvenliği (Uçtan Uca Şifreleme)</h2>
      <p>Fotoğraflarınız cihazınızda <strong>AES-256-GCM</strong> algoritması ile şifrelenir ve sunucularımıza yalnızca şifrelenmiş halde yüklenir. Bu sayede:</p>
      <ul>
        <li>Fotoğraflarınızı biz dahil kimse göremez</li>
        <li>Sunucularımız ele geçirilse dahi fotoğraflarınız okunamaz</li>
        <li>Şifreleme anahtarı yalnızca sizin cihazınızda (iOS Keychain) saklanır</li>
        <li>Yalnızca siz, kendi cihazınızda fotoğraflarınızı görüntüleyebilirsiniz</li>
      </ul>

      <h2>4. Yapay Zeka İşleme</h2>
      <p>Sanal deneme için fotoğraflarınız üçüncü taraf yapay zeka hizmetine (fal.ai) geçici olarak gönderilir. Bu işlem sırasında:</p>
      <ul>
        <li>Fotoğraflar yalnızca deneme sonucu üretmek için kullanılır</li>
        <li>İşlem tamamlandıktan sonra üçüncü taraf sunucularında saklanmaz</li>
        <li>Yapay zeka modeli eğitimi için kullanılmaz</li>
      </ul>

      <h2>5. Üçüncü Taraf Hizmetler</h2>
      <p>Uygulamamız aşağıdaki üçüncü taraf hizmetleri kullanır:</p>
      <ul>
        <li><strong>Firebase (Google):</strong> Kimlik doğrulama, veritabanı, analitik</li>
        <li><strong>Cloudflare:</strong> İçerik dağıtımı ve depolama</li>
        <li><strong>RevenueCat:</strong> Abonelik ve satın alma yönetimi</li>
        <li><strong>fal.ai:</strong> Yapay zeka görüntü işleme</li>
      </ul>

      <h2>6. Veri Saklama ve Silme</h2>
      <p>Verileriniz hesabınız aktif olduğu sürece saklanır. Hesabınızı sildiğinizde:</p>
      <ul>
        <li>Tüm fotoğraflarınız kalıcı olarak silinir</li>
        <li>Hesap bilgileriniz kaldırılır</li>
        <li>Şifreleme anahtarınız cihazınızdan silinir</li>
      </ul>
      <p>Hesabınızı silmek için uygulama içinden Profil > Hesabı Sil seçeneğini kullanabilirsiniz.</p>

      <h2>7. Çocukların Gizliliği</h2>
      <p>Uygulamamız 13 yaşın altındaki çocuklara yönelik değildir. Bilerek 13 yaşın altındaki bireylerden kişisel veri toplamayız.</p>

      <h2>8. Haklarınız</h2>
      <p>6698 sayılı Kişisel Verilerin Korunması Kanunu (KVKK) ve geçerli mevzuat kapsamında aşağıdaki haklara sahipsiniz:</p>
      <ul>
        <li>Verilerinize erişim talep etme</li>
        <li>Verilerinizin düzeltilmesini isteme</li>
        <li>Verilerinizin silinmesini talep etme</li>
        <li>Veri işlemeye itiraz etme</li>
      </ul>

      <h2>9. Değişiklikler</h2>
      <p>Bu gizlilik politikasını zaman zaman güncelleyebiliriz. Önemli değişiklikler uygulama içinden bildirilecektir.</p>

      <h2>10. İletişim</h2>
      <p>Gizlilikle ilgili sorularınız için bize ulaşabilirsiniz:</p>
      <p>E-posta: <a href="mailto:support@stilya.app">support@stilya.app</a></p>
    </div>

    <!-- EN -->
    <div class="lang-en">
      <h1>Privacy Policy</h1>
      <p class="date">Last updated: February 26, 2026</p>

      <p>At STILYA ("we", "app"), we respect your privacy and are committed to protecting your personal data. This policy explains what data is collected, how it is used, and how it is protected when you use our app.</p>

      <h2>1. Data We Collect</h2>
      <p>Our app collects the following data:</p>
      <ul>
        <li><strong>Account information:</strong> Name, email address (when signing in with Apple or Google)</li>
        <li><strong>Photos:</strong> Your model photo and garment photos (for virtual try-on)</li>
        <li><strong>Usage data:</strong> Credit usage, number of try-ons, subscription status</li>
        <li><strong>Device information:</strong> Device type, operating system version (for debugging)</li>
      </ul>

      <h2>2. How We Use Your Data</h2>
      <p>We use the collected data for the following purposes:</p>
      <ul>
        <li>Providing the virtual garment try-on service</li>
        <li>Managing your account and tracking your credit balance</li>
        <li>Managing subscriptions and purchases</li>
        <li>Improving app performance</li>
        <li>Identifying and resolving technical issues</li>
      </ul>

      <h2>3. Photo Security (End-to-End Encryption)</h2>
      <p>Your photos are encrypted on your device using <strong>AES-256-GCM</strong> encryption and are only uploaded to our servers in encrypted form. This means:</p>
      <ul>
        <li>No one, including us, can view your photos</li>
        <li>Even if our servers are compromised, your photos cannot be read</li>
        <li>The encryption key is stored only on your device (iOS Keychain)</li>
        <li>Only you can view your photos on your own device</li>
      </ul>

      <h2>4. AI Processing</h2>
      <p>For virtual try-on, your photos are temporarily sent to a third-party AI service (fal.ai). During this process:</p>
      <ul>
        <li>Photos are used solely to generate try-on results</li>
        <li>They are not stored on third-party servers after processing is complete</li>
        <li>They are not used to train AI models</li>
      </ul>

      <h2>5. Third-Party Services</h2>
      <p>Our app uses the following third-party services:</p>
      <ul>
        <li><strong>Firebase (Google):</strong> Authentication, database, analytics</li>
        <li><strong>Cloudflare:</strong> Content delivery and storage</li>
        <li><strong>RevenueCat:</strong> Subscription and purchase management</li>
        <li><strong>fal.ai:</strong> AI image processing</li>
      </ul>

      <h2>6. Data Retention and Deletion</h2>
      <p>Your data is retained as long as your account is active. When you delete your account:</p>
      <ul>
        <li>All your photos are permanently deleted</li>
        <li>Your account information is removed</li>
        <li>Your encryption key is deleted from your device</li>
      </ul>
      <p>To delete your account, go to Profile > Delete Account within the app.</p>

      <h2>7. Children's Privacy</h2>
      <p>Our app is not intended for children under 13 years of age. We do not knowingly collect personal data from individuals under 13.</p>

      <h2>8. Your Rights</h2>
      <p>Under applicable data protection laws, you have the following rights:</p>
      <ul>
        <li>Request access to your data</li>
        <li>Request correction of your data</li>
        <li>Request deletion of your data</li>
        <li>Object to data processing</li>
      </ul>

      <h2>9. Changes</h2>
      <p>We may update this privacy policy from time to time. Significant changes will be communicated through the app.</p>

      <h2>10. Contact</h2>
      <p>For privacy-related questions, you can reach us at:</p>
      <p>Email: <a href="mailto:support@stilya.app">support@stilya.app</a></p>
    </div>

    <div class="footer">
      <p class="lang-tr visible">&copy; 2026 STILYA. Tüm hakları saklıdır.</p>
      <p class="lang-en">&copy; 2026 STILYA. All rights reserved.</p>
      <div class="nav">
        <a href="/privacy" class="lang-tr visible">Gizlilik Politikası</a>
        <a href="/privacy" class="lang-en">Privacy Policy</a>
        <a href="/terms" class="lang-tr visible">Kullanım Koşulları</a>
        <a href="/terms" class="lang-en">Terms of Use</a>
      </div>
    </div>
  </div>
</body>
</html>`;
