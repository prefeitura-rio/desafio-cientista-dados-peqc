{#-
  O id_aluno chega como BYTES (34 bytes de hash) nos Parquets/BigQuery.
  Padronizamos para STRING hexadecimal em todas as camadas: facilita joins,
  testes, exportação e leitura humana. Caso a fonte já esteja como STRING,
  basta rodar com --vars '{id_aluno_is_bytes: false}'.
-#}
{% macro aluno_id_to_string(column_name) -%}
    {%- if var('id_aluno_is_bytes', true) -%}
        lower(to_hex({{ column_name }}))
    {%- else -%}
        lower(cast({{ column_name }} as string))
    {%- endif -%}
{%- endmacro %}
