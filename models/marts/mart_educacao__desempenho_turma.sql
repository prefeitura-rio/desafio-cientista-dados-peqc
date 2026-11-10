{{
    config(
        materialized='table',
        cluster_by=['faixa_tamanho_turma'],
        tags=['desempenho']
    )
}}

/*
    Desempenho por perfil de turma.
    Grão: 1 linha por turma do cadastro de matrícula (stg_educacao__turma).

    Pergunta de negócio: "Como a composição das turmas (tamanho, faixa etária)
    se correlaciona com desempenho e frequência?"

    Definições:
      - tamanho_turma: alunos matriculados na turma (cadastro). A fonte anonimizada
        não traz série nem turno; usamos faixa etária predominante como proxy de série.
      - As métricas de avaliação são agregadas pela turma informada NA AVALIAÇÃO
        (90,8% coincide com a turma de matrícula). Turmas que só existem na avaliação
        (0,08%) ficam fora deste mart e são monitoradas pelo teste de relationships.
      - Médias por disciplina ignoram nulos; alunos com todas as notas ~0
        (flag_notas_zeradas) entram na média por padrão, mas a quantidade é exposta
        para que o analista possa ajustar.
*/

with matriculas as (

    select * from {{ ref('stg_educacao__turma') }}

),

alunos as (

    select * from {{ ref('stg_educacao__aluno') }}

),

desempenho as (

    select * from {{ ref('int_educacao__aluno_desempenho_bimestre') }}

),

composicao as (

    select
        m.id_turma,
        m.ano_letivo,
        count(distinct m.id_aluno)                                        as tamanho_turma,
        count(distinct a.faixa_etaria)                                    as qtd_faixas_etarias,
        approx_top_count(a.faixa_etaria, 1)[offset(0)].value              as faixa_etaria_predominante
    from matriculas as m
    inner join alunos as a
        on m.id_aluno = a.id_aluno
    group by 1, 2

),

-- escola predominante da turma, inferida pelos alunos avaliados nela
escola_turma as (

    select
        id_turma,
        approx_top_count(id_escola, 1)[offset(0)].value                   as id_escola
    from desempenho
    where id_escola is not null
    group by 1

),

avaliacao_turma as (

    select
        id_turma,
        count(distinct id_aluno)                                          as qtd_alunos_avaliados,
        count(distinct bimestre)                                          as qtd_bimestres_avaliados,
        count(*)                                                          as qtd_registros_avaliacao,
        avg(nota_lingua_portuguesa)                                       as media_lingua_portuguesa,
        avg(nota_ciencias)                                                as media_ciencias,
        avg(nota_matematica)                                              as media_matematica,
        avg(media_notas)                                                  as media_geral,
        avg(percentual_frequencia_bimestre)                               as percentual_frequencia_medio,
        countif(flag_notas_zeradas)                                       as qtd_registros_notas_zeradas,
        safe_divide(
            countif(media_notas < {{ var('nota_minima_aprovacao') }}),
            countif(media_notas is not null)
        ) * 100                                                           as taxa_registros_abaixo_media_minima,
        safe_divide(
            countif(flag_frequencia_abaixo_limiar),
            countif(flag_frequencia_abaixo_limiar is not null)
        ) * 100                                                           as taxa_registros_frequencia_abaixo_limiar
    from desempenho
    group by 1

)

select
    c.id_turma,
    c.ano_letivo,
    et.id_escola,
    c.tamanho_turma,
    case
        when c.tamanho_turma <= 5  then '01-05'
        when c.tamanho_turma <= 15 then '06-15'
        when c.tamanho_turma <= 30 then '16-30'
        else '31+'
    end                                                                   as faixa_tamanho_turma,
    c.faixa_etaria_predominante,
    c.qtd_faixas_etarias,
    (c.qtd_faixas_etarias > 1)                                            as flag_turma_multisseriada,
    coalesce(av.qtd_alunos_avaliados, 0)                                  as qtd_alunos_avaliados,
    safe_divide(av.qtd_alunos_avaliados, c.tamanho_turma) * 100           as cobertura_avaliacao,
    av.qtd_bimestres_avaliados,
    av.qtd_registros_avaliacao,
    av.media_lingua_portuguesa,
    av.media_ciencias,
    av.media_matematica,
    av.media_geral,
    av.percentual_frequencia_medio,
    av.qtd_registros_notas_zeradas,
    av.taxa_registros_abaixo_media_minima,
    av.taxa_registros_frequencia_abaixo_limiar,
    (av.id_turma is null)                                                 as flag_turma_sem_avaliacao
from composicao as c
left join avaliacao_turma as av
    on c.id_turma = av.id_turma
left join escola_turma as et
    on c.id_turma = et.id_turma
