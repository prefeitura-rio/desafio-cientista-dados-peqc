/*
    REGRA DE NEGÓCIO: nenhum registro de frequência pode estar fora do ano
    letivo da matrícula do aluno.

    Por que importa: a frequência é apurada por ano letivo para fins de aprovação
    (LDB, art. 24). Um registro datado em outro ano indica erro de carga, de
    anonimização de datas ou de vínculo aluno/matrícula, e contaminaria o cálculo
    de absenteísmo anual.

    O teste falha se retornar qualquer linha.
*/

with frequencia as (

    select
        id_aluno,
        data_inicio_periodo,
        data_fim_periodo
    from {{ ref('stg_educacao__frequencia') }}

),

matricula as (

    select id_aluno, ano_letivo from {{ ref('stg_educacao__turma') }}

)

select
    f.id_aluno,
    f.data_inicio_periodo,
    f.data_fim_periodo,
    m.ano_letivo
from frequencia as f
inner join matricula as m
    on f.id_aluno = m.id_aluno
where extract(year from f.data_inicio_periodo) != m.ano_letivo
   or extract(year from f.data_fim_periodo) != m.ano_letivo
