# Agenda · Durão & Almeida, Pontes - Advogados Associados

Dois sites que usam o mesmo banco no Supabase (projeto `wrbqineebyybytthwjyt`).

| Pasta | Para quem | Acesso |
|---|---|---|
| `agenda-interna` | Equipe: ver e gerenciar a agenda | Com login |
| `site-cliente` | Clientes: solicitar reunião | Aberto |
| `banco` | Cria as tabelas e regras no Supabase | Uma vez |

A URL e a chave publishable do Supabase já estão preenchidas nos dois `index.html`.

## Passo a passo

### 1. Banco (Supabase)
1. Abra o projeto no Supabase > **SQL Editor** > **New query**.
2. Cole todo o conteúdo de `banco/banco-completo.sql` e clique em **Run**.
3. Em **Authentication > Users > Add user**, crie o e-mail e a senha de cada pessoa da equipe (marque "Auto Confirm User").
4. Em **Authentication > Sign In / Providers**, desligue **Allow new users to sign up**. Assim só quem você criou consegue entrar na agenda.

### 2. Publicar na Vercel (dois projetos)
1. Suba esta pasta inteira para um repositório no GitHub.
2. Na Vercel: **Add New > Project**, importe o repositório, e em **Root Directory** escolha `agenda-interna`. Framework Preset: **Other**. Deploy.
3. Repita: **Add New > Project**, o mesmo repositório, **Root Directory** `site-cliente`. Deploy.
4. Divulgue aos clientes apenas o endereço do `site-cliente`. O endereço da agenda interna fica só com a equipe.

### 3. Testar
1. Entre na agenda interna com um usuário criado e cadastre um advogado (botão **Advogados**).
2. Abra o site do cliente, escolha o advogado, um dia e um horário, e envie um pedido de teste.
3. Na agenda interna, clique em **Solicitações** e aceite. A reunião aparece na coluna do advogado.

## Se algo não funcionar
- **Erro de conexão ou de login com a chave nova:** em Supabase > Project Settings > API Keys, aba "Legacy", copie a chave `anon` (começa com `eyJ`) e troque `SUPABASE_ANON_KEY` nos dois `index.html`.
- **Site do cliente sem advogados:** cadastre ao menos um na agenda interna e confirme que o SQL rodou sem erro.
- **"E-mail ou senha incorretos":** confira se o usuário foi criado em Authentication > Users e está confirmado.

## Regras do site do cliente
- Reuniões de 30 minutos, dias úteis, das 09:00 às 18:00, pausa de 12:30 às 13:30, de amanhã até 14 dias úteis.
- Para mudar o expediente, altere o topo do script do `site-cliente/index.html` e a função `solicitar_reuniao` no SQL (os dois precisam ser iguais).
- O pedido bloqueia o horário até a equipe aceitar ou recusar. Não há e-mail automático: a confirmação ao cliente é feita pela equipe.

## Segurança
- A chave `sb_publishable_...` pode ficar no site. Nunca coloque a chave `secret` ou `service_role` em nenhum arquivo.
- Todo usuário logado vê todos os dados. Os dados dos clientes são pessoais (LGPD): crie logins só para quem precisa e use senhas fortes.
