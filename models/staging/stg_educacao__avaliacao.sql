{{ config(materialized='view') }}

/*
    Staging das notas e frequência bimestral.
    Grão alvo: 1 linha por aluno x turma x bimestre.

    Limpezas aplicadas:
      - bimestre chega como STRING ('1'..'4') -> INT64; fora do domínio é descartado
      - colunas disciplina_N (notas) renomeadas para nota_<disciplina>;
        disciplina_3 (Inglês) é 100% nula na fonte e foi mantida por contrato
        (se um dia vier preenchida, nada quebra)
      - notas fora de [0, 10] viram null (o jitter de anonimização pode gerar
        valores marginalmente fora do intervalo em outras extrações)
      - frequencia -> percentual_frequencia_bimestre (0..100)
      - DEDUPLICAÇÃO: 34 pares (aluno, turma, bimestre) aparecem repetidos na
        fonte. Mantemos a linha mais completa (mais notas preenchidas; empate
        resolvido pela maior frequência) via row_number, e expomos a quantidade
        de registros na fonte na coluna qtd_registros_fonte para auditoria.
*/

with source as (

    select * from {{ source('rmi_raw', 'avaliacao') }}

),

renamed as (

    select
        {{ aluno_id_to_string('id_aluno') }}                   as id_aluno,
        cast(id_turma as int64)                                as id_turma,
        safe_cast(trim(cast(bimestre as string)) as int64)     as bimestre,
        cast(frequencia as float64)                            as percentual_frequencia_bimestre,
        cast(disciplina_1 as float64)                          as nota_lingua_portuguesa,
        cast(disciplina_2 as float64)                          as nota_ciencias,
        cast(disciplina_3 as float64)                          as nota_ingles,
        cast(disciplina_4 as float64)                          as nota_matematica

    from source
    where id_aluno is not null

),

cleaned as (

    select
        id_aluno,
        id_turma,
        bimestre,
        if(percentual_frequencia_bimestre between 0 and 100, percentual_frequencia_bimestre, null)
                                                               as percentual_frequencia_bimestre,
        if(nota_lingua_portuguesa between 0 and 10, nota_lingua_portuguesa, null) as nota_lingua_portuguesa,
        if(nota_ciencias           between 0 and 10, nota_ciencias,           null) as nota_ciencias,
        if(nota_ingles             between 0 and 10, nota_ingles,             null) as nota_ingles,
        if(nota_matematica         between 0 and 10, nota_matematica,         null) as nota_matematica

    from renamed
    where bimestre between 1 and 4

),

deduplicated as (

    select
        id_aluno,
        id_turma,
        bimestre,
        percentual_frequencia_bimestre,
        nota_lingua_portuguesa,
        nota_ciencias,
        nota_ingles,
        nota_matematica,
        cast(nota_lingua_portuguesa is not null as int64)
          + cast(nota_ciencias is not null as int64)
          + cast(nota_ingles is not null as int64)
          + cast(nota_matematica is not null as int64)                 as qtd_notas_preenchidas,
        count(*) over (partition by id_aluno, id_turma, bimestre)      as qtd_registros_fonte
    from cleaned
    qualify row_number() over (
        partition by id_aluno, id_turma, bimestre
        order by
            cast(nota_lingua_portuguesa is not null as int64)
              + cast(nota_ciencias is not null as int64)
              + cast(nota_ingles is not null as int64)
              + cast(nota_matematica is not null as int64) desc,
            percentual_frequencia_bimestre desc
    ) = 1

)

select * from deduplicated
