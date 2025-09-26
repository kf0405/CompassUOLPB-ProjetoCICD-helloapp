# CompassUOLPB-ProjetoCICD-helloapp
# Projeto de CI/CD com GitHub Actions e ArgoCD

Este repositório contém um guia passo a passo para configurar um pipeline de Integração Contínua e Entrega Contínua (CI/CD) utilizando GitHub Actions para automação de build/push e ArgoCD para GitOps e deploy contínuo em um cluster Kubernetes.

## Tabela de Conteúdos
1.  [Fase 1: Preparação e Pré-requisitos](#fase-1-preparação-e-pré-requisitos)
2.  [Fase 2: Criação da Aplicação e Repositórios](#fase-2-criação-da-aplicação-e-repositórios)
3.  [Fase 3: Criação dos Manifestos Kubernetes](#fase-3-criação-dos-manifestos-kubernetes)
4.  [Fase 4: Configuração do CI/CD com GitHub Actions](#fase-4-configuração-do-cicd-com-github-actions)
5.  [Fase 5: Configuração do ArgoCD](#fase-5-configuração-do-argocd)
6.  [Fase 6: Teste e Verificação](#fase-6-teste-e-verificação)

---

## Fase 1: Preparação e Pré-requisitos

Antes de começar, garanta que todo o ambiente necessário esteja configurado.

### Contas e Acessos:
* **GitHub:** Crie uma conta no [GitHub](https://github.com/).
* **Docker Hub:** Crie uma conta no [Docker Hub](https://hub.docker.com/) e gere um **Access Token** (vá em `Account Settings` > `Security` > `New Access Token`). Guarde este token, pois ele será usado como sua senha.

### Ferramentas Locais:
* Instale o [Git](https://git-scm.com/downloads).
* Instale o [Python 3](https://www.python.org/downloads/).
* Instale o [Docker Desktop](https://www.docker.com/products/docker-desktop/).
* Instale o [Rancher Desktop](https://rancherdesktop.io/), habilite o Kubernetes e certifique-se de que o `kubectl` está funcionando com o comando `kubectl get nodes`.
* Instale o ArgoCD no seu cluster Kubernetes local seguindo o [guia oficial](https://argo-cd.readthedocs.io/en/stable/getting_started/).

## Fase 2: Criação da Aplicação e Repositórios

Vamos criar a base do projeto: a aplicação e os repositórios para o código e os manifestos de deploy.

### Crie os Repositórios no GitHub:
1.  Crie um repositório público chamado `hello-app`. É aqui que ficará o código da aplicação FastAPI, o `Dockerfile` e o workflow do GitHub Actions.
2.  Crie outro repositório público chamado `hello-manifests`. Este repositório conterá apenas os arquivos de configuração (manifestos) do Kubernetes.

### Desenvolva a Aplicação FastAPI:
1.  Clone o repositório `hello-app` para sua máquina.
2.  Dentro dele, crie um arquivo `main.py` com o seguinte conteúdo:
    ```python
    from fastapi import FastAPI

    app = FastAPI()

    @app.get("/")
    async def root():
        return {"message": "Hello World"}
    ```
3.  Crie um arquivo `requirements.txt` com as dependências:
    ```
    fastapi
    uvicorn
    ```
4.  No mesmo repositório, crie um arquivo chamado `Dockerfile` para "empacotar" a aplicação:
    ```dockerfile
    # Usar uma imagem base do Python
    FROM python:3.9-slim

    # Definir o diretório de trabalho
    WORKDIR /app

    # Copiar o arquivo de dependências e instalar
    COPY requirements.txt .
    RUN pip install --no-cache-dir -r requirements.txt

    # Copiar o resto do código da aplicação
    COPY . .

    # Expor a porta 80 e rodar a aplicação
    EXPOSE 80
    CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]
    ```

## Fase 3: Criação dos Manifestos Kubernetes

Agora, vamos definir como nossa aplicação deve ser executada no Kubernetes.

1.  **Clone o Repositório de Manifestos:**
    Clone o repositório `hello-manifests` para sua máquina.

2.  **Crie o Manifesto de Deployment (`deployment.yaml`):**
    Dentro do `hello-manifests`, crie o arquivo `deployment.yaml`. Substitua `SEU_USUARIO_DOCKERHUB` pelo seu nome de usuário.
    ```yaml
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: hello-app-deployment
    spec:
      replicas: 2
      selector:
        matchLabels:
          app: hello-app
      template:
        metadata:
          labels:
            app: hello-app
        spec:
          containers:
          - name: hello-app
            image: SEU_USUARIO_DOCKERHUB/hello-app:latest # Esta linha será atualizada pela automação
            ports:
            - containerPort: 80
    ```

3.  **Crie o Manifesto de Serviço (`service.yaml`):**
    No mesmo repositório, crie `service.yaml` para expor sua aplicação.
    ```yaml
    apiVersion: v1
    kind: Service
    metadata:
      name: hello-app-service
    spec:
      selector:
        app: hello-app
      ports:
        - protocol: TCP
          port: 80
          targetPort: 80
    ```

4.  **Envie os Manifestos:**
    Faça o `commit` e o `push` dos dois arquivos (`deployment.yaml` e `service.yaml`) para o repositório `hello-manifests`. No nosso caso, ele se encontra [aqui](https://github.com/kf0405/CompassUOLPB-ProjetoCICD-hellomanifests).

## Fase 4: Configuração do CI/CD com GitHub Actions

Esta é a etapa central da automação. O GitHub Actions irá construir a imagem Docker, publicá-la e atualizar o manifesto de deploy automaticamente.

1.  **Configure a Chave de Deploy:**
    * No seu computador, gere um novo par de chaves SSH:
        ```bash
        ssh-keygen -t ed25519 -C "github_actions" -f ./github-actions-key
        ```
        **Nota:** Não adicione senha à chave.
    * No repositório `hello-manifests`, vá em `Settings` > `Deploy keys` > `Add deploy key`.
    * **Title:** `Actions Deploy Key`
    * **Key:** Cole o conteúdo da chave **pública** (`github-actions-key.pub`).
    * Marque a opção **"Allow write access"** e clique em `Add key`.

2.  **Configure os Segredos do Repositório:**
    * No repositório `hello-app`, vá em `Settings` > `Secrets and variables` > `Actions` e adicione os seguintes segredos:
        * `DOCKER_USERNAME`: Seu nome de usuário do Docker Hub.
        * `DOCKER_PASSWORD`: O Access Token que você gerou no Docker Hub.
        * `SSH_PRIVATE_KEY`: O conteúdo da chave **privada** (`github-actions-key`).

3.  **Crie o Workflow do GitHub Actions:**
    * No repositório `hello-app`, crie a estrutura de pastas `.github/workflows/`.
    * Dentro de `workflows`, crie um arquivo `cicd.yml` com o conteúdo abaixo. Substitua `SEU_USUARIO_DOCKERHUB` e `SEU_USUARIO_GITHUB/hello-manifests.git`.
    ```yaml
    name: CI/CD Pipeline

    on:
      push:
        branches: [ "main" ]

    jobs:
      build-and-push:
        runs-on: ubuntu-latest
        steps:
          - name: Checkout code
            uses: actions/checkout@v3

          - name: Set up Docker Buildx
            uses: docker/setup-buildx-action@v2

          - name: Login to Docker Hub
            uses: docker/login-action@v2
            with:
              username: ${{ secrets.DOCKER_USERNAME }}
              password: ${{ secrets.DOCKER_PASSWORD }}

          - name: Build and push Docker image
            uses: docker/build-push-action@v4
            with:
              context: .
              push: true
              tags: SEU_USUARIO_DOCKERHUB/hello-app:${{ github.sha }}

      update-manifest:
        needs: build-and-push
        runs-on: ubuntu-latest
        steps:
          - name: Checkout manifests repository
            uses: actions/checkout@v3
            with:
              repository: SEU_USUARIO_GITHUB/hello-manifests
              ssh-key: ${{ secrets.SSH_PRIVATE_KEY }}

          - name: Update image tag in deployment
            run: |
              sed -i 's|image: .*|image: SEU_USUARIO_DOCKERHUB/hello-app:${{ github.sha }}|' deployment.yaml
              
          - name: Commit and push changes
            run: |
              git config --global user.name 'github-actions[bot]'
              git config --global user.email 'github-actions[bot]@users.noreply.github.com'
              git add deployment.yaml
              git commit -m "Update image to ${{ github.sha }}"
              git push
    ```

## Fase 5: Configuração do ArgoCD

Agora, vamos dizer ao ArgoCD para monitorar nosso repositório de manifestos e manter nosso cluster sincronizado.

1.  **Acesse a Interface do ArgoCD:**
    Use `kubectl port-forward` para acessar a interface web do ArgoCD, conforme a documentação de instalação.

2.  **Crie a Aplicação:**
    * Na interface do ArgoCD, clique em **NEW APP**.
    * **Application Name:** `hello-app`
    * **Project Name:** `default`
    * **Sync Policy:** `Automatic` (habilite `Prune Resources` e `Self Heal`).
    * **Repository URL:** A URL `.git` do seu repositório `hello-manifests`.
    * **Revision:** `HEAD`
    * **Path:** `.`
    * **Cluster URL:** `https://kubernetes.default.svc`
    * **Namespace:** `default`
    * Clique em `CREATE`. O ArgoCD irá clonar o repositório e implantar sua aplicação. O status deve mudar para **Healthy** e **Synced**.
    ![Sincronização ArgoCD](images/Screenshot%202025-09-26%20091514.png)

## Fase 6: Teste e Verificação

Finalmente, vamos verificar se tudo está funcionando de ponta a ponta.

1.  **Verifique os Pods:**
    No seu terminal, rode `kubectl get pods`. Você deve ver os pods da sua aplicação com o status `Running`.
    ![Resultado do comando kubectl get pods](images/Screenshot%202025-09-26%20091120.png)

2.  **Acesse a Aplicação:**
    Use o port-forward para expor o serviço localmente:
    ```bash
    kubectl port-forward svc/hello-app-service 8080:80
    ```
    Abra seu navegador e acesse `http://localhost:8080` ou faça uma requisição utilizando o curl. Você deve ver a mensagem: `{"message": "Hello World"}`, ou outra mensagem que você tenha colocado.  
    ![requisição curl para localhost:8080](images/Screenshot%202025-09-26%20091310.png)

3.  **Teste o Fluxo Completo:**
    * No repositório `hello-app`, edite o arquivo `main.py` e mude a mensagem para algo como `{"message": "Meu CI/CD funciona!"}`.
    * Faça o `commit` e o `push` da alteração para a branch `main`.

4.  **Resultados finais:**
    * **GitHub Actions:** Vá para a aba "Actions" do repositório `hello-app` e observe o workflow rodar.
    * **Docker Hub:** Verifique se uma nova imagem com a tag do hash do commit foi publicada. Para esse repositório, o link se encontra![aqui](https://hub.docker.com/repository/docker/kf0405/hello-app/general).
    * **Repositório de Manifestos:** Verifique o histórico de commits do `hello-manifests` para ver a atualização feita pelo bot.
    * **ArgoCD:** Na interface do ArgoCD, veja a aplicação ficar `OutOfSync` e depois sincronizar automaticamente para a nova versão.
    * **Aplicação:** Acesse `http://localhost:8080` novamente (talvez precise reiniciar o port-forward). A nova mensagem deve aparecer, confirmando o sucesso de todo o ciclo!
