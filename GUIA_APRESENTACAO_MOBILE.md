# Guia de apresentação do Pipeline Bucal no iPhone

Este guia prepara um computador Windows para executar o protótipo e permite abrir o fluxo completo no iPhone. A solução é uma **aplicação web local adicionável à Tela de Início**. Ela não é um aplicativo nativo, não usa TestFlight e não funciona sem o computador servidor ligado.

## O que levar para a reunião

- o computador Windows com o repositório atualizado e já testado;
- o iPhone carregado;
- uma ou mais imagens JPG ou PNG totalmente anônimas e autorizadas para a apresentação;
- opcionalmente, um cabo USB e um carregador — o cabo não transporta o acesso ao aplicativo;
- este guia disponível no computador.

Faça a preparação e um ensaio completo antes de sair. A rede da reunião pode bloquear a comunicação entre aparelhos; por isso, o Hotspot móvel do próprio Windows é a alternativa recomendada.

## Preparação única no outro computador

1. Abra a pasta já instalada do projeto.
2. Atualize o repositório. Abra o PowerShell nessa pasta e execute:

   ```powershell
   git pull
   ```

3. Dê dois cliques em `INICIAR_PIPELINE_MOBILE.bat`.
4. Na primeira execução, aguarde a instalação dos componentes. A internet é necessária somente para essa preparação.
5. Se o Firewall do Windows solicitar autorização para o Python, permita o acesso na rede usada para a apresentação. Faça isso somente em uma rede confiável.
6. O navegador do computador será aberto e o terminal mostrará o endereço para o celular.

Se o computador ainda não tiver o projeto, siga primeiro o [guia completo de instalação](GUIA_DE_INSTALACAO.md). Depois volte a esta seção.

## Opção 1 — computador e iPhone no mesmo Wi-Fi

1. Conecte o computador e o iPhone exatamente à mesma rede Wi-Fi.
2. No computador, dê dois cliques em `INICIAR_PIPELINE_MOBILE.bat`.
3. Se aparecer uma lista de redes, escolha a linha chamada **Wi-Fi** e confira se o endereço começa, por exemplo, com `192.168.` ou `10.`.
4. Mantenha aberta a janela preta/azul do iniciador durante toda a apresentação.
5. No computador, abra a barra lateral do Pipeline Bucal. Ela exibirá o endereço e um QR.
6. No iPhone, abra a Câmera, aponte para o QR e toque no aviso para abrir no Safari.

Redes de convidados de hotéis, universidades e empresas podem impedir que um aparelho encontre o outro. Se o site não abrir, use o Hotspot móvel descrito a seguir.

## Opção 2 — Hotspot móvel do Windows

Ative o hotspot **antes** de abrir o iniciador, para que ele possa encontrar o endereço correto.

1. No Windows, abra **Configurações > Rede e Internet > Hotspot móvel**.
2. Escolha compartilhar a conexão por **Wi-Fi**.
3. Confira ou edite o nome e a senha da rede.
4. Ative **Hotspot móvel**.
5. No iPhone, abra **Ajustes > Wi-Fi** e conecte-se à rede criada pelo computador.
6. No computador, dê dois cliques em `INICIAR_PIPELINE_MOBILE.bat`.
7. Se o iniciador mostrar mais de uma rede, selecione a interface associada ao hotspot. Ela costuma ter um endereço como `192.168.137.1`, mas o número pode ser diferente.
8. Use a Câmera do iPhone para ler o QR mostrado na barra lateral do aplicativo.

O USB pode permanecer conectado para alimentação, porém ele não substitui o Wi-Fi ou o hotspot neste protótipo.

## Adicionar o Pipeline Bucal à Tela de Início

Execute esta etapa depois que o endereço estiver aberto no **Safari**:

1. toque no botão **Compartilhar**;
2. role a lista e toque em **Adicionar à Tela de Início**;
3. mantenha o nome **Pipeline Bucal**;
4. toque em **Adicionar**;
5. abra o ícone criado e confirme que a tela inicial do protótipo aparece.

