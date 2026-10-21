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
  - Ontop yapilan uygulamalar, calistirilabilir dosya adina (orn. notepad.exe)
    gore %APPDATA%\OnTopManager\settings.ini dosyasina kaydedilir.
  - Program kapatilip tekrar acildiginda, veya ayni isimli uygulama sonradan
    baslatildiginda (PID/pencere handle'i degismis olsa bile), kayitli
    uygulamalar otomatik olarak tekrar ontop yapilir.
  - Pencerenin sag ustundeki X butonu programi kapatmaz, sistem tepsisine
    (tray) kucultur; tepsi simgesine cift tiklayarak tekrar acabilir, sag tik
    menusunden "Cikis" ile programi tamamen kapatabilirsiniz.

Notlar:
  - Bu ortamda Delphi kurulu olmadigi icin kod burada derlenip test edilememistir;
    Delphi 10.4 ile acip derlemeniz ve calistirmaniz gerekir.
  - Uygulama kendi penceresini listede gostermez.
  - Eslestirme PID yerine EXE dosya adina gore yapildigi icin, bir uygulamayi
    kapatip tekrar actiginizda (yeni PID ile) ontop hatirlanmasi calismaya
    devam eder.
