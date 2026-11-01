# Distribuição Android para testes — 30/10/2026

O artefato disponível é `design/exports/android-v1/Pipeline_Bucal_Android_v1_0.3.0_build4_debug.apk`.
É uma cópia byte a byte do aplicativo completo que foi instalado e aberto no
Samsung Android 16. Não foi recompilado nem reassinado nesta exportação.

- Versão: 0.3.0, build 4, modalidade **debug**.
- Pacote: `br.com.luisabecker.pipeline_bucal`.
- Android mínimo: 7.0 / API 24; target SDK 36.
- ABIs: ARM64, ARM de 32 bits e x86_64 no mesmo APK.
- Tamanho: 155.964.359 bytes.
- SHA-256: `b414f94736c6276862d490926873a7a5afa46b1537dba0d3963cae283a73f8ff`.
- Assinatura verificada com `apksigner`; alinhamento verificado com
  `zipalign -c -P 16` e segmentos ELF com alinhamento mínimo de 16 KB.
- Confirmados manifesto, fontes, marca, 11 referências com hashes íntegros,
  as seis classes e o endpoint HTTPS no código Dart empacotado.

O relatório `design/exports/android-v1/APK_BUILD4_DEBUG_VALIDATION.json` registra
39 verificações aprovadas. Essa inspeção de artefato não substitui testes completos
no aparelho e não realizou novas requisições à cloud. O arquivo
`SHA256SUMS.txt` permite conferir a integridade após o download.

## Release preparado, ainda não produzido

Foi preparada uma nova chave local RSA de 4096 bits para futuras distribuições
release. Nenhuma chave, senha ou configuração de assinatura foi enviada para a
cloud, para o Git ou para a pasta de distribuição.

A tentativa convencional de release build 5 foi bloqueada pela indisponibilidade
de sockets locais do daemon Gradle neste ambiente. A execução oficial sem daemon,
em processo único e offline, avançou após reutilizar cópias graváveis dos caches.
O último impedimento foi a ausência de dependências AndroidX necessárias ao
release no cache offline, incluindo `lifecycle-livedata-core:2.6.1` e
`androidx.arch.core:core-common:2.1.0`. Não se alteraram as versões das dependências.

Logs: `logs/android-release-20261030-build5.log`,
`logs/android-release-inprocess-offline-20261030-build5.log` e
`logs/android-release-pubcache-offline-20261030-build5.log`.

Para gerar e verificar o release no ambiente local normal do Mac:

```bash
bash mobile/tool/build_android_distribution.sh
```

O helper usa `lib/main.dart`, o endpoint padrão e `--build-number=5`, sem mudar
a versão do `pubspec.yaml` nem o código iOS. Ele valida o APK antes de exportar
`Pipeline_Bucal_Android_v1_0.3.0_build5.apk`; não instala nem publica o aplicativo.
O helper teve sintaxe e ajuda verificadas; o seu build completo ainda não foi
concluído. O validador rejeitou corretamente o APK debug quando submetido aos
critérios de release.

## Preservação da assinatura

Guardar um backup criptografado e privado destes dois arquivos locais juntos:

- `mobile/android/keystore/upload-keystore.jks`.
- `mobile/android/key.properties`.

O diretório da chave possui permissão 700, e os dois arquivos, permissão 600.
Ambos estão ignorados pelo Git. Não enviá-los na pasta destinada aos testadores,
nem recriá-los para cada atualização. A mesma chave deve assinar as futuras
atualizações release.

A assinatura release é diferente da assinatura debug existente. A migração entre
elas deve ser planejada separadamente; nenhum aplicativo foi desinstalado ou teve
seus dados apagados durante esta preparação.

## Verificação atual do upload manual

Em 30/10/2026, a usuária enviou manualmente o arquivo ao OneDrive. A cópia foi baixada pelo botão Baixar da pasta indicada e comparada com o APK validado:

- Nome no download do OneDrive: `Pipeline_Bucal_Android_v1_0.3.0.apk`.
- Tamanho: 155.964.359 bytes (a interface mostra aproximadamente 149 MB).
- SHA-256: `b414f94736c6276862d490926873a7a5afa46b1537dba0d3963cae283a73f8ff`.
- Resultado: conteúdo idêntico ao APK debug 0.3.0/build 4 validado. A alteração do nome não modificou o aplicativo.
- A interface mostrou compartilhamento **Particular**. Download verificado na sessão da proprietária; acesso por terceiros ainda não verificado/liberado nesta atividade.

## Destino OneDrive e comunicação aos testadores

Pasta solicitada: `TCC_Pipeline_Estomatologia/APK_Android/v1`, na conta institucional da usuária.

O APK foi preparado localmente com `LEIA-ME_TESTADORES_ANDROID.txt`. Estado anterior à intervenção da usuária: o envio **não havia sido confirmado**: o seletor nativo do Safari manteve o botão Enviar desabilitado ao selecionar o APK e também o TXT, inclusive em nova aba. A pasta ainda estava vazia naquela observação. Foi deixada uma aba no navegador do ChatGPT para autenticação do usuário e continuação do upload pelo seletor do navegador.

O diálogo do OneDrive informou que a pasta ainda não estava compartilhada e que somente pessoas adicionadas teriam acesso. As opções observadas foram pessoas da organização ou pessoas adicionadas. Não foram alteradas permissões nem enviados convites.

Mensagem pronta em `MENSAGEM_TESTADORES_ANDROID.md` e cópia TXT na pasta de exportação. O texto deve ser encaminhado ao grupo após a confirmação do upload e do acesso dos testadores.

A consulta visual ao endpoint `/v2/health`, no navegador em 30/10/2026, retornou `status: ok`, `api_version: 2` e `simulation_only: true`. Não houve nova implantação ou alteração de faturamento. Essa consulta confirma disponibilidade do serviço, não substitui uma execução completa do pipeline.