O atalho guarda o endereço de rede daquele computador. Se a rede ou o computador mudar, apague o atalho antigo e repita o procedimento com o novo endereço.

## Ensaio do fluxo completo no iPhone

1. Abra **Pipeline Bucal** pelo Safari ou pelo ícone da Tela de Início.
2. Toque em **Browse files/Procurar arquivos** e selecione uma imagem JPG ou PNG anônima.
3. Execute o **YOLO fantasma**.
4. Teste **Recorte inadequado > Recortar diretamente na imagem**.
5. Arraste o retângulo e os pontos de controle com o dedo, confira a prévia e confirme o recorte.
6. Execute a avaliação de foco e aceite a qualidade visual.
7. Execute a CNN fantasma e escolha concordar ou discordar.
8. Responda ao questionário simulado.
9. Execute o modelo multimodal específico por classe.
10. Confirme a exibição de risco baixo, médio ou alto de câncer, da orientação médica e do histórico JSON.

O protótipo corrige a orientação registrada pelo aparelho, remove metadados da cópia de trabalho e reduz imagens muito grandes para melhorar a navegação. Os blocos continuam sendo stubs: não existe análise clínica real.

## Se o iPhone não abrir o endereço

Faça estas verificações, na ordem:

1. confirme que a janela do iniciador continua aberta;
2. confirme que o aplicativo abre no navegador do próprio computador;
3. confirme que iPhone e computador estão na mesma rede ou hotspot;
4. digite no Safari exatamente o endereço mostrado no terminal, incluindo `http://` e `:8501`;
5. aceite a solicitação de acesso à rede local, caso o iPhone a apresente;
6. desligue temporariamente uma VPN no iPhone ou no computador;
7. no Firewall do Windows, autorize o Python na rede em uso;
8. se estiver em uma rede de convidados, troque para o Hotspot móvel do Windows;
9. encerre pressionando `Enter` no terminal, feche-o e execute novamente `INICIAR_PIPELINE_MOBILE.bat`.

Se a mensagem disser que a porta 8501 já está em uso, existe outra execução aberta. Localize o terminal anterior, pressione `Enter` e tente novamente.

### Se o alerta do Firewall foi negado ou não apareceu

Não desative o Firewall do Windows. Em uma rede confiável, crie uma liberação restrita somente à porta do protótipo:

1. encerre o iniciador pressionando `Enter` no terminal;
2. pesquise por **Firewall do Windows Defender com Segurança Avançada** e abra-o como administrador;
3. selecione **Regras de Entrada > Nova Regra**;
4. escolha **Porta**, depois **TCP**, e informe a porta local específica `8501`;
5. escolha **Permitir a conexão**;
6. marque **Privado**. Use **Público** somente se for indispensável e se a rede da reunião for confiável;
7. dê à regra o nome `Pipeline Bucal - porta 8501` e conclua;
8. execute novamente `INICIAR_PIPELINE_MOBILE.bat`.

Prefira o Hotspot móvel do Windows quando a rede do local for pública ou de convidados. Depois da apresentação, volte a **Regras de Entrada**, localize `Pipeline Bucal - porta 8501` e exclua essa regra. Isso não remove o protótipo; apenas fecha a liberação criada para a demonstração.

## Encerrar com segurança

1. No computador, volte ao terminal do iniciador.
2. Pressione `Enter`.
3. Confirme o encerramento se o Windows perguntar.
4. Feche as abas do protótipo.
5. Desative o Hotspot móvel, caso tenha sido utilizado.

As imagens ficam apenas na memória da sessão e não são gravadas automaticamente pelo protótipo. O acesso local não possui autenticação nem HTTPS; use somente uma rede controlada, imagens anônimas e encerre o servidor imediatamente após a demonstração.

## Limite desta versão

Esta entrega atende à demonstração local no iPhone e também pode ser aberta pelo navegador de um Android na mesma rede. Uma distribuição real por TestFlight ou pelas lojas exigirá uma etapa posterior: aplicativo móvel próprio, hospedagem segura, autenticação, políticas de privacidade, validação clínica e as contas de desenvolvedor exigidas pelas plataformas.
