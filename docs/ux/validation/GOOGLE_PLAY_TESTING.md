# Preparação para testes no Google Play

> Atualização em 30/10/2026: o usuário adiou a distribuição pelo Google Play por causa da verificação de identidade e escolheu enviar um APK diretamente à pasta OneDrive `TCC_Pipeline_Estomatologia/APK_Android/v1`. O conteúdo abaixo registra o diagnóstico anterior; não representa o plano ativo de distribuição.

Inspeção em 30/10/2026. Este documento registra a preparação; nenhuma versão foi enviada ou publicada.

## Escopo confirmado

- Distribuir primeiro o Android pelo Google Play para testes. iOS/TestFlight fica para a etapa seguinte.
- O usuário confirmou que o aplicativo instalado no Samsung funciona corretamente.
- Manter Pipeline Bucal, o fluxo demonstrativo, os resultados simulados aleatórios por análise e a integração HTTPS atual com Cloud Run.
- Preservar o limite gratuito da cloud; esta preparação não alterou serviços ou faturamento.

## Bloqueio observado no Console

A conta pessoal conectada exige confirmação de identidade mediante documento oficial. A verificação do telefone de contato depende da conclusão das verificações anteriores. O botão **Criar app** está desabilitado, com a instrução de concluir as verificações da conta.

O titular deve concluir a verificação diretamente no Google Play Console. Não incluir documentos de identidade, números de telefone, credenciais ou dados da conta neste repositório.

## Preparação técnica verificada

| Item | Estado |
| --- | --- |
| Application ID Android | `br.com.luisabecker.pipeline_bucal` |
| Versão local | `0.3.0` / código `4` |
| APK instalado | Debug; não é o artefato para envio à loja |
| Configuração de upload | `mobile/android/key.properties` ausente |
| Chave local no projeto | Nenhuma `.jks`/`.keystore` encontrada fora de `build` |
| AAB release | Ainda não gerado |
| Proteção do build | Release bloqueado sem configuração de assinatura |
| Proteção do Git | Chaves e `key.properties` ignorados |
| Alinhamento de 16 KB | ZIP e segmentos ELF de 64 bits do APK debug verificados; validar novamente o release |

## Proposta para a primeira distribuição

Usar a faixa de **teste interno**, restrita aos testadores cadastrados e acessada pelo link de participação. A documentação do Google indica até 100 testadores e permite iniciar essa faixa antes de completar todos os detalhes do app. Isso não remove o bloqueio atual de verificação da conta.

Pendências de decisão do usuário:

1. Quem participa da primeira rodada e quais contas Google devem ser cadastradas como testadores.
2. Qual e-mail está autorizado como contato público de suporte e privacidade. Não presumir autorização para publicar o e-mail usado no login.

## Próximas etapas após as pendências

1. Concluir a verificação da conta e confirmar que a criação do app foi liberada.
2. Criar o cadastro dedicado ao TCC e conferir pacote e código de versão aceitos.
3. Preparar a chave de upload protegida, a configuração local e orientações de backup, sem versionar senhas ou chaves.
4. Gerar AAB release com `lib/main.dart`, preservando o endpoint cloud; verificar assinatura, conteúdo e alinhamento de 16 KB do artefato final.
5. Preparar os textos demonstrativos, contato e política de privacidade coerentes com o tratamento real dos dados, além das declarações solicitadas pelo Console.
6. Cadastrar os testadores autorizados, enviar a versão à faixa interna e verificar seu estado e o link de participação.
7. Validar a instalação pela Google Play no aparelho. A assinatura difere do APK debug: se houver conflito, avaliar a remoção do debug com o usuário, preservando antes qualquer histórico que ele queira exportar.

Não há política de privacidade publicada identificada no projeto. A revisão inicial do código identifica envio de imagem/recorte, respostas e identificadores técnicos à cloud por HTTPS, processamento em memória e histórico local em memória com exportação manual. A ausência de persistência de imagens não elimina o tratamento em trânsito nem os registros técnicos da plataforma. As declarações finais devem refletir essa distinção.

## Fonte

[Google: configurar um teste aberto, fechado ou interno](https://support.google.com/googleplay/android-developer/answer/9845334?hl=pt-BR), consultado no navegador em 30/10/2026.
