OnTop Manager - Kullanim Notlari
=================================

Icerik:
  - OnTopManager.dpr   : Proje dosyasi
  - uMain.pas          : Ana form kodu
  - uMain.dfm          : Ana form tasarimi

Nasil acilir / derlenir (Delphi 10.4 Sydney):
  1) Delphi 10.4 IDE'de File > Open Project... ile OnTopManager.dpr dosyasini acin.
     (Ilk acilista IDE, dproj/res dosyalarini otomatik olusturacaktir.)
  2) Platform olarak Win32 veya Win64 secip Run (F9) ile calistirin.

Nasil calisir:
  - Program acildiginda ekrandaki tum gorunur uygulama pencerelerini listeler
    (Uygulama/EXE adi, pencere basligi, PID ve mevcut "Ontop" durumu).
  - "Listeyi Yenile" butonu veya 2 saniyelik otomatik zamanlayici ile liste
    guncellenir.
  - Listeden bir pencere secip "Ontop Yap / Kaldir" butonuna basarak (veya
    satira cift tiklayarak) o pencereyi her zaman ustte goster / kaldir.
  - COKLU SECIM: Ctrl'ye basili tutarak (veya Ctrl+A ile) birden fazla pencere
    secilebilir; "Secilenleri Ontop Yap / Kaldir" butonu secilenlerin tamamina
    uygulanir (secilenlerin tamami ontop ise kapatir, degilse hepsini acar).
  - GRUPLAMA: "Uygulamalari Grupla" seciliyken ayni uygulamaya (chrome.exe,
    opera.exe vb.) ait birden fazla pencere tek bir grup satiri altinda toplanir
    ("N kopya / M ontop" bilgisiyle). Grup satirina tiklayarak alt pencereleri
    acip kapatabilirsiniz (dropdown gibi).
  - Ontop yapilan uygulamalar, calistirilabilir dosya adina (orn. notepad.exe)
    gore %APPDATA%\OnTopManager\settings.ini dosyasina kaydedilir.
  - Program kapatilip tekrar acildiginda, veya ayni isimli uygulama sonradan
    baslatildiginda (PID/pencere handle'i degismis olsa bile), kayitli
    uygulamalar otomatik olarak tekrar ontop yapilir.
  - Pencerenin sag ustundeki X butonu programi kapatmaz, sistem tepsisine
    (tray) kucultur; tepsi simgesine cift tiklayarak tekrar acabilir, sag tik
    menusunden "Cikis" ile programi tamamen kapatabilirsiniz.
  - Varsayilan kisayollar: Ctrl+Shift+H ile on plandaki pencereyi tray'a at,
    Ctrl+Shift+J ile geri getir (kisayollar arayuzden degistirilebilir;
    degisen deger %APPDATA%\OnTopManager\settings.ini dosyasinda saklanir).
    Kisayollar acilista otomatik devreye girer; "Kisayollar etkin" onay
    kutusundan kapatilabilir/açilabilir ve bu tercih de saklanir.

  - Liste basliklarina (Ontop, Uygulama (EXE), Pencere Basligi, PID,
    Baslangic Tarihi) tiklayarak o alana gore artan/azalan sirada
    siralama yapabilirsiniz; aktif siralama sutununda ^ / v isareti gorunur.
  - Sistem tepsisindeki simge uygulamanin kendi (Application) ikonudur.

Surum Notlari
=============
Surum numarasi Delphi proje seceneklerinde (OnTopManager.dproj > VerInfo_Keys,
FileVersion/ProductVersion) tutulur ve form basliginda "vX.Y.Z" olarak gosterilir.
Her yeni ozellik talebinde minor deger bir arttirilir.

  v1.9.0 - Programdan cikista tray ile gizlenen tum acik pencereler geri getirilir.
  v1.8.2 - Delphi basliklarinda eksik GetShellWindow icin dogrudan user32 bildirimi eklendi.
  v1.8.1 - Delphi Win32 GCLP_HICONSM/GCLP_HICON tanimsiz sabit hatasi giderildi.
  v1.8.0 - Tray menusunde pencere simgeleri; kisayolla gizleme sonrasi siradaki gorunur uygulamaya odak gecisi; basili tutulan kisayolun tekrar tetiklenmesi engellendi.
  v1.7.0 - Kisayollar ilk acilista "Uygula" beklemeksizin otomatik devreye girer; "Kisayollar etkin" onay kutusu ile acilip kapatilabilir (tercih INI'de saklanir)
  v1.6.0 - Varsayilan kisayollar Ctrl+Shift+H (tray'a at) ve Ctrl+Shift+J (geri getir) olarak degistirildi; THotKey.HotKey TShortCut kodlamasi ile HotKeyMods uyumsuzlugu giderildi (Shift/Ctrl/Alt iceren kisayollar artik dogru kaydediliyor, oncesinde modifier'siz H/J olarak kaydediliyordu)
  v1.4.0 - Ayarlanabilir kisayollarla pencereyi tray'a atma (Ctrl+Alt+H) ve geri getirme (Ctrl+Alt+J); gizli pencereler ana ikonun menusunde kumelenir veya istenirse ikinci tray ikonunda gosterilir
  v1.3.0 - Pencereyi one getirme artik cift tiklama ile; tek tiklama sadece secim yapar
  v1.2.0 - Tek kopya korumasi (mutex): ikinci baslatista mevcut pencere one gelir
  v1.1.0 - Coklu secim ile toplu ontop; uygulama bazli gruplama/dropdown; tiklanan pencereyi one getirme
  v1.0.0 - Ilk surum: pencere listesi, ontop yap/kaldir, hatirlama (INI), tray, sutun siralama

Notlar:
  - Bu ortamda Delphi kurulu olmadigi icin kod burada derlenip test edilememistir;
    Delphi 10.4 ile acip derlemeniz ve calistirmaniz gerekir.
  - Uygulama kendi penceresini listede gostermez.
  - Eslestirme PID yerine EXE dosya adina gore yapildigi icin, bir uygulamayi
    kapatip tekrar actiginizda (yeni PID ile) ontop hatirlanmasi calismaya
    devam eder.
