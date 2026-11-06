import { LEGAL_PAGE_STYLE } from './legal-style.js';

export const TERMS_OF_USE_HTML = `<!DOCTYPE html>
<html lang="tr">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Kullanım Koşulları — STILYA</title>
  ${LEGAL_PAGE_STYLE}
</head>
<body>
  <div class="container">
    <div class="logo">STILYA</div>
    <div class="subtitle">Satın almadan önce dene</div>

    <h1>Kullanım Koşulları</h1>
    <p class="date">Son güncelleme: 26 Şubat 2026</p>

    <p>Bu kullanım koşulları, STILYA mobil uygulamasını ("Uygulama") kullanımınıza ilişkin koşulları belirler. Uygulamayı kullanarak bu koşulları kabul etmiş sayılırsınız.</p>

    <h2>1. Hizmet Tanımı</h2>
    <p>STILYA, yapay zeka teknolojisi kullanarak kıyafetleri sanal olarak denemenizi sağlayan bir iOS uygulamasıdır. Hizmet kapsamında:</p>
    <ul>
      <li>Tek parça kıyafet deneme</li>
      <li>Kombin oluşturma (birden fazla parça)</li>
      <li>Sonuçları kaydetme ve paylaşma</li>
    </ul>

    <h2>2. Hesap ve Kayıt</h2>
    <ul>
      <li>Uygulamayı kullanmak için Apple veya Google hesabınızla giriş yapabilirsiniz</li>
      <li>Hesap bilgilerinizin doğruluğundan siz sorumlusunuz</li>
      <li>Hesabınızın güvenliğini sağlamak sizin sorumluluğunuzdadır</li>
    </ul>

    <h2>3. Kredi Sistemi</h2>
    <ul>
      <li><strong>Ücretsiz kullanım:</strong> Her hafta 5 ücretsiz kredi verilir</li>
      <li><strong>Tek parça deneme:</strong> 1 kredi</li>
      <li><strong>Kombin oluşturma:</strong> 1 kredi</li>
      <li>Kullanılmayan ücretsiz krediler haftalık olarak sıfırlanır ve bir sonraki haftaya devretmez</li>
    </ul>

    <h2>4. Abonelikler ve Satın Almalar</h2>
    <ul>
      <li><strong>Pro Haftalık:</strong> Haftalık otomatik yenilenen abonelik</li>
      <li><strong>Pro Aylık:</strong> Aylık otomatik yenilenen abonelik</li>
      <li><strong>Kredi Paketleri:</strong> Tek seferlik satın alma (süresiz geçerli)</li>
    </ul>
    <p>Abonelik koşulları:</p>
    <ul>
      <li>Ödeme, satın alma onayında Apple Kimliği hesabınızdan tahsil edilir</li>
      <li>Abonelik, mevcut dönem bitiminden en az 24 saat önce iptal edilmediği sürece otomatik olarak yenilenir</li>
      <li>Yenileme ücreti, mevcut dönemin bitiminden 24 saat içinde hesabınızdan tahsil edilir</li>
      <li>Aboneliklerinizi satın alma sonrasında cihazınızın Ayarlar > Apple Kimliği > Abonelikler bölümünden yönetebilir ve iptal edebilirsiniz</li>
      <li>Ücretsiz deneme süresi sunulması halinde, kullanılmayan kısım abonelik satın alındığında geçerliliğini yitirir</li>
    </ul>

    <h2>5. Kabul Edilebilir Kullanım</h2>
    <p>Uygulamayı kullanırken aşağıdaki kurallara uymayı kabul edersiniz:</p>
    <ul>
      <li>Yalnızca kendinize ait veya kullanım iznine sahip olduğunuz fotoğrafları yüklemek</li>
      <li>Uygulamayı yasa dışı, zararlı veya başkalarının haklarını ihlal edecek şekilde kullanmamak</li>
      <li>Uygulamanın güvenlik önlemlerini aşmaya çalışmamak</li>
      <li>Otomatik veya toplu istek gönderen araçlar kullanmamak</li>
      <li>Uygunsuz, müstehcen veya hakaret içeren içerik yüklememek</li>
    </ul>

    <h2>6. Fikri Mülkiyet</h2>
    <p>Uygulama ve içerdiği tüm tasarım, kod, grafik ve içerikler STILYA'nın fikri mülkiyetidir. Kullanıcılar:</p>
    <ul>
      <li>Yükledikleri fotoğrafların haklarını korurlar</li>
      <li>Yapay zeka ile oluşturulan deneme sonuçlarını kişisel kullanım için saklayabilir ve paylaşabilirler</li>
      <li>Uygulamayı ticari amaçla kopyalayamaz veya tersine mühendislik yapamaz</li>
    </ul>

    <h2>7. Yapay Zeka Sonuçları</h2>
    <ul>
      <li>Yapay zeka sonuçları tahmini niteliktedir ve gerçek görünümü birebir yansıtmayabilir</li>
      <li>Sonuçlar satın alma kararı için referans amaçlıdır, garanti niteliği taşımaz</li>
      <li>Renk, beden ve kumaş dokusu farklılıkları oluşabilir</li>
    </ul>

    <h2>8. Sorumluluk Sınırlaması</h2>
    <ul>
      <li>Uygulama "olduğu gibi" sunulmaktadır</li>
      <li>Yapay zeka sonuçlarının doğruluğu garanti edilmez</li>
      <li>Teknik arızalar, bakım çalışmaları veya üçüncü taraf hizmet kesintileri nedeniyle oluşabilecek aksaklıklardan sorumlu değiliz</li>
      <li>Satın alma kararlarınızdan STILYA sorumlu tutulamaz</li>
    </ul>

    <h2>9. Hesap Feshi</h2>
    <p>Aşağıdaki durumlarda hesabınızı askıya alma veya sonlandırma hakkını saklı tutarız:</p>
    <ul>
      <li>Bu koşulların ihlali</li>
      <li>Kötüye kullanım veya dolandırıcılık girişimi</li>
      <li>Sistemin güvenliğini tehlikeye atan davranışlar</li>
    </ul>
    <p>Hesabınızı istediğiniz zaman uygulama içinden silebilirsiniz.</p>

    <h2>10. Değişiklikler</h2>
    <p>Bu koşulları önceden bildirmeksizin güncelleme hakkını saklı tutarız. Önemli değişiklikler uygulama içinden bildirilecektir. Değişiklik sonrası uygulamayı kullanmaya devam etmeniz, güncel koşulları kabul ettiğiniz anlamına gelir.</p>

    <h2>11. Uygulanacak Hukuk</h2>
    <p>Bu koşullar Türkiye Cumhuriyeti hukukuna tabidir. Uyuşmazlıklarda İstanbul mahkemeleri ve icra daireleri yetkilidir.</p>

    <h2>12. İletişim</h2>
    <p>Sorularınız için bize ulaşabilirsiniz:</p>
    <p>E-posta: <a href="mailto:support@stilya.app">support@stilya.app</a></p>

    <div class="footer">
      <p>&copy; 2026 STILYA. Tüm hakları saklıdır.</p>
      <div class="nav">
        <a href="/privacy">Gizlilik Politikası</a>
        <a href="/terms">Kullanım Koşulları</a>
      </div>
    </div>
  </div>
</body>
</html>`;
