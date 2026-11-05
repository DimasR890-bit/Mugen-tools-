#!/data/data/com.termux/files/usr/bin/bash
# build.sh - build Mugen Tools jadi APK langsung di Termux (tanpa HTML to APK)
set -e
cd "$(dirname "$0")"
P="${PREFIX:-/data/data/com.termux/files/usr}"

echo "[1/6] Install alat build..."
pkg install -y openjdk-17 aapt2 apksigner ecj zip curl unzip >/dev/null
command -v d8 >/dev/null 2>&1 || command -v dx >/dev/null 2>&1 || pkg install -y dx >/dev/null 2>&1 || pkg install -y d8 >/dev/null 2>&1 || true

echo "[2/6] Cari android.jar..."
AJ="${ANDROID_JAR:-}"
if [ -z "$AJ" ] || [ ! -f "$AJ" ]; then
  AJ=$(find "$P/share" "$HOME" -name android.jar 2>/dev/null | head -n 1)
fi
if [ -z "$AJ" ]; then
  mkdir -p "$HOME/.mugen-sdk"; AJ="$HOME/.mugen-sdk/android.jar"
  for u in \
    "https://github.com/Sable/android-platform-jars/raw/master/android-28/android.jar" \
    "https://github.com/Reginer/aosp-android-jar/raw/main/android-28/android.jar"; do
    curl -fL "$u" -o "$AJ" 2>/dev/null && [ "$(stat -c%s "$AJ")" -gt 1000000 ] && break
    rm -f "$AJ"
  done
fi
if [ ! -f "$AJ" ]; then
  echo "GAGAL: android.jar tidak ditemukan/terunduh."
  echo "Taruh file android.jar (API 28 ke atas) lalu jalankan: ANDROID_JAR=/path/android.jar bash build.sh"
  exit 1
fi
echo "    pakai: $AJ"

rm -rf build; mkdir -p build/obj

echo "[3/6] Kompilasi Java..."
ecj -source 8 -target 8 -bootclasspath "$AJ" -cp "$AJ" -d build/obj java/com/mugen/tools/MainActivity.java

echo "[4/6] Bikin classes.dex..."
CLASSES=$(find build/obj -name '*.class')
if command -v d8 >/dev/null 2>&1; then
  d8 --min-api 24 --lib "$AJ" --output build $CLASSES
else
  dx --dex --output=build/classes.dex build/obj
fi

echo "[5/6] Susun resource + assets..."
aapt2 compile --dir res -o build/res.zip
aapt2 link -o build/base.apk -I "$AJ" --manifest AndroidManifest.xml -A assets -R build/res.zip \
  --min-sdk-version 24 --target-sdk-version 28 --version-code 1 --version-name 1.0 --auto-add-overlay
(cd build && zip -q -j base.apk classes.dex)

echo "[6/6] Tanda tangan APK..."
KS="$HOME/.mugen-debug.jks"
[ -f "$KS" ] || keytool -genkeypair -keystore "$KS" -storepass android -keypass android \
  -alias mugen -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Mugen Tools" >/dev/null 2>&1
apksigner sign --ks "$KS" --ks-pass pass:android --key-pass pass:android --out MugenTools.apk build/base.apk

echo
echo "SELESAI: $(pwd)/MugenTools.apk"
if [ -d "$HOME/storage/downloads" ]; then
  cp MugenTools.apk "$HOME/storage/downloads/MugenTools.apk" && echo "Salinan: Download/MugenTools.apk"
fi
echo "Install: termux-open MugenTools.apk"
