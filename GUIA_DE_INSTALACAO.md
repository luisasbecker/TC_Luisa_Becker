# Guia completo de instalação e execução

Este documento explica como baixar, instalar e executar o protótipo **Pipeline para Detecção, Processamento e Classificação de Lesões Bucais em Imagens Clínicas** em outro computador.

O guia foi escrito para pessoas que não trabalham diariamente com Python. Leia a seção correspondente ao sistema operacional da nova máquina.

## Antes de começar

O protótipo:

- utiliza Python e Streamlit;
- não contém modelos reais de inteligência artificial;
- não executa treinamento ou retreinamento;
- não precisa de placa de vídeo dedicada;
- não precisa de TensorFlow, PyTorch, YOLO real ou OpenCV;
- deve ser utilizado somente com imagens simuladas, sem dados identificáveis de pacientes.

Separe aproximadamente 15 a 30 minutos para a primeira instalação. É necessário acesso à internet para baixar o projeto e suas dependências. Depois da instalação, a aplicação é executada localmente no computador.

## Resumo das etapas

1. Instalar Python.
2. Instalar Git, caso seja usado o método recomendado.
3. Baixar o projeto pelo Git ou como arquivo ZIP.
4. Abrir um terminal na pasta do projeto.
5. Criar e ativar um ambiente virtual.
6. Instalar as dependências.
7. Executar os testes.
8. Iniciar a interface Streamlit.
9. Abrir o endereço local no navegador.

## 1. Instalar e verificar o Python

O projeto é compatível com Python 3.11 a 3.14 e foi verificado com Python 3.14. Recomenda-se instalar a versão estável mais recente da linha 3.14.x. Não use uma versão futura, como Python 3.15 ou posterior, até que as dependências do protótipo sejam validadas com ela.

Use apenas o site oficial:

