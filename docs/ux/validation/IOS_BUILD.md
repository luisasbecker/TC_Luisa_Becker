# Verificação iOS — 29/10/2026

## Resultado após reconexão do aparelho

**Instalação e abertura confirmadas no iPhone físico.** Às 20:00 (America/Sao_Paulo),
um Clean Build Folder seguido de Run no Xcode recompilou e assinou o aplicativo.
O Xcode passou de `Attaching to Runner on iPhone de Luisa` para **`Running Runner
on iPhone de Luisa`**. A janela Devices confirmou Pipeline Bucal, build **4**, no
iPhone 16 Pro Max com iOS 26.5.2. O produto usa versão **0.3.0**, target
`lib/main.dart` e o endpoint HTTPS v2 padrão; não usa o entrypoint de diagnóstico.

A primeira tentativa às 19:58 instalou o app, mas foi recusada pelo iOS com erro
de segurança na abertura. A investigação local identificou uma divergência entre
o binário `Frameworks/App.framework/App` e o hash selado do pacote assinado. O
perfil de desenvolvimento estava válido (criação em 29/10 e validade até 05/11,
horários registrados em UTC), portanto não foi necessário mudar confiança,
permissões, certificado ou conta Apple.

Após a recompilação limpa, `codesign --verify --deep --strict --verbose=2` retornou
código **0**, `valid on disk` e `satisfies its Designated Requirement`. Isso corrige
a inconsistência do produto compilado, sem alteração na lógica Dart ou no backend.
O diagnóstico inicial está em `logs/ios-launch-signature-error.txt`.

A confirmação de abertura **não equivale a percorrer todo o pipeline no aparelho**.
O fluxo completo, câmera, galeria e compartilhamento ainda exigem teste manual no
dispositivo. Não foi produzida uma captura do aplicativo em primeiro plano nesta
verificação. As capturas Flutter existentes continuam sendo renderizações de widgets.

## Histórico da primeira compilação

O workspace `mobile/ios/Runner.xcworkspace` compilou com sucesso pelo Xcode 16.4. O build final às 02:25 incluiu os ajustes de histórico e origem por sessão; uma nova execução às 02:27 iniciou a instalação no iPhone de Luisa.

O `Info.plist` do produto compilado foi conferido: versão **0.3.0**, build **4**, identificador `br.com.luisabecker.pipelineBucal`, iOS mínimo 13.0. A janela Devices do Xcode confirmou o aplicativo Pipeline Bucal com versão de build **4** entre os instalados no iPhone 16 Pro Max conectado.

A abertura pelo Xcode ficou aguardando o desbloqueio do aparelho: “Unlock iPhone de Luisa to Continue”. Esse estado não comprova a execução do novo fluxo no aparelho. Desbloquear o iPhone permite concluir o Run e a verificação manual; nenhum código de desbloqueio foi solicitado ou utilizado.

O build via linha de comando dentro do ambiente restrito não conseguiu acessar os serviços CoreSimulator/CoreDevice e reportou erro de leitura de workspace. O mesmo workspace foi aberto e compilado com sucesso pela interface oficial do Xcode. Não foram alteradas permissões de segurança, assinatura ou conta Apple para contornar o problema.

As capturas em `docs/ux/screenshots/flutter/` são renderizações automatizadas dos widgets, não capturas do iPhone. A comunicação HTTPS pública v2 e os três riscos foram verificados separadamente pelo smoke Python; não se deve chamar esse teste de validação no aparelho.

Não houve Archive, TestFlight ou publicação na App Store. A equipe pessoal de desenvolvimento existente foi mantida.
