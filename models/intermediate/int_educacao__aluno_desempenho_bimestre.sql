{{ config(materialized='view') }}

/*
    Desempenho e frequência do aluno por bimestre, enriquecido com cadastro,
    matrícula e escola principal.
    Grão: 1 linha por aluno x turma x bimestre (herdado de stg_educacao__avaliacao).

    Joins e premissas:
      - avaliacao  INNER JOIN aluno      : toda avaliação pertence a um aluno
                                           cadastrado (teste relationships).
      - avaliacao  LEFT  JOIN turma      : 0,08% das avaliações apontam para turma
                                           fora do cadastro; não descartamos a nota,
                                           apenas marcamos flag_turma_nao_cadastrada.
      - avaliacao  LEFT  JOIN aluno_escola: alunos sem frequência (e portanto sem
                                           escola inferida) ficam com id_escola nulo
                                           e são contabilizados à parte nos marts.

    Métricas:
      - media_notas: média das notas existentes (Inglês é 100% nulo e é ignorado
        automaticamente pelo AVG; se um dia vier preenchido, entra na conta).
      - flag_frequencia_abaixo_limiar usa var('limiar_frequencia_minima') (75%).
      - flag_notas_zeradas: todas as notas existentes <= 0,5. A EDA mostrou um pico
        artificial em ~0 (ausência de nota codificada como 0 + jitter); marcamos
        em vez de excluir para que o mart decida.
*/

with avaliacao as (

    select * from {{ ref('stg_educacao__avaliacao') }}

),

alunos as (

    select id_aluno, faixa_etaria, id_bairro_hash from {{ ref('stg_educacao__aluno') }}

),

turmas as (

    select distinct id_turma, ano_letivo from {{ ref('stg_educacao__turma') }}

),

aluno_escola as (

    select * from {{ ref('int_educacao__aluno_escola') }}

),

joined as (

    select
        av.id_aluno,
        av.id_turma,
        av.bimestre,
        t.ano_letivo,
        al.faixa_etaria,
        al.id_bairro_hash                                   as id_bairro_hash_aluno,
        ae.id_escola_principal                              as id_escola,
        ae.flag_transferencia,
        av.percentual_frequencia_bimestre,
        av.nota_lingua_portuguesa,
        av.nota_ciencias,
        av.nota_ingles,
        av.nota_matematica,
        av.qtd_notas_preenchidas,
        av.qtd_registros_fonte,
        (t.id_turma is null)                                as flag_turma_nao_cadastrada,
        (ae.id_aluno is null)                               as flag_sem_escola_inferida

    from avaliacao as av
    inner join alunos as al
        on av.id_aluno = al.id_aluno
    left join turmas as t
        on av.id_turma = t.id_turma
    left join aluno_escola as ae
        on av.id_aluno = ae.id_aluno

),

metricas as (

    select
        *,
        (
            coalesce(nota_lingua_portuguesa, 0) + coalesce(nota_ciencias, 0)
            + coalesce(nota_ingles, 0) + coalesce(nota_matematica, 0)
        ) / nullif(qtd_notas_preenchidas, 0)                as media_notas,
        case
            when percentual_frequencia_bimestre is null then null
            else percentual_frequencia_bimestre < {{ var('limiar_frequencia_minima') }}
        end                                                 as flag_frequencia_abaixo_limiar,
        case
            when qtd_notas_preenchidas = 0 then null
            else coalesce(nota_lingua_portuguesa, 0) <= 0.5
             and coalesce(nota_ciencias, 0) <= 0.5
             and coalesce(nota_ingles, 0) <= 0.5
             and coalesce(nota_matematica, 0) <= 0.5
        end                                                 as flag_notas_zeradas
    from joined

)

select * from metricas
