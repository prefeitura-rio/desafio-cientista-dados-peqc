{#-
  Sobrescreve o comportamento padrão do dbt (<target.schema>_<custom_schema>)
  para que cada camada vá para um dataset próprio e previsível no BigQuery:
    staging      -> <dataset>_staging
    intermediate -> <dataset>_intermediate
    marts        -> <dataset>_marts
  Em ambientes de dev isso continua isolado porque <dataset> vem do profile.
-#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    {%- if custom_schema_name is none -%}
        {{ default_schema }}
    {%- else -%}
        {{ default_schema }}_{{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
