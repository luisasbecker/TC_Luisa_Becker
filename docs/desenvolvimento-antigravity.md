# Desenvolver no Antigravity com o iPhone conectado

Configuração verificada em **02/11/2026** no Antigravity IDE 2.5.5, com extensões Dart/Flutter 3.146.0, Flutter 3.41.7 e Dart 3.11.5. O iPhone físico conectou ao VM Service em Debug. Uma alteração temporária de interface, salva com **⌘S**, foi aplicada por hot reload em 437 ms; a restauração do código original foi aplicada em 355 ms. Nenhuma alteração visual do teste foi mantida. A sessão foi deixada ativa ao final da preparação; se você a encerrar, inicie novamente com F5.

Abra a pasta **`mobile`** deste repositório no Antigravity IDE, usando **File → Open Folder**. Essa pasta contém `pubspec.yaml` e as configurações de execução em `.vscode/`. O iPhone será o dispositivo físico de desenvolvimento, com o aplicativo executando nele enquanto você edita o código no Mac.

## Preparação

1. Na área de extensões da IDE, mantenha habilitadas **Dart** (`Dart-Code.dart-code`) e **Flutter** (`Dart-Code.flutter`), recomendadas pelo projeto.
2. Se a IDE solicitar o Flutter SDK, selecione uma instalação permanente. Neste Mac, use `/opt/homebrew/share/flutter`. Esse caminho pertence à configuração local da IDE e não foi fixado no repositório. Não selecione uma cópia dentro de `/tmp`.
3. No terminal integrado, já dentro de `mobile`, execute `flutter pub get`. Isso regenera os caminhos locais das dependências; não exige atualizar suas versões. O ambiente de referência usa Flutter 3.41.7 e Dart 3.11.5.
4. Conecte e desbloqueie o iPhone. Mantenha o Modo de Desenvolvedor ativado e autorize a confiança no Mac, se solicitado. Para assinatura, utilize a conta e a equipe de desenvolvimento já configuradas no Xcode.

## Iniciar e editar

1. Abra `lib/main.dart`.
2. Na barra inferior, selecione o iPhone. Se necessário, use a paleta de comandos (**⇧⌘P**) e **Flutter: Select Device**.
3. Em **Run and Debug**, escolha **Pipeline Bucal · desenvolvimento** e pressione **F5** (ou **fn + F5**, conforme o teclado). Aguarde o aplicativo abrir e o debugger se conectar. Se o iPhone solicitar acesso à rede local para as ferramentas de desenvolvimento, permita-o.
4. Edite um arquivo Dart e salve com **⌘S**. Durante a sessão Debug, a IDE solicita **hot reload** quando o arquivo salvo contém alterações. O mesmo vale para salvamentos automáticos, caso você já use essa preferência. A configuração do projeto não ativa o salvamento automático.
5. Confira o resultado no iPhone e a saída em **Debug Console**. Para encerrar a sessão, use o botão de parar na barra de depuração.

O hot reload normalmente preserva o estado da tela. Se houver um erro de compilação, corrija-o e salve novamente. A aplicação instalada em modo Release não oferece hot reload; inicie pela configuração de desenvolvimento da IDE.

## Quando reiniciar

- **Hot restart:** use o comando **Flutter: Hot Restart** quando precisar executar novamente a inicialização (`main`/`initState`) ou começar com o estado do aplicativo limpo. Os dados mantidos apenas em memória serão reiniciados.
- **Parar e executar novamente:** necessário após alterações nativas em iOS/Android, plugins ou configurações de build. Se modificar dependências no `pubspec.yaml`, execute `flutter pub get` antes de iniciar novamente.
- **Xcode:** o scheme `Runner` usa **Run = Debug**, com **Debug executable** habilitado e o inicializador LLDB do Flutter. **Archive = Release** permanece reservado à distribuição. Abra `mobile/ios/Runner.xcworkspace` se precisar revisar assinatura ou o dispositivo.

## Código, cloud e Android

Comece por `lib/features/` para telas e fluxo, `lib/design_system/` para aparência e `lib/core/` para modelos e serviços. O ponto de entrada é `lib/main.dart`.

A execução da IDE mantém o endpoint cloud padrão do aplicativo, sem substituí-lo por localhost ou por uma implementação offline. As chamadas ocorrem ao percorrer as etapas do app. Para ensaiar somente a interface sem chamadas, selecione explicitamente um cenário no painel de demonstração do aplicativo. As configurações da IDE não alteram os recursos nem os limites do serviço cloud.

A mesma configuração Debug serve para Android: conecte um dispositivo com depuração USB autorizada e selecione-o em **Flutter: Select Device** antes de iniciar. Nenhum identificador de aparelho está fixado no projeto.

## Se o dispositivo não aparecer

Confirme cabo, desbloqueio, confiança no computador e Modo de Desenvolvedor. Confira se o iPhone aparece na janela **Devices and Simulators** do Xcode. No terminal integrado, `flutter devices` mostra os destinos reconhecidos; `flutter doctor -v` ajuda a identificar componentes ausentes. Após conectar o aparelho, tente selecioná-lo novamente na IDE.

Para detalhes do hot reload e de sua configuração: [documentação Flutter](https://docs.flutter.dev/tools/hot-reload) e [configurações Dart Code](https://dartcode.org/docs/settings/#dartflutterhotreloadonsave).
