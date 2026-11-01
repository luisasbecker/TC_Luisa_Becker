# Verificação do build e instalação Android — 30/10/2026

## Resultado atual: instalado e aberto no Samsung

**Build, instalação e abertura confirmados em 30/10/2026.** A usuária executou o
instalador preparado no Terminal normal do Mac e autorizou a depuração USB. O
Gradle conseguiu baixar suas dependências e concluir `assembleDebug` em 343,8 s.
O APK completo usa `lib/main.dart`, com o endpoint HTTPS v2 padrão do projeto.

- Dispositivo: Samsung **SM-X910**, Android **16**, API **36**, ABI arm64-v8a.
- Aplicativo: Pipeline Bucal, versão **0.3.0**, build **4**.
- Pacote: `br.com.luisabecker.pipeline_bucal`.
- APK: `mobile/build/app/outputs/flutter-apk/app-debug.apk`, **155.964.359 bytes**.
- Instalação pelo Android: **Success**.
- Assinatura do APK: `apksigner verify --verbose` aprovado, esquema v2, um assinante.
- Abertura: **Status: ok**, `LaunchState: COLD`, `MainActivity`, 1830 ms.
- Verificação posterior: processo ativo e Activity em estado retomado; nenhum
  erro fatal, exceção não tratada ou erro Flutter nos 220 registros examinados
  do processo recém-iniciado.
- Android mínimo 24, alvo 36; Inter, logo, biblioteca de referências e engine
  Flutter arm64 incluídos no pacote.

SHA-256 do APK:
`b414f94736c6276862d490926873a7a5afa46b1537dba0d3963cae283a73f8ff`.

Evidências: `logs/android-local-20261030-151504.log` e
`logs/android-device-install-20261030.json`. A confirmação de execução não
substitui o teste manual de câmera, recorte, fluxo completo e cloud no Samsung.
Esta é uma versão debug para testes locais; não houve envio às lojas.

## Histórico: bloqueios do ambiente de automação

Nas tentativas anteriores, nenhum APK foi gerado. A execução em processo único evitou o socket do daemon, mas o acesso
Java às dependências pelo proxy autorizado também falhou com `Operation not
permitted`. Não foi identificado um erro no código Android a partir dessas
tentativas. O histórico abaixo documenta esses bloqueios anteriores à execução
manual bem-sucedida de 30/10.

## Ambiente verificado

- Flutter 3.41.7 em `/tmp/tc-luisa-sdk/flutter`; cache de pacotes em `/tmp/tc-luisa-sdk/pub-cache`.
- OpenJDK 17.0.17 do Homebrew em `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`.
- Android SDK em `$HOME/Library/Android/sdk`, com plataformas 34, 35 e 36.
- Build Tools disponíveis: 33.0.1, 34.0.0, 35.0.0 e 36.1.0.
- NDK 28.2.13676358 já instalado, correspondente ao exigido pelo Flutter atual.
- Gradle 8.14-all, Android Gradle Plugin 8.11.1 e Kotlin 2.2.20, conforme o projeto.
- Cache Gradle temporário: `/tmp/tc-luisa-gradle`; configurações Android temporárias:
  `/tmp/tc-luisa-android`. Nenhuma variável `HOME` foi alterada.

## Comando executado

Dentro de `mobile/`:

```sh
CI=true \
FLUTTER_SUPPRESS_ANALYTICS=true \
PUB_CACHE=/tmp/tc-luisa-sdk/pub-cache \
JAVA_HOME=/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home \
ANDROID_HOME=$HOME/Library/Android/sdk \
ANDROID_USER_HOME=/tmp/tc-luisa-android \
GRADLE_USER_HOME=/tmp/tc-luisa-gradle \
/tmp/tc-luisa-sdk/flutter/bin/flutter --no-version-check build apk --debug --no-pub
```

O SDK temporário deve ser substituído pelo caminho do Flutter disponível em uma
execução futura. A tarefa solicita `assembleDebug`; não solicita assinatura de release.

## Evidências e sequência das tentativas

1. O wrapper Java falhou ao buscar a distribuição com
   `java.net.UnknownHostException: services.gradle.org`.
