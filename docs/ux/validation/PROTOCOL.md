# Roteiro proposto de avaliação de UX

Versão de preparação — 29/10/2026. **Nenhum teste com profissionais foi realizado como parte desta entrega.** Este roteiro orienta uma avaliação futura do fluxo e da interface; não avalia capacidade diagnóstica, desempenho clínico de modelos nem eficácia de tratamento.

## Objetivo e participantes

Observar se profissionais da saúde, sem exigir especialização em odontologia ou estomatologia, conseguem percorrer o pipeline, compreender o caráter simulado, corrigir entradas e reconhecer quando uma classe não foi confirmada.

Usar imagens de teste disponibilizadas e autorizadas para o projeto. Não coletar nome de paciente nem transformar o questionário demonstrativo em atendimento. Identificar participantes por códigos e registrar resultados de forma separada dos testes automatizados. Quantidade de participantes, recrutamento e procedimentos acadêmicos da avaliação devem ser definidos com o orientador antes da execução.

## Preparação de cada sessão

- Registrar código do participante, versão do app/protótipo, sistema operacional, tamanho de tela, tema e modo de execução.
- Explicar que os módulos e resultados são simulados e que se está avaliando a experiência do sistema, não o conhecimento clínico do participante.
- Oferecer imagens previamente selecionadas da biblioteca autorizada e identificar sua origem. Não fazer upload automático ao abrir referências.
- Solicitar que o participante descreva dúvidas e expectativas durante as tarefas, sem indicar previamente o caminho correto.
- Registrar início/fim e ajuda fornecida. Não interpretar demora de rede como dificuldade de navegação: separar espera técnica de tempo ativo.

O aplicativo deve manter sorteio por nova análise. Para observar categorias específicas de resultado ou exceções raras, usar os mockups de exemplo/fixtures; marcar essa sessão como avaliação do protótipo correspondente, não como execução cloud real. Não exigir que o usuário repita análises até obter um risco específico.

## Tarefas

| Tarefa | Enunciado sugerido | Observar | Critério de sucesso |
| --- | --- | --- | --- |
| Iniciar | “Comece uma análise usando esta imagem de teste.” | Descoberta de Nova análise, captura/galeria, prévia e envio | Imagem confirmada segue à detecção; uma análise e uma imagem identificáveis |
| Corrigir recorte | “A área selecionada não corresponde à que você quer analisar. Ajuste-a.” | Descoberta do editor, zoom, alças, confirmação | Pixels corrigidos aparecem e seguem à avaliação de qualidade |
| Trocar fotografia | “Em vez de ajustar esta imagem, use outra fotografia.” | Diferença entre recortar e substituir | Nova imagem volta à detecção; decisões anteriores não ficam ativas |
| Sem detecção | “Nenhuma região foi encontrada. Continue por recorte manual.” | Compreensão da recuperação e de seus limites | Região válida é definida antes de qualquer classificação |
| Reenviar após falha | “Nenhuma região foi encontrada. Prefira uma nova fotografia.” | Facilidade de retorno | Aquisição e detecção são executadas novamente |
| Rejeitar qualidade | “Você considera que a imagem não permite continuar. Como procede?” | Compreensão da decisão humana | Retorno à aquisição; motivo fica registrado; não avança à CNN |
| Concordar | “Compare a sugestão com as referências e confirme a sugestão para este exercício.” | Leitura da classe, galeria e ação principal | Confirmação explícita e questionário correspondente |
| Discordar | “Para este exercício, escolha outra classe como mais semelhante.” | Descoberta das cinco alternativas e ampliação | Sugestão original preservada; seleção distinta registrada |
| Declarar incerteza | “Você não concorda, mas não consegue escolher uma classe alternativa.” | Ausência de coerção para confirmar | Incerteza registrada; fluxo continua; classe provisória visível |
| Responder/revisar | “Preencha o formulário, volte a uma seção e corrija uma resposta.” | Seções, progresso, obrigatoriedade e edição | Resposta nova aparece na revisão; resultado anterior invalidado |
| Rever classe | “Volte à comparação e altere a classe usada no formulário.” | Previsibilidade da invalidação | Questionário correto; respostas incompatíveis não são reutilizadas |
| Consultar biblioteca | “Consulte uma referência e depois retome a análise.” | Menu flutuante e orientação entre abas | A análise retorna à mesma etapa, com dados válidos preservados |
| Recuperar conexão | “O envio falhou. Tente continuar quando a conexão voltar.” | Clareza da mensagem e confiança no estado | Mesma análise/entrada; sem avanço parcial ou troca silenciosa para offline |
| Interpretar resultado | “Explique o que esta tela informa e o que ela não permite concluir.” | Compreensão do risco simulado, orientação e incerteza | Reconhece ausência de diagnóstico/porcentagem e aviso provisório, quando aplicável |
| Encerrar/exportar | “Conclua a análise e exporte o registro deste exercício.” | Descoberta das ações e separação de nova análise | Conclusão registrada; JSON sem pixels nem identificação pessoal desnecessária |

As três telas de risco devem ser avaliadas como exemplos de compreensão de mensagem; não há resposta clínica correta a inferir das fotos.

## Métricas e anotações

| Medida | Definição |
| --- | --- |
| Conclusão da tarefa | Completa sem ajuda, completa com ajuda ou não concluída |
| Tempo total | Tempo entre início e fim da tarefa, incluindo espera |
| Tempo ativo | Tempo na tarefa, separado de pausa do app, espera técnica e consulta a outras abas |
| Retornos | Quantidade e motivo; distinguir revisão intencional de desorientação |
| Correções | Recorte, imagem, classe e respostas alteradas |
| Dificuldades | Ação tentada, expectativa verbalizada, resposta da interface e ajuda fornecida |
| Interrupções | Cancelamento/abandono explícito e etapa; não inferir causa sem relato |
| Consistência | Imagem/recorte/classe/questionário/resultado correspondem às entradas atuais |
| Compreensão | Simulação, ausência de diagnóstico e estado de classe provisória entendidos |

Guardar o resultado da observação separado do JSON técnico do aplicativo. O JSON pode conter versão, origem da execução (manual/automatizada/mockup), identificadores, etapas, horários, decisões, retornos e eventos; não deve conter as imagens.

## Verificação de acessibilidade

Repetir tarefas essenciais nos temas claro e escuro, em tela pequena e com fonte ampliada. Verificar ordem de leitura com VoiceOver/TalkBack, rótulos dos botões, foco após transições, ações acessíveis do recorte, contraste e áreas de toque. Verificar que a redução de movimento não impede entendimento nem avanço.

Menus, avisos e teclado não devem encobrir campos ou ações. Resultado, seleção, erro e confirmação devem possuir texto/ícone além de cor. Preferências do sistema não podem alterar a identidade ou os dados da análise.

## Encerramento da observação

Perguntar quais etapas pareceram pouco claras, quais ações eram esperadas e o que o participante mudaria. Separar observação de comportamento, relato do participante e interpretação do avaliador. Registrar sugestões para revisão, sem apresentar a avaliação de usabilidade como validação clínica.

## Limitações previstas

- Sem persistência, fechamento forçado pode perder a sessão; não prometer registro recuperável de abandono nesses casos.
- As fotografias classificadas extraídas da Figura 2 de Gomes et al. são pequenas; a limitação visual deve ser explicitada e considerada na análise das tarefas de comparação.
- Falhas/saídas controladas em mockups e testes automatizados demonstram caminhos possíveis, não frequência real de falhas ou desempenho clínico.
- O roteiro precisa ser executado e seus resultados documentados posteriormente; não há métricas de participantes preenchidas neste documento.
