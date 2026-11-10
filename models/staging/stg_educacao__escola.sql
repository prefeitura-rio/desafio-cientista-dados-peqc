{{ config(materialized='view') }}

/*
    Staging do cadastro de unidades escolares.
    Grão: 1 linha por escola (id_escola).

    Observação importante (ver notebooks/eda.ipynb): o hash de bairro da escola
    NÃO coincide com o hash de bairro do aluno (salts diferentes) nem com a
    tabela pública datario.dados_mestres.bairro. Por isso id_bairro_hash é
    mantido apenas como chave de agrupamento ("região anonimizada").
*/

with source as (

    select * from {{ source('rmi_raw', 'escola') }}

),

renamed as (

    select
        cast(id_escola as int64)   as id_escola,
        cast(bairro as int64)      as id_bairro_hash

    from source
    where id_escola is not null

)

select * from renamed
