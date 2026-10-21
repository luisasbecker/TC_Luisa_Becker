# Pipeline Bucal — iOS e Android

Aplicativo Flutter local, sem servidor. Mantém o protótipo acadêmico: todos os módulos de IA são simulações determinísticas, não modelos clínicos. A versão Python/Streamlit continua disponível na raiz.

## Executar

Requisitos usados nesta preparação: Flutter 3.41.7 / Dart 3.11.5; Xcode no macOS para iOS; JDK 17 e Android SDK para Android. O `pubspec.lock` fixa as dependências.

```sh
cd mobile
flutter pub get
flutter analyze
flutter test
flutter run -d <identificador-do-dispositivo>
```

Para iPhone, abra `ios/Runner.xcworkspace` depois de resolver as dependências. Se necessário:

```sh
flutter build ios --config-only
cd ios
pod install
open Runner.xcworkspace
```

Em Runner → Signing & Capabilities, selecione sua equipe. Selecione o iPhone como destino e execute Run. A conta Apple precisa estar autenticada; o aparelho deve estar desbloqueado e autorizado para desenvolvimento.

As configurações geradas (`Generated.xcconfig`, `.dart_tool`, `local.properties`) não são versionadas. Na execução assistida, apontam para uma cópia temporária do SDK. Execute `flutter pub get` e `flutter build ios --config-only` com seu Flutter habitual para regenerá-las antes de continuar em outra sessão.

## Fluxo

1. Imagem da galeria ou câmera, com tratamento de cancelamento e recuperação da seleção interrompida no Android.
2. Orientação corrigida, cópia de trabalho sem metadados e dimensão máxima de 2560 pixels.
3. Seleção sobre a imagem, com quatro pontos arrastáveis e movimento da área selecionada. É possível selecionar a imagem inteira ou importar uma imagem já corrigida.
4. A confirmação materializa os pixels do recorte. A mesma imagem e seu hash acompanham foco, classificação, questionário e resultado. A original aparece somente na comparação.
5. Validação visual, com opção de ajustar novamente o recorte ou encerrar por qualidade inadequada.
6. Confirmação ou correção da classe sugerida; registro de feedback para curadoria futura.
7. Três respostas obrigatórias, específicas da classe final; modelo multimodal simulado correspondente.
8. Resultado explicitamente simulado, orientação profissional e compartilhamento voluntário do resumo JSON sem bytes de imagem.

A sessão fica em memória e é descartada no reinício/encerramento. Câmera, seletor de fotos e compartilhamento podem usar arquivos temporários do sistema. Não há banco de pacientes, upload para servidor ou retreinamento. Use imagens sintéticas, não imagens identificáveis de pacientes.

## Testes e verificação em 21/10/2026

- `flutter analyze --no-pub`: passou após a implementação.
- Núcleo Dart: 14 cenários passaram com `dart --packages=.dart_tool/package_config.json tool/verify_pipeline.dart`. Esse executor dispensa o servidor local usado por `flutter test`.
- `flutter test --no-pub`: bloqueado antes da execução dos testes por proibição de abrir socket local. Os testes de widgets estão escritos, mas não foram validados neste ambiente.
- Testes Python executados: 33 passaram; incluem recorte por pixels e fluxo completo. A suíte Streamlit não foi executada porque o pacote não está instalado no Python disponível.
- CocoaPods: instalação de dependências concluída.
- Build/instalação iOS: **concluídos pelo Xcode após nova autenticação da conta Apple**. A versão Release foi instalada no iPhone de Luisa e confirmada na lista Installed Apps como Pipeline Bucal, build 1, identificador `br.com.luisabecker.pipelineBucal`. O esquema Run usa Release sem depurador. Após a orientação para confiar no certificado em Ajustes → Geral → VPN e Gerenciamento de Dispositivo, o usuário confirmou o sucesso da instalação. Os testes completos do fluxo no aparelho serão feitos pelo usuário.
- Build Android: **não concluído**. O download do Gradle falhou com `UnknownHostException: services.gradle.org`.
- Nenhum envio para GitHub, TestFlight, App Store Connect ou Google Play foi feito.

A instalação confirmada não equivale a testes de uso no aparelho. Após confiar no certificado, abra o app e valide câmera, galeria, recorte por toque, comparação da original, compartilhamento e retorno após interrupções. Execute também `flutter test` e conclua o build Android quando o ambiente permitir.

## Distribuição de teste, em etapa posterior

Os identificadores iniciais são `br.com.luisabecker.pipelineBucal` no iOS e `br.com.luisabecker.pipeline_bucal` no Android. Confirme-os antes do primeiro registro nas lojas.

### iOS / TestFlight

Configure a equipe com acesso à distribuição, o registro no App Store Connect e a assinatura, depois:

```sh
flutter build ipa --release
```

A equipe pessoal usada na tentativa de instalação não comprova inscrição no programa de distribuição. Ícone, metadados da loja, política de privacidade e revisão da apresentação como protótipo ainda precisam ser concluídos. Os ícones atuais são os padrões do projeto Flutter.

### Android / teste interno

Copie `android/key.properties.example` para `android/key.properties` e preencha com sua chave de upload. Não versione chaves ou senhas. Builds release sem esse arquivo são bloqueados para evitar usar a assinatura de debug como distribuição.

```sh
flutter build apk --debug
flutter build appbundle --release
```

Referências oficiais: https://docs.flutter.dev/deployment/ios e https://docs.flutter.dev/deployment/android.
