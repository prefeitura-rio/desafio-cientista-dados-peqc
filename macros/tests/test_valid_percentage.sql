{#-
  Teste genérico customizado: garante que uma coluna de percentual esteja no
  intervalo [0, 100]. Nulos são ignorados (use not_null separadamente quando
  a coluna for obrigatória). Retorna as linhas violadoras para store_failures.
-#}
{% test valid_percentage(model, column_name) %}
select
    {{ column_name }} as valor_invalido
from {{ model }}
where {{ column_name }} is not null
  and ({{ column_name }} < 0 or {{ column_name }} > 100)
{% endtest %}
