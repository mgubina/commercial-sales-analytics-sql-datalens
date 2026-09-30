-- Шаг 1. Агрегация выручки по месяцам и направлениям
CREATE OR REPLACE VIEW public.step1_monthly_revenue
AS SELECT date_trunc('month'::text, revenue_date::timestamp with time zone)::date AS finance_month,
    department_name,
    sum(amount_rub) AS total_revenue
   FROM fact_revenue
  GROUP BY (date_trunc('month'::text, revenue_date::timestamp with time zone)::date), department_name;
  
-- Шаг 2. Агрегация себестоимости по месяцам и направлениям
CREATE OR REPLACE VIEW public.step2_monthly_cost
AS SELECT date_trunc('month'::text, cost_date::timestamp with time zone)::date AS finance_month,
    department_name,
    sum(cost_rub) AS total_cost
   FROM fact_cost
  GROUP BY (date_trunc('month'::text, cost_date::timestamp with time zone)::date), department_name;  

-- Шаг 3. Финальная витрина с аналитическими оконными функциями
CREATE OR REPLACE VIEW public.v_global_finance_analytics
AS SELECT r.finance_month,
    r.department_name,
    r.total_revenue AS revenue,
    c.total_cost AS cost,
    r.total_revenue - c.total_cost AS margin,
    round((r.total_revenue - c.total_cost)::numeric / r.total_revenue::numeric * 100::numeric, 2) AS profitability,
    dense_rank() OVER (PARTITION BY r.finance_month ORDER BY (round((r.total_revenue - c.total_cost)::numeric / r.total_revenue::numeric * 100::numeric, 2)) DESC) AS rank_margin_in_month,
    sum(r.total_revenue - c.total_cost) OVER (PARTITION BY r.department_name ORDER BY r.finance_month) AS running_total_margin,
    lag(r.total_revenue - c.total_cost, 1) OVER (PARTITION BY r.department_name ORDER BY r.finance_month) AS prev_month_margin
   FROM step1_monthly_revenue r
     JOIN step2_monthly_cost c ON r.finance_month = c.finance_month AND r.department_name::text = c.department_name::text;