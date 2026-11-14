# نشر «أثر لا ينقطع» على Google Play

هذه خطوات إصدار Android App Bundle آمن. لا تستخدم APK التجريبي للنشر.

## 1. إنشاء مفتاح رفع (على جهازك الشخصي)

في PowerShell، مع وجود Java 17 أو أحدث:

```powershell
keytool -genkeypair -v -keystore athr-upload.jks -storetype PKCS12 -keyalg RSA -keysize 4096 -validity 10000 -alias athrUpload
```

احفظ ملف `athr-upload.jks` وكلمات المرور في مكان خاص مع نسخة احتياطية آمنة. **لا ترفع المفتاح إلى مستودع GitHub ولا ترسله عبر المحادثة**.

## 2. إدخال أسرار GitHub

اذهب إلى إعدادات مستودع `ahmedax2026/athr`، ثم **Settings > Secrets and variables > Actions > New repository secret**.

في PowerShell:

```powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path "./athr-upload.jks")))
```

أضف أربعة أسرار:

- `ATHR_UPLOAD_KEYSTORE_BASE64`: نص Base64 الناتج (لا تشاركه علنًا).
- `ATHR_UPLOAD_STORE_PASSWORD`: كلمة مرور المخزن.
- `ATHR_UPLOAD_KEY_ALIAS`: `athrUpload`.
- `ATHR_UPLOAD_KEY_PASSWORD`: كلمة مرور المفتاح.

## 3. إصدار AAB

من الفرع `feature/qcf-quran-005` افتح GitHub Actions workflow باسم `Build signed Google Play AAB`، ثم شغله يدويًا عبر **Run workflow**.

عند النجاح، نزّل artifact باسم `athr-google-play-signed-aab`، واستخرج `app-release.aab` منه. الملف المضغوط الذي يقدّمه GitHub ليس هو الملف الذي ترفعه إلى Play Console.

## 4. Google Play Console

افتح https://play.google.com/console/ وأنشئ تطبيقًا باسم «أثر لا ينقطع»، ثم أكمل بيانات المتجر وسياسة الخصوصية وإقرار سلامة البيانات وتصنيف المحتوى وتعليمات الوصول عند الحاجة. ارفع ملف AAB إلى مسار الاختبار المغلق (Closed testing) أو الاختبار الداخلي (Internal testing).

بالنسبة للحسابات الشخصية المنشأة بعد 13 نوفمبر 2023، يتطلب الوصول للإنتاج مشاركة 12 مختبرًا في الاختبار المغلق لمدة 14 يومًا متواصلة على الأقل، ثم التقديم للحصول على حق النشر الإنتاجي.

## متطلبات قبل الإصدار العام

- اختبر الأذان والإشعارات والصلاحيات والقرآن والأذكار والختمات و«فك كرب» على أجهزة حقيقية.
- جهّز سياسة خصوصية عامة على رابط HTTPS، تكون متاحة من داخل التطبيق والمتجر.
- لا تنشر وثائق «فك كرب» التي تتضمن معلومات شخصية حساسة بدون إخفائها وموافقة صاحبها.
- راجع صحة الآيات والأذكار المعروضة في الصور قبل النشر.
- أكمل أي متطلبات معلّقة في لوحة Play Console.

ملاحظة: إعدادات الرفع والربط هنا تجهّز البنية التقنية فقط، ولا تعني أن التطبيق اجتاز مراجعة Google Play.
