<!-- Modelo para encaminhamento. Substitua o marcador pelo link privado autorizado; não publique links pessoais de compartilhamento no Git. -->

Olá, pessoal! Estou disponibilizando uma versão de testes do **Pipeline Bucal**, aplicativo do meu TCC, para avaliar o funcionamento do fluxo e a experiência de uso.

**Download:** <LINK_PRIVADO_DE_DOWNLOAD>

Na pasta, baixem o arquivo **Pipeline_Bucal_Android_v1_0.3.0.apk**. É uma versão de desenvolvimento (debug) destinada a testes. Esta versão é para celulares e tablets com **Android 7.0 ou mais recente**. O APK não funciona no iPhone; os testes de iOS serão disponibilizados separadamente pelo TestFlight.

**Como instalar**

1. Abram o link no aparelho Android e baixem o APK completo. Se o OneDrive mostrar apenas uma prévia, usem a opção de download.
2. Abram o arquivo baixado e escolham **Instalar**.
3. Se o Android pedir permissão para instalar por essa origem, autorizem somente o aplicativo usado para abrir o arquivo, como o navegador ou o gerenciador de arquivos. Essa permissão pode ser retirada depois da instalação.
4. Se aparecer outro bloqueio ou alerta de segurança, não desativem as proteções do aparelho: avisem no grupo para verificarmos a mensagem.
5. Se o link pedir acesso ao OneDrive, informem no grupo o e-mail com que vão acessar para que eu possa liberar o download.
6. Abram **Pipeline Bucal**. Não é necessário ativar modo de desenvolvedor nem depuração USB.

**O que esta versão faz**

Os módulos de detecção YOLO, avaliação automática de foco, classificação CNN, sistema inteligente e modelos multimodais estão **simulados**. Ainda não foram implementados modelos reais de inteligência artificial, treinamento ou retreinamento.

A classe de lesão e o nível de risco — **baixo, médio ou alto** — são sorteados por análise e podem se repetir. Esses resultados **não têm valor clínico, não representam a condição da imagem e não são diagnósticos**. Não usem o aplicativo para avaliar pacientes ou tomar decisões de saúde.

A comunicação com o **Google Cloud Run é real**: no modo cloud, a imagem escolhida, seus recortes, as respostas e as informações técnicas da análise são enviados por HTTPS para executar o fluxo simulado. Mantenham conexão com a internet durante esse percurso. O modo offline é uma demonstração local separada.

Usem apenas as **imagens de exemplo do TCC** ou imagens cujo uso esteja autorizado e que não identifiquem pessoas. Não incluam rostos, nomes, documentos ou outras informações pessoais.

**O que gostaria que vocês observassem**

- Conseguem selecionar uma imagem e entender o próximo passo em cada tela?
- Ao corrigir o recorte manualmente, a imagem recortada continua corretamente nas etapas seguintes?
- É possível concordar, discordar, escolher outra classe ou indicar “Não consigo determinar” e continuar?
- O questionário, os retornos, a revisão e o resultado são claros? Há botões, textos ou telas difíceis de usar?
- Uma nova análise começa corretamente? O aplicativo apresenta erros ou fecha sozinho?

Enviem o feedback aqui no grupo, informando **modelo do aparelho, versão do Android, etapa em que estavam, o que fizeram e o que aconteceu**. Se houver erro, copiem o texto da mensagem. Capturas de tela podem ajudar, desde que não mostrem pacientes, informações pessoais ou notificações privadas.

O objetivo é validar o percurso das imagens e informações, as correções e a usabilidade. Obrigada pela participação!
