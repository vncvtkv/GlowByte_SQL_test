-- Вторая задача

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
(123, '2012-08-05', '2011-03-01', 'Ленинградский проспект, 21'),
(123, '2012-06-01', '2014-01-01', 'Проспект Вернадского, 37'),
(123, '2014-01-01', '9999-12-31', 'Мосфильмовская ул, 12'),
(1, '2014-01-01', '9999-12-31', 'Улица Строителей 5');
-- Написать запрос, который бы вернул все client_id, для которых история изменения
-- атрибутов заведена некорректно
WITH problem_flags AS (
    SELECT 
        client_id,
        start_dt,
        end_dt,
        -- Проверка на некорректные даты (start_dt >= end_dt)
        CASE WHEN start_dt >= end_dt THEN 1 ELSE 0 END AS invalid_dates,
        -- Проверка на перекрытие с предыдущим периодом
        CASE WHEN LAG(end_dt) OVER (PARTITION BY client_id ORDER BY start_dt) >= start_dt 
             THEN 1 ELSE 0 END AS has_overlap,
        -- Проверка первой записи записи
        CASE WHEN LAG(start_dt) OVER (PARTITION BY client_id ORDER BY start_dt) IS NULL 
                  AND start_dt != DATE '1900-01-01' 
             THEN 1 ELSE 0 END AS invalid_first,
        -- Проверка последней записи
        CASE WHEN LEAD(start_dt) OVER (PARTITION BY client_id ORDER BY start_dt) IS NULL 
                  AND end_dt != DATE '9999-12-31'
             THEN 1 ELSE 0 END AS invalid_last
    FROM t_client_addr
)
SELECT DISTINCT client_id
FROM problem_flags
WHERE invalid_dates = 1 OR has_overlap = 1 OR invalid_first = 1 OR invalid_last = 1
ORDER BY client_id;

-- Написать запрос (или последовательность запросов), исправляющий некорректную
-- историю в таблице.

-- 1. Исправляем записи, где start_dt >= end_dt (меняем местами)
UPDATE t_client_addr 
SET 
    start_dt = LEAST(start_dt, end_dt),
    end_dt = GREATEST(start_dt, end_dt)
WHERE start_dt >= end_dt;

-- 2. Исправляем последнюю запись для каждого клиента
UPDATE t_client_addr t1
SET end_dt = DATE '9999-12-31'
WHERE NOT EXISTS (
    SELECT 1 FROM t_client_addr t2 
    WHERE t2.client_id = t1.client_id AND t2.start_dt > t1.start_dt
) AND end_dt != DATE '9999-12-31';

-- 3. Исправляем первую запись для каждого клиента
UPDATE t_client_addr t1
SET start_dt = DATE '1900-01-01'
WHERE NOT EXISTS (
    SELECT 1 FROM t_client_addr t2 
    WHERE t2.client_id = t1.client_id AND t2.start_dt < t1.start_dt
) AND start_dt != DATE '1900-01-01';

-- 4. Исправляем перекрывающиеся периоды (исправленная версия)
WITH overlap_correction AS (
    SELECT 
        a.client_id,
        a.start_dt AS original_start,
        a.end_dt AS original_end,
        MIN(b.start_dt) - 1 AS new_end_dt
    FROM t_client_addr a
    JOIN t_client_addr b ON a.client_id = b.client_id AND a.start_dt < b.start_dt AND a.end_dt > b.start_dt
    GROUP BY a.client_id, a.start_dt, a.end_dt
)
UPDATE t_client_addr t
SET end_dt = o.new_end_dt
FROM overlap_correction o
WHERE t.client_id = o.client_id 
  AND t.start_dt = o.original_start
  AND t.end_dt = o.original_end;

-- 5. Удаляем дубликаты и некорректные записи
DELETE FROM t_client_addr
WHERE ctid NOT IN (
    SELECT MIN(ctid)
    FROM t_client_addr
    GROUP BY client_id, start_dt, end_dt
);

SELECT * FROM
t_client_addr
ORDER BY client_id, start_dt;
