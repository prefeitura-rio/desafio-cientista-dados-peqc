{{ config(materialized='view') }}

/*
    Staging dos registros de frequência por disciplina e período de apuração.
    Grão alvo: 1 linha por aluno x turma x escola x disciplina x período.

    Limpezas aplicadas:
      - datas chegam como STRING 'YYYY-MM-DD' -> DATE (SAFE.PARSE_DATE: strings
        inválidas viram null e são eliminadas pelo filtro de qualidade)
      - disciplina: código genérico -> nome legível (macro map_disciplina),
        mantendo o código original para rastreabilidade
      - frequencia -> percentual_frequencia; linhas fora de [0, 100] são descartadas
      - DEDUPLICAÇÃO: a fonte contém 1.483 linhas 100% idênticas (reprocessamento).
        Removemos apenas duplicatas exatas via `select distinct`. Duplicatas com
        o MESMO grão mas valores diferentes (~1.100 pares, 2.186 linhas) são preservadas aqui
        e resolvidas na camada intermediate (média), para não esconder o problema
        de qualidade na origem. O teste de unicidade do grão fica em warn.
*/

with source as (

    select * from {{ source('rmi_raw', 'frequencia') }}

),

renamed as (

    select distinct
        {{ aluno_id_to_string('id_aluno') }}                  as id_aluno,
        cast(id_turma as int64)                               as id_turma,
        cast(id_escola as int64)                              as id_escola,
        safe.parse_date('%Y-%m-%d', trim(data_inicio))        as data_inicio_periodo,
        safe.parse_date('%Y-%m-%d', trim(data_fim))           as data_fim_periodo,
        trim(disciplina)                                      as codigo_disciplina,
        {{ map_disciplina('trim(disciplina)') }}              as nome_disciplina,
        cast(frequencia as float64)                           as percentual_frequencia

    from source

),

filtered as (

    select
        *,
        extract(month from data_inicio_periodo)               as mes_periodo
    from renamed
    where id_aluno is not null
      and id_escola is not null
      and data_inicio_periodo is not null
      and data_fim_periodo is not null
      and percentual_frequencia between 0 and 100

)

select * from filtered
