select *
from 
{{ dbt_metrics.calculate(
    metric('base_sum_metric__14_day_window'), 
    grain='week', 
    dimensions=[]) 
}}