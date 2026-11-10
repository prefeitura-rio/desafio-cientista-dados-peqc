/*
    TESTE DE RECONCILIAÇÃO: o total de alunos com absenteísmo crônico somado
    em todas as escolas do mart deve ser igual ao total recalculado diretamente
    a partir da camada intermediate.

    Por que importa: é a garantia de que nenhuma agregação, join ou filtro do
    mart "perde" ou "duplica" alunos. Este número vai para gestores e para a
    imprensa; uma divergência aqui é um incidente de confiança no dado.

    O teste falha se os dois totais forem diferentes (retorna 1 linha).
*/

with no_mart as (

    select sum(qtd_alunos_absenteismo_cronico) as total
    from {{ ref('mart_educacao__absenteismo_escola') }}

),

recalculado as (

    select count(*) as total
    from (
        select
            d.id_aluno
        from {{ ref('int_educacao__aluno_desempenho_bimestre') }} as d
        inner join {{ ref('int_educacao__aluno_escola') }} as ae
            on d.id_aluno = ae.id_aluno
        group by d.id_aluno
        having avg(d.percentual_frequencia_bimestre) < {{ var('limiar_frequencia_minima') }}
    )

)

select
    m.total as total_no_mart,
    r.total as total_recalculado
from no_mart as m
cross join recalculado as r
where m.total != r.total
