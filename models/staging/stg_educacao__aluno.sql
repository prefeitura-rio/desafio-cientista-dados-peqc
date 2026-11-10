{{ config(materialized='view') }}

/*
    Staging do cadastro de alunos.
    Grão: 1 linha por aluno (id_aluno).

    Limpezas aplicadas:
      - id_aluno: BYTES -> STRING hex minúscula (chave padronizada em todo o projeto)
      - faixa_etaria: trim + normalização; valores fora do domínio viram null
        (o teste accepted_values pega regressões)
      - bairro: chega como FLOAT64 (por causa dos 68 nulos no Parquet) -> INT64
      - filtro de qualidade: descarta linhas sem id_aluno (chave obrigatória)
*/

with source as (

    select * from {{ source('rmi_raw', 'aluno') }}

),

renamed as (

    select
        {{ aluno_id_to_string('id_aluno') }}            as id_aluno,
        cast(id_turma as int64)                         as id_turma,
        case trim(faixa_etaria)
            when '0-5'   then '0-5'
            when '6-10'  then '6-10'
            when '11-14' then '11-14'
            when '15-17' then '15-17'
            when '18+'   then '18+'
            else null
        end                                             as faixa_etaria,
        cast(bairro as int64)                           as id_bairro_hash,
        (bairro is null)                                as flag_bairro_nao_informado

    from source
    where id_aluno is not null

)

select * from renamed
