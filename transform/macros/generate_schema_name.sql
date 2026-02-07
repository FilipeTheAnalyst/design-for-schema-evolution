{% macro generate_schema_name(custom_schema_name, node) -%}
{#
    Override dbt's default schema naming to use clean schema names
    (e.g. STAGING instead of <target_schema>_STAGING).
#}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim }}
    {%- endif -%}
{%- endmacro %}