- [Download oficial do Python](https://www.python.org/downloads/)
- [Python 3.14.8](https://www.python.org/downloads/release/python-3148/), versão recomendada no momento da elaboração deste guia;
- [Download do Python para Windows](https://www.python.org/downloads/windows/)
- [Download do Python para macOS](https://www.python.org/downloads/macos/)

### Windows

1. Acesse a página oficial do Python.
2. Baixe o instalador de 64 bits ou o gerenciador de instalação indicado pelo site.
3. Durante a instalação tradicional, habilite a opção **Add Python to PATH**, quando ela for apresentada.
4. Conclua a instalação.
5. Feche e abra novamente o PowerShell.
6. Verifique a instalação:

```powershell
python --version
python -m pip --version
```

O primeiro comando deve mostrar uma versão entre Python 3.11 e 3.14. Não continue se ele mostrar Python 3.10, 3.15 ou outra versão fora dessa faixa.

Se `python` não for reconhecido ou apontar para outra versão, tente selecionar explicitamente a linha 3.14:

```powershell
py -3.14 --version
py -3.14 -m pip --version
```

Se apenas `py -3.14` funcionar, use esse comando para criar o ambiente conforme indicado na seção 5.

### macOS

1. Baixe e execute o instalador oficial para macOS.
2. Abra um novo Terminal.
3. Verifique:

```bash
python3 --version
python3 -m pip --version
```

### Linux

Muitas distribuições já possuem Python. Verifique primeiro:

```bash
python3 --version
python3 -m pip --version
```

No Ubuntu ou Debian, os componentes necessários podem ser instalados com:

```bash
sudo apt update
sudo apt install python3 python3-venv python3-pip
```

Depois da instalação, execute novamente `python3 --version`. Algumas versões de Linux podem fornecer Python 3.10 ou anterior. Se a versão estiver fora da faixa 3.11–3.14, não continue: instale Python 3.14 pelo procedimento oficial da sua distribuição e crie o ambiente com `python3.14 -m venv .venv`.

Em outras distribuições, use o gerenciador de pacotes e a documentação oficial correspondentes.

## 2. Instalar e verificar o Git

O Git é recomendado porque facilita baixar atualizações futuras. Ele não é obrigatório se você optar pelo download em ZIP.

Use o site oficial:

- [Download oficial do Git](https://git-scm.com/downloads/)

### Windows

1. Baixe o Git for Windows.
2. Execute o instalador.
3. Para uma instalação comum, as opções padrão são suficientes.
4. Feche e abra novamente o PowerShell.
5. Verifique:

```powershell
git --version
```

### macOS e Linux

Siga a opção indicada para o seu sistema na página oficial do Git. Depois, verifique:

```bash
git --version
```

No macOS, esse comando pode oferecer a instalação das Command Line Tools. Se isso acontecer, aceite a instalação, aguarde a conclusão, abra novamente o Terminal e repita `git --version`.

No Ubuntu ou Debian, também é possível instalar com:

```bash
sudo apt install git
```

## 3. Baixar o projeto

Escolha apenas um dos métodos a seguir.

### Método A — Clonar com Git (recomendado para atualizações)

Esse método preserva o histórico e permite obter atualizações com `git pull`.

1. Abra a página do repositório:

   [github.com/luisasbecker/TC_Luisa_Becker](https://github.com/luisasbecker/TC_Luisa_Becker)

2. Se o repositório estiver privado, entre no GitHub com uma conta que tenha acesso.
3. Abra o PowerShell no Windows ou o Terminal no macOS/Linux.
4. Vá até a pasta em que deseja guardar o projeto.

No Windows, uma forma segura de acessar a pasta Documentos, inclusive quando ela está redirecionada ao OneDrive, é:

```powershell
Set-Location ([Environment]::GetFolderPath('MyDocuments'))
```

Outra opção é abrir a pasta desejada no Explorador de Arquivos, clicar com o botão direito em uma área vazia e selecionar **Abrir no Terminal**, quando essa opção estiver disponível.

Exemplo universal no macOS ou Linux, usando a pasta pessoal:

```bash
cd ~
```

5. Clone o repositório e entre na pasta:

```bash
git clone https://github.com/luisasbecker/TC_Luisa_Becker.git
cd TC_Luisa_Becker
```

No Windows, o Git for Windows normalmente inclui o Git Credential Manager e pode abrir o navegador para autenticação. Entre na conta que possui acesso ao projeto.

No macOS ou Linux, o navegador só será aberto automaticamente se um gerenciador de credenciais compatível estiver configurado. Se `git clone` pedir uma senha e não abrir o navegador, **não informe a senha da sua conta do GitHub**. Para um primeiro uso, prefira o método ZIP abaixo.

No macOS, as alternativas incluem [GitHub Desktop](https://desktop.github.com/), [GitHub CLI](https://cli.github.com/), token pessoal ou chave SSH. No Linux, utilize GitHub CLI, token pessoal ou chave SSH seguindo a documentação oficial.

Nunca grave senhas ou tokens dentro dos arquivos do repositório.

As instruções oficiais do GitHub estão em:

- [Clonar um repositório](https://docs.github.com/pt/repositories/creating-and-managing-repositories/cloning-a-repository)
- [Armazenar credenciais do GitHub no Git](https://docs.github.com/pt/get-started/git-basics/caching-your-github-credentials-in-git)

### Método B — Baixar como ZIP (mais simples para iniciantes)

Esse método é mais simples e não exige Git, mas não permite atualizar o projeto com `git pull`.

1. Entre no GitHub com uma conta autorizada, caso o repositório seja privado.
2. Abra [a página do projeto](https://github.com/luisasbecker/TC_Luisa_Becker).
3. Selecione o botão **Code**.
4. Selecione **Download ZIP**.
5. Aguarde o download.
6. No Explorador de Arquivos ou Finder, localize o ZIP.
7. Extraia todo o conteúdo. Não execute o projeto de dentro do arquivo compactado.
8. Abra a pasta extraída, normalmente chamada `TC_Luisa_Becker-main`.

Consulte também a documentação oficial: [Baixar arquivos de código-fonte](https://docs.github.com/pt/repositories/working-with-files/using-files/downloading-source-code-archives).

## 4. Confirmar que a pasta correta está aberta

O terminal deve estar na pasta que contém pelo menos estes arquivos:

```text
app.py
requirements.txt
README.md
src/
tests/
```

No Windows, liste os arquivos com:

```powershell
Get-ChildItem
```

No macOS ou Linux:

```bash
ls
```

Se `app.py` e `requirements.txt` não aparecerem, navegue até a pasta correta antes de continuar.

## 5. Criar o ambiente virtual

O ambiente virtual mantém as dependências do protótipo separadas das demais instalações do computador.

### Windows PowerShell

Para selecionar explicitamente Python 3.14:

```powershell
py -3.14 -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Se `py` não estiver disponível, mas `python --version` mostrar uma versão entre 3.11 e 3.14:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
```

Quando o ambiente estiver ativo, `(.venv)` normalmente aparecerá no início da linha do terminal.

#### Se o PowerShell bloquear a ativação

Libere scripts somente para a janela atual e tente novamente:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

Essa configuração termina quando a janela do PowerShell é fechada.

Como alternativa, abra o Prompt de Comando na pasta do projeto e use:

```bat
.venv\Scripts\activate.bat
```

### macOS ou Linux

```bash
python3 -m venv .venv
source .venv/bin/activate
```

Se `python3 --version` não estiver entre 3.11 e 3.14 e você instalou Python 3.14 separadamente, substitua o primeiro comando por `python3.14 -m venv .venv`.

Depois da ativação, os sistemas normalmente passam a aceitar `python` como comando dentro do ambiente.

## 6. Instalar as dependências

Com o ambiente virtual ativo:

```bash
python -m pip install --upgrade pip
python -m pip install -r requirements.txt
```

O arquivo `requirements.txt` declara diretamente:

- Streamlit;
- Pillow;
- `qrcode`.

O `pip` também instalará automaticamente as dependências indiretas necessárias, o que é esperado. Nenhum modelo real de inteligência artificial é baixado.

O pacote `qrcode` gera o QR de acesso móvel inteiramente no computador, sem enviar o endereço a um serviço externo.

## 7. Executar os testes

Ainda com o ambiente virtual ativo:

```bash
python -m unittest discover -s tests -v
```

Ao final, o terminal deve apresentar `OK`. A quantidade de testes pode aumentar em versões futuras do projeto.

## 8. Iniciar o protótipo

Execute:

```bash
python -m streamlit run app.py
```

O Streamlit normalmente abre o navegador automaticamente. Se isso não acontecer, acesse:

[http://localhost:8501](http://localhost:8501)

Mantenha o terminal aberto enquanto estiver usando o protótipo.

Para encerrar:

1. volte ao terminal;
2. pressione `Ctrl+C`;
3. feche a janela do navegador, se desejar.

### Primeiro teste dentro do aplicativo

O upload aceita arquivos PNG, JPG, JPEG e WEBP. Use somente uma imagem sintética ou não clínica, sem dados identificáveis de pacientes.

Para conferir o fluxo principal:

1. envie a imagem simulada;
2. execute o YOLO fantasma;
3. aceite ou corrija o recorte;
4. execute a avaliação de foco e confirme a qualidade visual;
5. execute a CNN fantasma e informe se concorda com a classe de lesão elementar;
6. responda ao questionário simulado;
7. execute o modelo multimodal específico por classe;
8. confira o risco final e o histórico JSON.

Outros desvios do fluxo estão descritos nos [cenários manuais do README](README.md#cenários-manuais-principais).

Para usar o protótipo no iPhone ou Android, conclua primeiro este teste no computador e depois siga o [Guia de apresentação móvel](GUIA_APRESENTACAO_MOBILE.md).

## 9. Executar novamente em outro dia

Não é necessário reinstalar tudo. Abra um terminal na pasta do projeto, ative o ambiente e inicie o Streamlit.

### Windows PowerShell

```powershell
cd "CAMINHO\PARA\TC_Luisa_Becker"
.\.venv\Scripts\Activate.ps1
python -m streamlit run app.py
```

### macOS ou Linux

```bash
cd "/caminho/para/TC_Luisa_Becker"
source .venv/bin/activate
python -m streamlit run app.py
```

Substitua o caminho de exemplo pelo local em que o projeto foi salvo.

## 10. Atualizar o projeto

### Se o projeto foi clonado com Git

Encerre o Streamlit e abra um terminal dentro da pasta do projeto. Atualize os arquivos:

```bash
git pull
```

Em seguida, ative o ambiente virtual.

No Windows PowerShell:

```powershell
.\.venv\Scripts\Activate.ps1
```

No macOS ou Linux:

```bash
source .venv/bin/activate
```

Com o ambiente ativo, atualize as dependências e execute os testes:

```bash
python -m pip install -r requirements.txt
python -m unittest discover -s tests -v
```

### Se o projeto foi baixado como ZIP

Baixe um novo ZIP e extraia-o em uma nova pasta. Essa opção não possui atualização automática nem histórico Git. Preserve separadamente qualquer arquivo pessoal que você tenha colocado na pasta antiga.

O ambiente virtual `.venv` não faz parte do ZIP. Na nova pasta, repita as etapas 4 a 8 deste guia: confirme a pasta, crie e ative um novo ambiente, instale `requirements.txt`, execute os testes e inicie o Streamlit.

## 11. Problemas comuns

### `python` não é reconhecido

- Feche e abra novamente o terminal.
- No Windows, tente `py --version`.
- Reinstale o Python e habilite a opção de inclusão no PATH, quando disponível.
- Confirme que a versão está entre Python 3.11 e 3.14.

### `git` não é reconhecido

- Feche e abra novamente o terminal.
- Confirme que o Git foi instalado pelo site oficial.
- Se não quiser instalar Git, use o método de download em ZIP.

### Erro `No module named streamlit`

Ative o ambiente virtual e reinstale as dependências:

```bash
python -m pip install -r requirements.txt
```

### `requirements.txt` não foi encontrado

O terminal está na pasta errada. Navegue até a pasta que contém `app.py` e `requirements.txt`.

### O PowerShell informa que a execução de scripts foi desabilitada

Na mesma janela:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\.venv\Scripts\Activate.ps1
```

### A porta 8501 já está em uso

Use outra porta:

```bash
python -m streamlit run app.py --server.port 8502
```

Depois, acesse [http://localhost:8502](http://localhost:8502).

### O GitHub mostra página não encontrada

Em repositórios privados, o GitHub pode mostrar uma página 404 para quem não está autenticado ou não possui acesso. Entre na conta correta e confirme que ela tem permissão para visualizar `luisasbecker/TC_Luisa_Becker`.

### A clonagem solicita autenticação

Se o Git Credential Manager abrir o navegador, conclua a autenticação na conta autorizada. Se nenhum navegador abrir e o terminal solicitar uma senha, não use a senha da conta do GitHub. Para a instalação mais simples, faça o download em ZIP. Para continuar com Git, configure um dos métodos de autenticação indicados na [documentação oficial do GitHub](https://docs.github.com/pt/get-started/git-basics/caching-your-github-credentials-in-git).

## 12. Checklist final

Antes de considerar a instalação concluída, confirme:

- [ ] Uma versão do Python entre 3.11 e 3.14 está instalada.
- [ ] O projeto foi clonado ou o ZIP foi completamente extraído.
- [ ] O terminal está na pasta que contém `app.py`.
- [ ] O ambiente virtual `.venv` foi criado e ativado.
- [ ] As dependências foram instaladas sem erro.
- [ ] Os testes terminaram com `OK`.
- [ ] A aplicação abriu em `http://localhost:8501` ou na porta alternativa escolhida.
- [ ] Se haverá apresentação no celular, o procedimento de `GUIA_APRESENTACAO_MOBILE.md` foi ensaiado na rede escolhida.

## Uso responsável

Este protótipo é uma ferramenta acadêmica de apoio à validação de fluxo. Ele não realiza diagnóstico, não substitui avaliação profissional e não substitui exames complementares quando indicados. Não utilize imagens reais ou identificáveis de pacientes.
