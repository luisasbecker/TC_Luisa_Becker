#!/bin/bash
# Run manually on the Mac to build and install the full test app on one Android.
# This does not publish a release, change device security settings or erase data.
set -euo pipefail

if [[ "${1:-}" == --help || "${1:-}" == -h ]]; then
  echo "Uso: bash mobile/tool/install_android_local.sh [SERIAL_ANDROID]"
  echo "Confere o Android autorizado, compila lib/main.dart, instala sem apagar dados e abre o app."
  echo "Sem serial, seleciona somente quando houver exatamente um Android autorizado."
  echo "Não publica em lojas nem altera configurações de segurança do aparelho."
  exit 0
fi
if [[ $# -gt 1 ]]; then
  echo "Informe somente um serial opcional. Use --help para consultar o uso."
  exit 1
fi
requested_serial="${1:-${PIPELINE_ANDROID_SERIAL:-}}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
mobile_dir="$(cd -- "$script_dir/.." && pwd)"
cd -- "$mobile_dir"
log_dir="$mobile_dir/../docs/ux/validation/logs"
mkdir -p -- "$log_dir"
log_path="$log_dir/android-local-$(date +%Y%m%d-%H%M%S).log"
: > "$log_path"
message() { printf '%s\n' "$*" | tee -a "$log_path"; }
run_logged() { "$@" 2>&1 | tee -a "$log_path"; }
trap 'result=$?; if [[ $result != 0 ]]; then message "Etapa interrompida. Consulte o erro acima e o log: $log_path"; fi' EXIT

flutter_bin="${PIPELINE_FLUTTER_BIN:-}"
if [[ -z "$flutter_bin" ]]; then
  flutter_bin="$(command -v flutter || true)"
fi
if [[ -z "$flutter_bin" && -x /opt/homebrew/share/flutter/bin/flutter ]]; then
  flutter_bin=/opt/homebrew/share/flutter/bin/flutter
fi
if [[ ! -x "$flutter_bin" ]]; then
  message "Flutter não encontrado. Configure PIPELINE_FLUTTER_BIN com o executável Flutter."
  exit 1
fi

if [[ -z "${JAVA_HOME:-}" && -x /opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home/bin/java ]]; then
  export JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home
fi

android_sdk="${ANDROID_HOME:-${ANDROID_SDK_ROOT:-}}"
if [[ -z "$android_sdk" && -f android/local.properties ]]; then
  android_sdk="$(sed -n 's/^sdk\.dir=//p' android/local.properties | head -1)"
fi
if [[ -z "$android_sdk" || ! -x "$android_sdk/platform-tools/adb" ]]; then
  message "Android SDK não encontrado. Configure ANDROID_HOME."
  exit 1
fi
export ANDROID_HOME="$android_sdk"
adb_bin="$android_sdk/platform-tools/adb"
serial="$requested_serial"

message "Mantenha o Android conectado e desbloqueado. Autorize a conexão USB no aparelho, se solicitado."

require_authorized_device() {
  while true; do
    device_lines="$("$adb_bin" devices)" || return 1
    if [[ -z "$serial" ]]; then
      available_count="$(printf '%s\n' "$device_lines" | awk 'NR>1 && $2=="device" {n++} END {print n+0}')"
      if [[ "$available_count" -gt 1 ]]; then
        message "Há mais de um Android autorizado. Informe o serial desejado como argumento; nenhum será escolhido."
        return 1
      elif [[ "$available_count" == 1 ]]; then
        serial="$(printf '%s\n' "$device_lines" | awk 'NR>1 && $2=="device" {print $1}')"
      fi
    fi
    state="$(printf '%s\n' "$device_lines" | awk -v target="$serial" '$1==target {print $2}')"
    if [[ -n "$serial" && "$state" == device ]]; then
      return 0
    fi
    if [[ "$state" == unauthorized ]] || { [[ -z "$serial" ]] && printf '%s\n' "$device_lines" | awk 'NR>1 && $2=="unauthorized" {found=1} END {exit !found}'; }; then
      message "O Android aguarda autorização. Desbloqueie-o e aceite a mensagem de depuração USB desse computador."
    elif [[ "$state" == offline ]]; then
      message "O Android está offline. Confira o cabo e a conexão USB."
    else
      message "O Android ainda não está visível para instalação. Confira o cabo, a conexão e a depuração USB."
    fi
    if [[ ! -t 0 ]]; then
      message "Execute novamente em um Terminal interativo após autorizar o aparelho. Nenhum build ou instalação será iniciado agora."
      return 1
    fi
    read -r -p "Depois de conferir o aparelho, pressione Enter para tentar novamente (Ctrl+C cancela): " retry_answer || return 1
  done
}

# Device authorization must succeed before downloading or building anything.
# Once chosen, the same serial remains pinned through build and installation.
require_authorized_device

message "Android conectado: $("$adb_bin" -s "$serial" shell getprop ro.product.model | tr -d '\r')"
message "Versão Android: $("$adb_bin" -s "$serial" shell getprop ro.build.version.release | tr -d '\r')"
message "Compilando o aplicativo completo (lib/main.dart), com endpoint cloud padrão."
export CI=true
export FLUTTER_SUPPRESS_ANALYTICS=true

# Use the normal local developer environment. This script intentionally does not
# configure proxies, disable TLS, stop other ADB servers or alter permissions.
run_logged "$flutter_bin" --no-version-check pub get --offline || run_logged "$flutter_bin" --no-version-check pub get
run_logged "$flutter_bin" --no-version-check build apk --debug --no-pub --target=lib/main.dart

apk="$mobile_dir/build/app/outputs/flutter-apk/app-debug.apk"
if [[ ! -s "$apk" ]]; then
  message "O build terminou sem produzir o APK esperado. Instalação não executada."
  exit 1
fi

require_authorized_device
message "Instalando Pipeline Bucal sem apagar os dados existentes."
run_logged "$adb_bin" -s "$serial" install -r "$apk"
launch_output="$("$adb_bin" -s "$serial" shell am start -W -n \
  br.com.luisabecker.pipeline_bucal/br.com.luisabecker.pipeline_bucal.MainActivity)"
printf '%s\n' "$launch_output" | tee -a "$log_path"
if ! printf '%s\n' "$launch_output" | awk '/^Status: ok\r?$/ {ok=1} END {exit !ok}'; then
  message "O APK foi instalado, mas o Android não confirmou a abertura. Confira a mensagem acima."
  exit 1
fi

message "Instalação e abertura confirmadas pelo gerenciador de atividades Android. APK: $apk"
message "Confira a tela do Pipeline Bucal no aparelho. Nenhuma publicação em loja foi realizada."
