-- BANCO COMPLETO: rode UMA vez no Supabase (SQL Editor > New query > cole tudo > Run)

-- Rode no Supabase: SQL Editor > New query > Run

create table advogados (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  area text not null default '',
  oab text not null default '',
  created_at timestamptz not null default now()
);

create table clientes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  tel text not null default '',
  mail text not null default '',
  created_at timestamptz not null default now()
);

create table reunioes (
  id uuid primary key default gen_random_uuid(),
  data date not null,
  ini time not null,
  dur int not null default 30 check (dur > 0),
  cliente_id uuid references clientes(id) on delete set null,
  assunto text not null,
  tipo text not null default 'cliente' check (tipo in ('interno','cliente','audiencia','prazo')),
  local text not null default '',
  pauta text not null default '',
  feito boolean not null default false,
  adv uuid[] not null default '{}',
  created_at timestamptz not null default now()
);
create index reunioes_data_idx on reunioes (data);

-- Segurança: só usuários logados acessam os dados
alter table advogados enable row level security;
alter table clientes  enable row level security;
alter table reunioes  enable row level security;

create policy "equipe logada" on advogados for all to authenticated using (true) with check (true);
create policy "equipe logada" on clientes  for all to authenticated using (true) with check (true);
create policy "equipe logada" on reunioes  for all to authenticated using (true) with check (true);

-- Atualização em tempo real entre usuários
alter publication supabase_realtime add table advogados, clientes, reunioes;


-- Rode no MESMO projeto Supabase da agenda interna (SQL Editor > Run).
-- O site do cliente não acessa tabelas: só chama as 3 funções abaixo.

create table solicitacoes (
  id uuid primary key default gen_random_uuid(),
  advogado_id uuid not null references advogados(id) on delete cascade,
  data date not null,
  ini time not null,
  dur int not null default 30,
  nome text not null,
  tel text not null,
  mail text not null,
  assunto text not null,
  status text not null default 'pendente' check (status in ('pendente','aceita','recusada')),
  created_at timestamptz not null default now()
);
-- impede dois pedidos pendentes para o mesmo advogado/dia/horário
create unique index solicitacoes_slot_uq on solicitacoes (advogado_id, data, ini) where status = 'pendente';

alter table solicitacoes enable row level security;
create policy "equipe logada" on solicitacoes for all to authenticated using (true) with check (true);
alter publication supabase_realtime add table solicitacoes;

-- 1) lista de advogados (só nome e área)
create function listar_advogados()
returns table (id uuid, nome text, area text)
language sql stable security definer set search_path = public as $$
  select id, nome, area from advogados order by nome
$$;

-- 2) horários ocupados de um advogado em um dia (sem dados de clientes)
create function horarios_ocupados(p_advogado uuid, p_data date)
returns table (ini time, dur int)
language sql stable security definer set search_path = public as $$
  select r.ini, r.dur from reunioes r where r.data = p_data and p_advogado = any (r.adv)
  union all
  select s.ini, s.dur from solicitacoes s where s.data = p_data and s.advogado_id = p_advogado and s.status = 'pendente'
$$;

-- 3) cria a solicitação, validando tudo no servidor
create function solicitar_reuniao(p_advogado uuid, p_data date, p_ini time, p_nome text, p_tel text, p_mail text, p_assunto text)
returns void
language plpgsql security definer set search_path = public as $$
declare hoje date := (now() at time zone 'America/Sao_Paulo')::date;
begin
  if length(trim(coalesce(p_nome,''))) < 2 or length(p_nome) > 120
     or length(trim(coalesce(p_tel,''))) < 8 or length(p_tel) > 30
     or p_mail !~ '^[^@\s]+@[^@\s]+\.[^@\s]+$' or length(p_mail) > 160
     or length(trim(coalesce(p_assunto,''))) < 3 or length(p_assunto) > 600 then
    raise exception 'Dados inválidos';
  end if;
  if p_data <= hoje or p_data > hoje + 60 or extract(isodow from p_data) > 5 then
    raise exception 'Data indisponível';
  end if;
  -- expediente: 09:00 a 18:00, pausa 12:30-13:30, intervalos de 30 min (ajuste aqui se mudar no site)
  if p_ini < time '09:00' or p_ini > time '17:30' or (p_ini >= time '12:30' and p_ini < time '13:30')
     or extract(minute from p_ini) not in (0, 30) then
    raise exception 'Horário indisponível';
  end if;
  if not exists (select 1 from advogados where id = p_advogado) then
    raise exception 'Advogado inválido';
  end if;
  if exists (select 1 from horarios_ocupados(p_advogado, p_data) o
             where o.ini < p_ini + interval '30 minutes' and o.ini + make_interval(mins => o.dur) > p_ini) then
    raise exception 'Horário já ocupado';
  end if;
  insert into solicitacoes (advogado_id, data, ini, dur, nome, tel, mail, assunto)
  values (p_advogado, p_data, p_ini, 30, trim(p_nome), trim(p_tel), trim(p_mail), trim(p_assunto));
end $$;

revoke all on function listar_advogados() from public;
revoke all on function horarios_ocupados(uuid, date) from public;
revoke all on function solicitar_reuniao(uuid, date, time, text, text, text, text) from public;
grant execute on function listar_advogados() to anon, authenticated;
grant execute on function horarios_ocupados(uuid, date) to anon, authenticated;
grant execute on function solicitar_reuniao(uuid, date, time, text, text, text, text) to anon, authenticated;
