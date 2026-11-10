/*
    REGRA DE NEGÓCIO: os períodos de apuração de frequência de um mesmo aluno em
    uma mesma escola não podem se sobrepor no tempo.

    Por que importa: o percentual de frequência é "100 - faltas/dias letivos" do
    período. Se dois períodos se sobrepõem, os mesmos dias letivos entram duas
    vezes na média anual e o absenteísmo fica distorcido (para mais ou para
    menos). Também é o sintoma clássico de carga duplicada com datas deslocadas.

    Implementação: ordena os períodos consolidados (intermediate) por aluno/escola
    e compara o início de cada período com o fim do anterior.

    O teste falha se retornar qualquer linha.
*/

with periodos as (

    select
        id_aluno,
        id_escola,
        data_inicio_periodo,
        data_fim_periodo,
        lag(data_fim_periodo) over (
            partition by id_aluno, id_escola
            order by data_inicio_periodo
        ) as data_fim_periodo_anterior
    from {{ ref('int_educacao__aluno_frequencia_periodo') }}

)

select
    id_aluno,
    id_escola,
    data_fim_periodo_anterior,
    data_inicio_periodo
from periodos
where data_fim_periodo_anterior is not null
  and data_inicio_periodo <= data_fim_periodo_anterior
