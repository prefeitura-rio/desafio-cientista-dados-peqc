{{ config(materialized='view') }}

/*
    Escola principal de cada aluno no ano letivo.
    Grão: 1 linha por aluno.

    Por que este model existe:
      - A tabela de avaliação NÃO tem id_escola. Para responder "absenteísmo por
        escola/região" precisamos ligar o aluno a uma escola.
      - A única fonte com id_escola é a frequência. 3,6% dos alunos aparecem em
        mais de uma escola (transferência). Escolhemos a escola com MAIS períodos
        de frequência registrados; empate resolvido pela escola mais recente
        (maior data_inicio) e, por fim, pelo menor id_escola (determinismo).

    Premissas:
      - Join implícito: aluno existe em stg_educacao__frequencia (100% dos alunos
        do cadastro têm frequência na carga de referência). Alunos sem frequência
        ficam fora deste model e, por consequência, fora dos marts por escola
        (o mart documenta essa cobertura).
*/

with frequencia as (

    select
        id_aluno,
        id_escola,
        id_turma,
        data_inicio_periodo
    from {{ ref('stg_educacao__frequencia') }}

),

por_aluno_escola as (

    select
        id_aluno,
        id_escola,
        count(distinct data_inicio_periodo)   as qtd_periodos_na_escola,
        max(data_inicio_periodo)              as ultimo_periodo_na_escola,
        count(distinct id_turma)              as qtd_turmas_na_escola
    from frequencia
    group by 1, 2

),

ranked as (

    select
        *,
        count(*) over (partition by id_aluno)   as qtd_escolas_no_ano,
        row_number() over (
            partition by id_aluno
            order by qtd_periodos_na_escola desc, ultimo_periodo_na_escola desc, id_escola
        )                                       as ordem
    from por_aluno_escola

)

select
    id_aluno,
    id_escola                      as id_escola_principal,
    qtd_periodos_na_escola,
    qtd_turmas_na_escola,
    qtd_escolas_no_ano,
    (qtd_escolas_no_ano > 1)       as flag_transferencia
from ranked
where ordem = 1
