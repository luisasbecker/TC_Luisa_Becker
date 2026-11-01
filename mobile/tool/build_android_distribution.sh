#!/bin/bash
# Conventional local release build. Does not install, upload or modify iOS.
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Uso: bash mobile/tool/build_android_distribution.sh"
  echo "Gera e verifica APK universal release 0.3.0 build 5 usando a chave local existente."
  echo "Não cria chaves, instala no aparelho ou envia arquivos."
  exit 0
fi
if [[ $# != 0 ]]; then
  echo "Nenhum argumento é necessário. Consulte --help."
  exit 1
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mobile_dir="$(cd -- "$script_dir/.." && pwd)"
repo_dir="$(cd -- "$mobile_dir/.." && pwd)"
cd -- "$mobile_dir"
if [[ ! -f android/key.properties || ! -f android/keystore/upload-keystore.jks ]]; then
  echo "Chave ou configuração local ausente. Restaure o backup seguro antes de gerar atualizações."
  exit 1
fi
git check-ignore -q android/key.properties
git check-ignore -q android/keystore/upload-keystore.jks

flutter_bin="${PIPELINE_FLUTTER_BIN:-$(command -v flutter || true)}"
if [[ -z "$flutter_bin" && -x /opt/homebrew/share/flutter/bin/flutter ]]; then
  flutter_bin=/opt/homebrew/share/flutter/bin/flutter
fi
if [[ ! -x "$flutter_bin" ]]; then
  echo "Flutter não encontrado. Configure PIPELINE_FLUTTER_BIN."
  exit 1
fi
if [[ -z "${JAVA_HOME:-}" && -x /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi
android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$android_sdk" && -f android/local.properties ]]; then
  android_sdk="$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -1)"
fi
if [[ -z "$android_sdk" || ! -d "$android_sdk/build-tools" ]]; then
  echo "Android SDK não encontrado. Configure ANDROID_HOME."
  exit 1
fi
export ANDROID_HOME="$android_sdk"
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true

log_dir="$repo_dir/docs/ux/validation/logs"
mkdir -p -- "$log_dir"
log_path="$log_dir/android-distribution-$(date +%Y%m%d-%H%M%S).log"
run_logged() { "$@" 2>&1 | tee -a "$log_path"; }
echo "Compilando lib/main.dart com o endpoint cloud padrão e a chave local."
run_logged "$flutter_bin" --no-version-check pub get --offline
run_logged "$flutter_bin" --no-version-check build apk --release --no-pub \
  --target=lib/main.dart --build-name=0.3.0 --build-number=5

apk="$mobile_dir/build/app/outputs/flutter-apk/app-release.apk"
export_dir="$repo_dir/design/exports/android-v1"
mkdir -p -- "$export_dir"
report="$export_dir/APK_BUILD5_RELEASE_VALIDATION.json"
run_logged python3 "$script_dir/verify_android_distribution.py" "$apk" \
  --sdk "$android_sdk" --report "$report"

destination="$export_dir/Pipeline_Bucal_Android_v1_0.3.0_build5.apk"
cp -- "$apk" "$destination"
chmod 644 "$destination"
python3 - "$destination" <<'PY'
import hashlib
from pathlib import Path
import sys
apk = Path(sys.argv[1])
digest = hashlib.sha256(apk.read_bytes()).hexdigest()
(apk.parent / 'SHA256SUMS_RELEASE.txt').write_text(digest + '  ' + apk.name + '\n')
print('APK release validado e pronto: ' + str(apk))
print('SHA-256: ' + digest)
print('Nenhuma instalação ou publicação foi realizada.')
PY
