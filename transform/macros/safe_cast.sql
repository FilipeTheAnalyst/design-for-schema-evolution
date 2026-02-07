{% macro safe_cast(column_name, data_type, default_value='NULL') %}
{#
    Safely cast a column that may not exist yet due to schema evolution.
    If the column doesn't exist in the source, returns the default value.

    Usage:
        {{ safe_cast('precipitation_sum', 'FLOAT', '0.0') }}
#}
    TRY_CAST({{ column_name }} AS {{ data_type }})
{% endmacro %}
