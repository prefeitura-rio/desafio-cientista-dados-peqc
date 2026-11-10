/*
    REGRA DE NEGÓCIO: todo aluno com nota ou frequência bimestral registrada
    (tabela de avaliação) precisa ter ao menos um período de frequência apurado
    no ano letivo.

    Por que importa: não existe avaliação sem o aluno ter frequentado a escola.
    Avaliações "órfãs" de frequência indicam aluno avaliado em outra rede/ano,
    falha na carga da frequência ou quebra do mapeamento de IDs. Como o mart de
    absenteísmo infere a escola do aluno a partir da frequência, esses alunos
    sumiriam silenciosamente das contagens por escola.

    O teste falha se retornar qualquer linha.
*/

with avaliados as (

    select distinct id_aluno from {{ ref('stg_educacao__avaliacao') }}

),

com_frequencia as (

    select distinct id_aluno from {{ ref('stg_educacao__frequencia') }}

)

select
    a.id_aluno
from avaliados as a
left join com_frequencia as f
    on a.id_aluno = f.id_aluno
where f.id_aluno is null
