{% macro excluded_suppliers() %}
    {% if target.name == 'cm' %}
        {# CM excluded supplier IDs — fill in here #}
        15,25,27,33,37,44,159,157,176
    {%elif target.name == 'sk'%}
    1,2,8,10,13,16
    {%elif target.name == 'aksata'%}
    8, 10,1,2
    {% else %}
        65,67,75,78,79,98,144,146,154,179
    {% endif %}
{% endmacro %}
