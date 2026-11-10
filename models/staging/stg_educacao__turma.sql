{{ config(materialized='view') }}

/*
    Staging da tabela "turma".
    Apesar do nome, a tabela fonte tem grão aluno x turma (1 linha por aluno,
    97.044 linhas = cadastro de alunos): funciona como a MATRÍCULA do ano letivo.
    O nome é mantido para rastreabilidade com a fonte; a semântica é documentada
    no schema.yml.

    Limpezas aplicadas:
      - ano -> ano_letivo (INT64). Toda a base foi anonimizada para 2000.
      - id_aluno padronizado como STRING hex.
      - filtro: descarta linhas sem aluno ou sem turma (não representam matrícula).
*/

with source as (

    select * from {{ source('rmi_raw', 'turma') }}

),

renamed as (

    select
        {{ aluno_id_to_string('id_aluno') }}   as id_aluno,
        cast(id_turma as int64)                as id_turma,
        cast(ano as int64)                     as ano_letivo

    from source
    where id_aluno is not null
      and id_turma is not null

)

select * from renamed