2. `curl` alcançou a URL oficial, acompanhando os redirecionamentos oficiais até o
   arquivo. O Java não usava automaticamente o proxy HTTP fornecido pelo ambiente.
   Foi configurado somente `/tmp/tc-luisa-gradle/gradle.properties` para usar esse mesmo
   proxy, sem credenciais, mudança de certificado ou desativação de validação HTTPS.
3. A tentativa Java com esse proxy falhou em abertura de socket com
   `java.net.SocketException: Operation not permitted`.
4. A distribuição exata `gradle-8.14-all.zip` foi baixada pela URL oficial usando `curl`
   para o cache esperado pelo wrapper, junto ao checksum oficial. Tamanho: **224116304
   bytes**. SHA-256 verificado:

   ```text
   efe9a3d147d948d7528a9887fa35abcf24ca1a43ad06439996490f77569b02d1
   ```

   Origem: `https://services.gradle.org/distributions/gradle-8.14-all.zip` e seu arquivo
   `.sha256`. A versão/URL do wrapper no repositório não foi alterada.
5. Com a distribuição local validada, o wrapper extraiu e iniciou o Gradle. A criação
   do daemon falhou **antes da configuração/compilação do projeto**, na abertura do
   socket local:

   ```text
   Unable to start the daemon process.
   java.net.SocketException: Operation not permitted
   org.gradle.internal.remote.internal.inet.TcpIncomingConnector.accept
   org.gradle.launcher.daemon.server.DaemonTcpServerConnector.start
   Caused by: java.net.SocketException: Operation not permitted
   sun.nio.ch.Net.listen
   sun.nio.ch.ServerSocketChannelImpl.bind
   ```

O bloqueio não se resume ao DNS ou download da distribuição: o Java também não
conseguiu abrir o socket local necessário ao daemon no ambiente desta execução.
Nenhuma permissão foi ampliada e não houve tentativa de execução fora do sandbox.

## Limitações e próximo passo

Executar o mesmo build debug em ambiente que permita o funcionamento normal do
Gradle/JVM e o acesso aos repositórios oficiais. Não reduzir versões de Gradle, AGP,
Kotlin ou bibliotecas para contornar o bloqueio ambiental.

O caminho esperado após um build bem-sucedido é
`mobile/build/app/outputs/flutter-apk/app-debug.apk`; ele **não existia ao final desta
verificação**. A distribuição verificada permanece apenas no cache temporário.

Não foram lidas, criadas ou alteradas chaves de assinatura de publicação. Um futuro
APK debug validaria a compilação para testes, mas não substituiria um AAB release
assinado nem a preparação exigida para envio à Play Store.

## Nova verificação após reconexão do iPhone

O comando documentado foi executado novamente em 29/10/2026 com Flutter 3.41.7,
JDK 17 e o cache existente. O Gradle iniciou `assembleDebug`, mas a abertura do
socket local do daemon voltou a falhar em `ServerSocketChannelImpl.bind`, com
`java.net.SocketException: Operation not permitted`. A falha ocorreu antes da
compilação do aplicativo. O arquivo `app-debug.apk` continua ausente. Log desta
tentativa: `logs/android-recheck-20261029.log`.

A revisão estática confirmou:

- `INTERNET` no manifesto principal, também aplicável ao build release; o endpoint
  do aplicativo usa HTTPS.
- Activity Flutter v2, `singleTop`, namespace e classe `MainActivity` consistentes.
- Flutter fornece `minSdk 24`, `compileSdk 36`, `targetSdk 36` e NDK
  `28.2.13676358`; os SDKs e o NDK correspondentes estão instalados.
- Java/Kotlin usam alvo 17. As dependências fixadas incluem implementações Android
  de seleção/captura de imagem e compartilhamento.
- O plugin `image_picker` instalado declara suporte a Android SDK 24+ e não exige
  configuração adicional de câmera no manifesto. O app chama `retrieveLostData`
  ao iniciar em Android para recuperar seleção interrompida pelo sistema.
- O botão/gesto de voltar é tratado com `PopScope`, compartilhando a navegação
  controlada do fluxo. O compartilhamento exporta JSON, com recuperação de erro.
