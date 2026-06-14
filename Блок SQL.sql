CREATE DATABASE finalproject;
USE finalproject;

SELECT * FROM customer_info LIMIT 10;
SELECT * FROM transactions_info LIMIT 10;

-- 1 список клиентов с непрерывной историей за год, клиенты с покупками каждый месяц
WITH checks AS (
    SELECT
        ID_client,
        Id_check,
        STR_TO_DATE(date_new, '%d/%m/%Y') AS check_date,
        SUM(Sum_payment) AS check_sum
    FROM transactions_info
    GROUP BY 
        ID_client, 
        Id_check, 
        STR_TO_DATE(date_new, '%d/%m/%Y')
),
period_checks AS (
    SELECT *
    FROM checks
    WHERE check_date >= '2015-06-01'
      AND check_date <  '2016-06-01'
)
SELECT *
FROM period_checks
LIMIT 10;

-- 2 Показатели по месяцам
WITH checks AS (
    SELECT
        ID_client,
        Id_check,
        STR_TO_DATE(date_new, '%d/%m/%Y') AS check_date,
        SUM(Sum_payment) AS check_sum
    FROM transactions_info
    GROUP BY ID_client, Id_check, STR_TO_DATE(date_new, '%d/%m/%Y')
),
period_checks AS (
    SELECT *
    FROM checks
    WHERE check_date >= '2015-06-01'
      AND check_date < '2016-06-01'
),
monthly AS (
    SELECT
        DATE_FORMAT(check_date, '%Y-%m') AS month_num,
        AVG(check_sum) AS avg_check_month,
        COUNT(*) AS operations_count,
        COUNT(DISTINCT ID_client) AS clients_count,
        SUM(check_sum) AS month_sum
    FROM period_checks
    GROUP BY DATE_FORMAT(check_date, '%Y-%m')
),
year_total AS (
    SELECT
        COUNT(*) AS total_operations,
        SUM(check_sum) AS total_sum
    FROM period_checks
)
SELECT
    m.month_num,
    ROUND(m.avg_check_month, 2) AS avg_check_month,
    ROUND(m.operations_count / m.clients_count, 2) AS avg_operations_per_client,
    m.clients_count AS active_clients,
    ROUND(m.operations_count / yt.total_operations * 100, 2) AS operations_share_percent,
    ROUND(m.month_sum / yt.total_sum * 100, 2) AS sum_share_percent
FROM monthly m
CROSS JOIN year_total yt
ORDER BY m.month_num;

-- 3 Соотношение M / F / NA по месяцам
WITH checks AS (
    SELECT
        ID_client,
        Id_check,
        STR_TO_DATE(date_new, '%d/%m/%Y') AS check_date,
        SUM(Sum_payment) AS check_sum
    FROM transactions_info
    GROUP BY ID_client, Id_check, STR_TO_DATE(date_new, '%d/%m/%Y')
),
period_checks AS (
    SELECT *
    FROM checks
    WHERE check_date >= '2015-06-01'
      AND check_date < '2016-06-01'
),
gender_month AS (
    SELECT
        DATE_FORMAT(pc.check_date, '%Y-%m') AS month_num,
        COALESCE(ci.Gender, 'NA') AS gender,
        COUNT(DISTINCT pc.ID_client) AS clients_count,
        COUNT(*) AS operations_count,
        SUM(pc.check_sum) AS total_sum
    FROM period_checks pc
    LEFT JOIN customer_info ci
        ON pc.ID_client = ci.Id_client
    GROUP BY DATE_FORMAT(pc.check_date, '%Y-%m'), COALESCE(ci.Gender, 'NA')
),
month_total AS (
    SELECT
        month_num,
        SUM(clients_count) AS total_clients,
        SUM(total_sum) AS month_sum
    FROM gender_month
    GROUP BY month_num
)
SELECT
    gm.month_num,
    gm.gender,
    gm.clients_count,
    ROUND(gm.clients_count / mt.total_clients * 100, 2) AS gender_clients_percent,
    ROUND(gm.total_sum, 2) AS gender_sum,
    ROUND(gm.total_sum / mt.month_sum * 100, 2) AS gender_sum_percent
