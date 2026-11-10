{#-
  Tradução dos códigos genéricos de disciplina para nomes legíveis.
  Mapeamento fornecido no schema.yml original do bucket (rmi/schema.yml).
  Centralizado em macro para que staging de frequência e avaliação usem a
  mesma nomenclatura (evita "Português" num lugar e "Língua Portuguesa" noutro).
-#}
{% macro map_disciplina(column_name) -%}
    case {{ column_name }}
        when 'disciplina_1' then 'Língua Portuguesa'
        when 'disciplina_2' then 'Ciências'
        when 'disciplina_3' then 'Língua Estrangeira (Inglês)'
        when 'disciplina_4' then 'Matemática'
        else 'Desconhecida'
    end
{%- endmacro %}
