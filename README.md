# Nuvem PIX — Instalador (VPS)

Instalação self-hosted do **Nuvem PIX** por imagens Docker prontas. **Não contém o código-fonte** —
apenas os arquivos de instalação. As imagens são baixadas do registro privado com o **token de
acesso** que você recebeu.

```
Internet ──▶ Caddy (HTTPS :443) ──┬─ site/painel
                                  └─ /api ─▶ backend
Placas ────▶ backend HTTP :8080  +  EMQX MQTT :1883
backend ──▶ Postgres · Redis · EMQX (rede interna)
```

## Pré-requisitos
- VPS **Ubuntu 22.04 / 24.04** limpa, acesso root (sudo).
- Um **domínio** apontando (registro A) para o **IP da VPS** (necessário para o HTTPS).
- O **token de acesso** (usuário + token) fornecido pela Nuvem PIX.
- Portas liberadas: **80, 443, 1883, 8080** e **22** (SSH).

## Instalação
```bash
git clone https://github.com/fredericozapponi/nuvem-pix-installer.git
cd nuvem-pix-installer
sudo bash install.sh
```
O instalador:
1. instala o Docker (se faltar);
2. faz `docker login` no registro com o seu **token**;
3. pergunta **domínio, admin, gateway Pix**, gera os **segredos** e escreve o `.env`;
4. **baixa as imagens** e sobe tudo (HTTPS automático no domínio).

Acesse **https://seu-dominio** e entre com o admin que você definiu.

## Operação
```bash
docker compose logs -f          # logs
docker compose ps               # status
sudo bash update.sh             # atualizar para a última versão
docker compose down             # parar
docker compose up -d            # iniciar
```

## Versão
Por padrão usa a tag `latest`. Para fixar uma versão, defina no `.env`:
```
NUVEMPIX_VERSION=v1.0.0
```

## Backup
- Volume do **Postgres** + pasta **`./data`** (firmware/imagens) + o **`.env`**.
