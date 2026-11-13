{% macro excluded_customers() %}
    {% if target.name == 'cm' %}
        {# CM excluded customer IDs — fill in here #}
        13,20,446,51,67,66,87,19,18,16,138,170,171,356,131,405,544
    {%elif target.name == 'sk'%}
    26 , 23 , 4,5,6,12,25,15,3,11
    {%elif target.name == 'aksata'%}
    1,2,15,16,21,22,29,45,127
    {% else %}
        788, 7, 6, 1162, 178, 194, 576,1058, 821, 1140, 1344, 1354, 1435, 1647,901,1853
        
    {% endif %}
{% endmacro %}
