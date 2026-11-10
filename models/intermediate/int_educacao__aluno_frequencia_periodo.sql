{{ config(materialized='view') }}

/*
    Frequência consolidada por aluno e período de apuração (todas as disciplinas).
    Grão: 1 linha por aluno x escola x período (data_inicio_periodo).

    Decisões de modelagem:
      - A fonte traz 4 disciplinas por aluno/período sempre; consolidamos em uma
        média simples (percentual_frequencia_medio) e guardamos o mínimo
        (pior disciplina) para análises de risco.
      - Duplicatas de mesmo grão com valores divergentes (que o staging preserva
        de propósito) são absorvidas pelo AVG; expomos qtd_registros para auditoria.
      - id_turma NÃO entra no grão: ~12% das linhas de frequência apontam para
        turmas fora do cadastro e a turma da frequência quase nunca coincide com
        a turma de matrícula do aluno (0,01%). Mantemos a turma mais frequente
        apenas como atributo informativo (turma_predominante).
      - Join com o cadastro de alunos: INNER (toda frequência tem aluno; o teste
        de relationships garante). Faixa etária vem para cá para evitar re-join
        nos marts.
*/

with frequencia as (

    select * from {{ ref('stg_educacao__frequencia') }}

),

alunos as (

    select id_aluno, faixa_etaria from {{ ref('stg_educacao__aluno') }}

),

agregado as (

    select
        f.id_aluno,
        f.id_escola,
        f.data_inicio_periodo,
        min(f.data_fim_periodo)                           as data_fim_periodo,
        min(f.mes_periodo)                                as mes_periodo,
        avg(f.percentual_frequencia)                      as percentual_frequencia_medio,
        min(f.percentual_frequencia)                      as percentual_frequencia_minimo,
        count(distinct f.codigo_disciplina)               as qtd_disciplinas,
        count(*)                                          as qtd_registros,
        approx_top_count(f.id_turma, 1)[offset(0)].value  as turma_predominante
    from frequencia as f
    group by 1, 2, 3

)

select
    a.id_aluno,
    a.id_escola,
    a.data_inicio_periodo,
    a.data_fim_periodo,
    a.mes_periodo,
    al.faixa_etaria,
    a.turma_predominante,
    a.percentual_frequencia_medio,
    a.percentual_frequencia_minimo,
    a.qtd_disciplinas,
    a.qtd_registros,
    (a.percentual_frequencia_medio < {{ var('limiar_frequencia_minima') }})
                                                          as flag_abaixo_limiar
from agregado as a
inner join alunos as al
    on a.id_aluno = al.id_aluno
