# Verificação da interface Flutter — 29/10/2026

A implementação utiliza os componentes e temas reais, um transporte de fixture explícito para testes e as imagens locais autorizadas. Nenhum resultado desta verificação representa teste com profissionais ou inferência clínica.

## Execuções

**Verificação final consolidada:** 71 testes passaram, sem omissões, após todos os ajustes de proveniência, navegação e redução de movimento. Esta execução incluiu `PIPELINE_PYTHON` e `PYTHONPATH`, portanto também executou o contrato contra o Python real. Log: `logs/flutter-final-71-tests.log`. A análise estática global final não encontrou problemas. As execuções intermediárias abaixo explicam as revisões; não devem ser somadas ao total final.

| Verificação | Resultado observado |
|---|---|
| Suíte Flutter completa, após navegação centralizada e redução de movimento | 69 testes passaram; 1 contrato Python foi omitido nessa execução por ausência de variáveis de ambiente. |
| Fluxos UI após ajuste final de proveniência de sessões | 9 testes passaram em `test/ux_flow_test.dart`. |
| Regressões de acessibilidade incorporadas à suíte | 3 testes passaram: galeria, imagem ampliada e seleção de execução em 320×568 com fonte a 250%. |
| Capturas com fontes e imagens decodificadas | 1 teste de geração passou, produzindo 10 PNGs dos widgets reais. |

O último ajuste de proveniência armazena a origem por sessão, preservando a distinção entre execução manual e fixture mesmo depois de iniciar outra análise. O controlador tem testes próprios para esse caso; a suíte completa acima ocorreu antes desse ajuste final. Não somar as execuções como se fossem testes distintos.

Logs das execuções da UI estão em `logs/flutter-suite-before-provenance.log`, `logs/flutter-ui-final.log` e `logs/flutter-captures.log`.

## O que os testes de UI exercitam

- Percurso pelos botões até cada categoria de risco.
- Discordância e incerteza com continuidade pelo questionário e aviso de classe não confirmada.
- Resultado sem porcentagens e com orientação de avaliação médica.
- Gesto de recorte que altera a região e os pixels exibidos na etapa de qualidade.
- Falha de detecção com correção manual, sem avanço automático sem ROI.
- Navegação entre abas sem perda da análise ou imagem.
- Temas claro/escuro, telefone compacto, fonte ampliada e redução de movimento.
- Mudança da preferência de redução de movimento no sistema durante a execução.
- Sheets e galerias com fonte a 250% sem estouro de layout.

As interações com câmera, seletor do sistema e compartilhamento nativo precisam ser verificadas nos dispositivos. Compilação e instalação nativas têm evidências próprias; estes testes não as substituem.

## Reproduzir

A partir de `mobile/`:

```sh
flutter test
flutter test test/ux_flow_test.dart test/ui_accessibility_test.dart
flutter test --update-goldens tool/capture_ui_test.dart
```

Para incluir o contrato Python local, configure `PIPELINE_PYTHON` e `PYTHONPATH` com o ambiente que possui Pillow. A omissão explícita desse contrato não significa que os testes Dart de contrato foram ignorados.
