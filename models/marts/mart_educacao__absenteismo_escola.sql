{{
    config(
        materialized='table',
        cluster_by=['id_bairro_hash', 'id_escola'],
        tags=['absenteismo']
    )
}}

/*
    Absenteísmo crônico por escola (e região anonimizada).
    Grão: 1 linha por escola do cadastro.

    Pergunta de negócio: "Quais escolas/regiões têm maior taxa de alunos com
    frequência abaixo de 75%?" (LDB, art. 24, inciso VI).

    Definições:
      - Aluno pertence à escola pela escola principal inferida da frequência
        (int_educacao__aluno_escola).
      - Frequência anual do aluno = média das frequências bimestrais disponíveis
        (stg_educacao__avaliacao.percentual_frequencia_bimestre). É a medida com
        variância real; a tabela de frequência por disciplina (97-100%) é mantida
        como indicador complementar (percentual_frequencia_disciplinas_medio).
      - Absenteísmo crônico = frequência anual < var('limiar_frequencia_minima').
      - taxa_absenteismo_cronico é calculada sobre alunos COM frequência bimestral
        (denominador explícito em qtd_alunos_com_frequencia_bimestral), nunca sobre
        o total de matriculados, para não subestimar escolas com baixa cobertura.
*/

with escolas as (

    select * from {{ ref('stg_educacao__escola') }}

),

aluno_escola as (

    select * from {{ ref('int_educacao__aluno_escola') }}

),

desempenho as (

    select * from {{ ref('int_educacao__aluno_desempenho_bimestre') }}

),

frequencia_periodo as (

    select * from {{ ref('int_educacao__aluno_frequencia_periodo') }}

),

-- 1 linha por aluno: frequência anual e desempenho consolidados
aluno_ano as (

    select
        id_aluno,
        avg(percentual_frequencia_bimestre)                     as percentual_frequencia_anual,
        countif(percentual_frequencia_bimestre is not null)    as qtd_bimestres_com_frequencia,
        countif(flag_frequencia_abaixo_limiar)                  as qtd_bimestres_abaixo_limiar,
        avg(media_notas)                                        as media_notas_anual
    from desempenho
    group by 1

),

aluno_consolidado as (

    select
        ae.id_aluno,
        ae.id_escola_principal                                   as id_escola,
        ae.flag_transferencia,
        aa.percentual_frequencia_anual,
        aa.qtd_bimestres_com_frequencia,
        aa.qtd_bimestres_abaixo_limiar,
        aa.media_notas_anual,
        case
            when aa.percentual_frequencia_anual is null then null
            else aa.percentual_frequencia_anual < {{ var('limiar_frequencia_minima') }}
        end                                                      as flag_absenteismo_cronico
    from aluno_escola as ae
    left join aluno_ano as aa
        on ae.id_aluno = aa.id_aluno

),

por_escola as (

    select
        id_escola,
        count(distinct id_aluno)                                 as qtd_alunos,
        countif(flag_transferencia)                              as qtd_alunos_transferidos,
        countif(percentual_frequencia_anual is not null)         as qtd_alunos_com_frequencia_bimestral,
        countif(flag_absenteismo_cronico)                        as qtd_alunos_absenteismo_cronico,
        countif(qtd_bimestres_abaixo_limiar > 0)                 as qtd_alunos_algum_bimestre_abaixo_limiar,
        avg(percentual_frequencia_anual)                         as percentual_frequencia_anual_medio,
        avg(media_notas_anual)                                   as media_notas_escola
    from aluno_consolidado
    group by 1

),

por_escola_disciplinas as (

    select
        id_escola,
        avg(percentual_frequencia_medio)                         as percentual_frequencia_disciplinas_medio,
        count(distinct data_inicio_periodo)                      as qtd_periodos_apurados
    from frequencia_periodo
    group by 1

),

final as (

    select
        e.id_escola,
        e.id_bairro_hash,
        coalesce(pe.qtd_alunos, 0)                               as qtd_alunos,
        coalesce(pe.qtd_alunos_transferidos, 0)                  as qtd_alunos_transferidos,
        coalesce(pe.qtd_alunos_com_frequencia_bimestral, 0)      as qtd_alunos_com_frequencia_bimestral,
        coalesce(pe.qtd_alunos_absenteismo_cronico, 0)           as qtd_alunos_absenteismo_cronico,
        coalesce(pe.qtd_alunos_algum_bimestre_abaixo_limiar, 0)  as qtd_alunos_algum_bimestre_abaixo_limiar,
        safe_divide(
            pe.qtd_alunos_absenteismo_cronico,
            pe.qtd_alunos_com_frequencia_bimestral
        ) * 100                                                  as taxa_absenteismo_cronico,
        safe_divide(
            pe.qtd_alunos_com_frequencia_bimestral,
            pe.qtd_alunos
        ) * 100                                                  as cobertura_frequencia_bimestral,
        pe.percentual_frequencia_anual_medio,
        pd.percentual_frequencia_disciplinas_medio,
        pd.qtd_periodos_apurados,
        pe.media_notas_escola,
        (pe.id_escola is null)                                   as flag_escola_sem_alunos
    from escolas as e
    left join por_escola as pe
        on e.id_escola = pe.id_escola
    left join por_escola_disciplinas as pd
        on e.id_escola = pd.id_escola

)

select
    *,
    -- ranking só entre escolas com base mínima de 30 alunos avaliados, para evitar
    -- que escolas com 1-2 alunos dominem o topo da lista
    case
        when qtd_alunos_com_frequencia_bimestral >= 30
        then rank() over (
            partition by (qtd_alunos_com_frequencia_bimestral >= 30)
            order by taxa_absenteismo_cronico desc
        )
    end                                                          as ranking_absenteismo_rede,
    case
        when qtd_alunos_com_frequencia_bimestral >= 30
        then rank() over (
            partition by id_bairro_hash, (qtd_alunos_com_frequencia_bimestral >= 30)
            order by taxa_absenteismo_cronico desc
        )
    end                                                          as ranking_absenteismo_regiao
from final