FROM gender_month gm
JOIN month_total mt
    ON gm.month_num = mt.month_num
ORDER BY gm.month_num, gm.gender;

-- 4 Возрастные группы за весь период
WITH checks AS (
    SELECT
        ID_client,
        Id_check,
        STR_TO_DATE(date_new, '%d/%m/%Y') AS check_date,
        SUM(Sum_payment) AS check_sum
    FROM transactions_info
    GROUP BY ID_client, Id_check, STR_TO_DATE(date_new, '%d/%m/%Y')
),
period_checks AS (
    SELECT *
    FROM checks
    WHERE check_date >= '2015-06-01'
      AND check_date < '2016-06-01'
),
age_data AS (
    SELECT
        pc.*,
        CASE
            WHEN ci.Age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(ci.Age / 10) * 10, '-', FLOOR(ci.Age / 10) * 10 + 9)
        END AS age_group
    FROM period_checks pc
    LEFT JOIN customer_info ci
        ON pc.ID_client = ci.Id_client
),
total AS (
    SELECT
        COUNT(*) AS total_operations,
        SUM(check_sum) AS total_sum
    FROM age_data
)
SELECT
    age_group,
    COUNT(*) AS operations_count,
    ROUND(SUM(check_sum), 2) AS total_sum,
    ROUND(AVG(check_sum), 2) AS avg_check,
    ROUND(COUNT(*) / t.total_operations * 100, 2) AS operations_percent,
    ROUND(SUM(check_sum) / t.total_sum * 100, 2) AS sum_percent
FROM age_data
CROSS JOIN total t
GROUP BY age_group, t.total_operations, t.total_sum
ORDER BY age_group;

-- 5 Возрастные группы поквартально
WITH checks AS (
    SELECT
        ID_client,
        Id_check,
        STR_TO_DATE(date_new, '%d/%m/%Y') AS check_date,
        SUM(Sum_payment) AS check_sum
    FROM transactions_info
    GROUP BY ID_client, Id_check, STR_TO_DATE(date_new, '%d/%m/%Y')
),
period_checks AS (
    SELECT *
    FROM checks
    WHERE check_date >= '2015-06-01'
      AND check_date < '2016-06-01'
),
age_data AS (
    SELECT
        pc.*,
        CONCAT(YEAR(pc.check_date), '-Q', QUARTER(pc.check_date)) AS quarter_num,
        CASE
            WHEN ci.Age IS NULL THEN 'NA'
            ELSE CONCAT(FLOOR(ci.Age / 10) * 10, '-', FLOOR(ci.Age / 10) * 10 + 9)
        END AS age_group
    FROM period_checks pc
    LEFT JOIN customer_info ci
        ON pc.ID_client = ci.Id_client
),
quarter_total AS (
    SELECT
        quarter_num,
        COUNT(*) AS quarter_operations,
        SUM(check_sum) AS quarter_sum
    FROM age_data
    GROUP BY quarter_num
)
SELECT
    ad.quarter_num,
    ad.age_group,
    COUNT(*) AS operations_count,
    ROUND(SUM(ad.check_sum), 2) AS total_sum,
    ROUND(AVG(ad.check_sum), 2) AS avg_check,
    ROUND(COUNT(*) / qt.quarter_operations * 100, 2) AS operations_percent_in_quarter,
    ROUND(SUM(ad.check_sum) / qt.quarter_sum * 100, 2) AS sum_percent_in_quarter
FROM age_data ad
JOIN quarter_total qt
    ON ad.quarter_num = qt.quarter_num
GROUP BY ad.quarter_num, ad.age_group, qt.quarter_operations, qt.quarter_sum
ORDER BY ad.quarter_num, ad.age_group;