- A proteção de assinatura release exige `android/key.properties`; nenhuma chave
  de publicação foi consultada, criada ou alterada nesta verificação.

Essas verificações de configuração e código **não equivalem a um build nem a um
teste em aparelho Android**. Não foram alteradas versões ou permissões do ambiente
para contornar o bloqueio, e não há evidência que permita afirmar que o APK foi
gerado ou que a aplicação foi executada em Android.

## Alternativa oficial sem daemon

Foi consultada a [documentação oficial de Gradle sobre desativação do daemon](https://docs.gradle.org/current/userguide/gradle_daemon.html#sec:disabling_the_daemon)
e a documentação/código-fonte incluídos na distribuição 8.14 já verificada. A
execução pode usar a JVM cliente quando seus argumentos coincidem com os do build.

A primeira tentativa com `gradlew --no-daemon` ainda lançou um daemon de uso único.
Em seguida, foi chamado o entrypoint oficial `org.gradle.launcher.GradleMain` da
mesma distribuição, com os argumentos de memória do projeto, o agente de
instrumentação original e `--no-daemon --max-workers=2 --info --stacktrace
assembleDebug`. Isso efetivamente usou `RunInProcess`, chegou a `Starting Build`
e à configuração do plugin Gradle do Flutter, sem abrir a porta do daemon.

O build então falhou ao resolver `org.gradle.kotlin.kotlin-dsl:5.2.0` em
`https://plugins.gradle.org`, porque a JVM recebeu `java.net.SocketException:
Operation not permitted` ao acessar o proxy HTTP autorizado. As portas desse proxy
são temporárias; para descartar configuração vencida, o arquivo temporário de
propriedades foi atualizado com `HTTPS_PROXY` **dentro da mesma execução** antes de
iniciar Java. A falha permaneceu. Não foram alterados certificados, validação TLS,
repositórios, dependências, permissões de rede ou a distribuição Gradle.

Evidência final: `logs/android-inprocess-20261029.log`. O texto “Plugin ... was not
found” é consequência dessa resolução de rede bloqueada, e não comprova que a
versão configurada do plugin seja inválida. A tarefa não chegou à compilação do
código Flutter/Android, nem produziu um APK. O próximo passo continua sendo compilar
num ambiente autorizado em que a JVM consiga acessar os repositórios oficiais.

Também foi conferido o cache padrão de dependências do usuário, sem ler
credenciais ou chaves: `~/.gradle/caches/modules-2/files-2.1` não existe. Não há
cópias disponíveis nesse cache do plugin Kotlin DSL 5.2.0, AGP 8.11.1 ou Kotlin
Gradle Plugin 2.2.20 para transferir ao diretório temporário e completar um build
`--offline`. Portanto, não foi repetida uma compilação offline sem as dependências
necessárias.

## Histórico da conexão inicial do Samsung em 30/10/2026

O Mac identificou um Samsung físico no barramento USB. Após a ativação da
depuração USB informada pela usuária, a identificação USB mudou, mas
`adb devices -l` continuou sem listar dispositivos nesta execução. Reiniciar
o servidor ADB não alterou o resultado. Não é possível concluir apenas a
partir disso que a autorização RSA foi recusada no aparelho. O inventário USB
também informou uma falha de acesso à interface de dispositivo pelo processo.

Não existiam APKs em `mobile/build/app/outputs/flutter-apk/`, logs de execução
manual do instalador nem cache das dependências Gradle. A depuração USB não
resolve a restrição de compilação Gradle previamente verificada no ambiente.

Foi preparado `mobile/tool/install_android_local.sh` para execução manual no
Terminal do Mac. Ele mantém `lib/main.dart`, o endpoint HTTPS v2 padrão e a
instalação com preservação dos dados; não publica o aplicativo. O servidor
ADB sem dispositivos criado durante a investigação foi encerrado ao final.
A instalação e a execução ainda não estavam confirmadas naquele momento.
Posteriormente, a usuária iniciou o comando no Terminal e autorizou o aparelho;
o build, a instalação e a abertura foram concluídos conforme o resultado atual
registrado no início deste documento.
