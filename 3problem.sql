-- Третья задача

CREATE TABLE t_client_addr (
    client_id NUMERIC,
    start_dt DATE,
    end_dt DATE,
    client_addr VARCHAR(200),
    PRIMARY KEY (client_id, start_dt, end_dt)
);

INSERT INTO t_client_addr (client_id, start_dt, end_dt, client_addr)
VALUES
(123, '1900-01-01', '2012-07-04', 'Улица Строителей 5'),
(123, '2012-07-05', '2015-03-01', 'Ленинградский проспект, 21'),
(123, '2015-03-02', '9999-12-31', 'Мосфильмовская ул, 12'),
(144, '1900-01-01', '2012-03-01', 'Улица Строителей 5'),
(144, '2015-03-02', '9999-12-31', 'Мосфильмовская ул, 12'),
(144, '2012-03-01', '2015-03-01', 'Ленинградский проспект, 21');


CREATE TABLE t_client_job (
    client_id NUMERIC,
    start_dt DATE,
    end_dt DATE,
    client_job VARCHAR(200),
    PRIMARY KEY (client_id, start_dt, end_dt)
);

INSERT INTO t_client_job (client_id, start_dt, end_dt, client_job)
VALUES
(123, '1900-01-01', '2007-02-11', 'ПАО Аэрофлот'),
(123, '2007-02-12', '2013-11-22', 'ПАО ВТБ'),
(123, '2015-03-02', '9999-12-31', 'Мосфильмовская ул, 12'),
(144, '1900-01-01', '9999-12-31', 'Мосфильмовская ул, 12');;
-- Необходимо написать sql-запрос для формирования общей истории изменения двух атрибутов
-- клиента
-- 
WITH 
-- Собираем все ключевые даты изменений из обеих таблиц
all_dates AS (
    SELECT client_id, start_dt AS event_date FROM t_client_addr
    UNION
    SELECT client_id, end_dt + INTERVAL '1 day' AS event_date FROM t_client_addr WHERE end_dt != DATE '9999-12-31'
    UNION
    SELECT client_id, start_dt AS event_date FROM t_client_job
    UNION
    SELECT client_id, end_dt + INTERVAL '1 day' AS event_date FROM t_client_job WHERE end_dt != DATE '9999-12-31'
),

-- Создаем непрерывные периоды между точками изменений
date_ranges AS (
    SELECT 
        client_id,
        event_date AS start_dt,
        LEAD(event_date - INTERVAL '1 day') OVER (PARTITION BY client_id ORDER BY event_date) AS end_dt
    FROM all_dates
),

-- Фильтруем только валидные периоды (где start_dt < end_dt)
valid_periods AS (
    SELECT 
        client_id,
        start_dt,
        CASE 
            WHEN end_dt IS NULL THEN DATE '9999-12-31'
            ELSE end_dt
        END AS end_dt
    FROM date_ranges
    WHERE start_dt < COALESCE(end_dt, DATE '9999-12-31')
)

-- Соединяем периоды с актуальными адресами и местами работы
SELECT 
    v.client_id,
    v.start_dt,
    v.end_dt,
    a.client_addr,
    j.client_job
FROM valid_periods v
LEFT JOIN t_client_addr a ON v.client_id = a.client_id 
    AND v.start_dt >= a.start_dt 
    AND v.end_dt <= a.end_dt
LEFT JOIN t_client_job j ON v.client_id = j.client_id 
    AND v.start_dt >= j.start_dt 
    AND v.end_dt <= j.end_dt
WHERE a.client_id IS NOT NULL OR j.client_id IS NOT NULL
ORDER BY v.client_id, v.start_dt;

