{% macro calculate(metric_list, grain=none, dimensions=[], secondary_calculations=[], start_date=none, end_date=none, where=none, date_alias=none, base_filter=none, base_filter_field=none) %}
    {{ return(adapter.dispatch('calculate', 'metrics')(metric_list, grain, dimensions, secondary_calculations, start_date, end_date, where, date_alias, base_filter, base_filter_field)) }}
{% endmacro %}


{% macro default__calculate(metric_list, grain=none, dimensions=[], secondary_calculations=[], start_date=none, end_date=none, where=none, date_alias=none, base_filter=none, base_filter_field=none) %}
    {#- Need this here, since the actual ref is nested within loops/conditions: -#}
    -- depends on: {{ ref(var('dbt_metrics_calendar_model', 'dbt_metrics_default_calendar')) }}
    
    {#- ############
    VARIABLE SETTING - Creating the metric tree and making sure metric list is a list!
    ############ -#}

    {%- if execute %}
        {% do exceptions.warn(
            "WARNING: dbt_metrics is going to be deprecated in dbt-core 1.6 in \
July 2023 as part of the migration to MetricFlow. This package will \
continue to work with dbt-core 1.5 but a 1.6 version will not be \
released. If you have any questions, please join us in the #dbt-core-metrics in the dbt Community Slack") %}
    {%- endif %}

    {%- if metric_list is not iterable -%}
        {%- set metric_list = [metric_list] -%}
    {%- endif -%}
    {%- if base_filter_field and base_filter_field is string -%}
        {%- set base_filter_field = [base_filter_field] -%}
    {%- endif -%}

    {%- set metric_tree = metrics.get_metric_tree(metric_list=metric_list) -%}

    {#- Here we are creating the metrics dictionary which contains all of the metric information needed for sql gen. -#}
    {%- set metrics_dictionary = metrics.get_metrics_dictionary(metric_tree=metric_tree) -%}

    {% set ns = namespace(base_filter=base_filter) %}

    {%- if base_filter -%}
        {%- for item in base_filter_field -%}
            {%- set ns.base_filter -%}
                {{ ns.base_filter | replace(" "+item, " base_model."+item) }}
            {%- endset -%}
        {% endfor %}
    {%- endif -%}
    {% set additional_base_filter %}
        {%- if base_filter -%}
            {{ ns.base_filter }}
        {% else %}

        {% endif %}
    {%  endset %}

    {#- ############
    VALIDATION - Make sure everything is good!
    ############ -#}

    {%- if not execute -%}
        {%- do return("Did not execute") -%}
    {%- endif -%}

    {%- if not metric_list -%}
        {%- do exceptions.raise_compiler_error("No metric or metrics provided") -%}
    {%- endif -%}

    {%- do metrics.validate_timestamp(grain=grain, metric_tree=metric_tree, metrics_dictionary=metrics_dictionary, dimensions=dimensions) -%}

    {%- do metrics.validate_grain(grain=grain, metric_tree=metric_tree, metrics_dictionary=metrics_dictionary, secondary_calculations=secondary_calculations) -%}

    {%- do metrics.validate_derived_metrics(metric_tree=metric_tree) -%}

    {%- do metrics.validate_dimension_list(dimensions=dimensions, metric_tree=metric_tree, metrics_dictionary=metrics_dictionary) -%} 

    {# {%- do metrics.validate_metric_config(metrics_dictionary=metrics_dictionary) -%}  #}

    {%- do metrics.validate_where(where=where) -%} 

    {%- do metrics.validate_secondary_calculations(metric_tree=metric_tree, metrics_dictionary=metrics_dictionary, grain=grain, secondary_calculations=secondary_calculations) -%} 

    {%- do metrics.validate_calendar_model() -%}

    {#- ############
    SQL GENERATION - Lets build that SQL!
    ############ -#}

    {%- set sql = metrics.get_metric_sql(
        metrics_dictionary=metrics_dictionary,
        grain=grain,
        dimensions=dimensions,
        secondary_calculations=secondary_calculations,
        start_date=start_date,
        end_date=end_date,
        where=where,
        date_alias=date_alias,
        metric_tree=metric_tree,
        additional_base_filter=additional_base_filter
    ) %}

({{ sql }}) metric_subq 

{%- endmacro -%}
