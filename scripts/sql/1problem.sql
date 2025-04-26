-- Первая задача

-- Создание таблицы clnt_aggr
CREATE TABLE clnt_aggr (
    client_dk NUMERIC PRIMARY KEY,
    tb_name VARCHAR(100),
    salary NUMERIC,
    pos_amt NUMERIC,
    pos_qty NUMERIC,
    report_dt DATE
);
-- Заполнение данными clnt_aggr
INSERT INTO clnt_aggr (client_dk, tb_name, salary, pos_amt, pos_qty, report_dt) 
VALUES
(507851886, 'Московский банк', 15000, 6400, 8, '2019-05-31'),
(267188214, 'Центрально-Черноземный банк', 50000, 13200, 10, '2019-05-31'),
(148849526, 'Московский банк', 30000, 35000, 3, '2019-06-30'),
(613898474, 'Юго-Западный банк', 150000, 61000, 26, '2019-06-30');

-- Создание таблицы clnt_data
CREATE TABLE clnt_data (
    client_dk NUMERIC,
    actual_from_dt DATE,
    actual_to_dt DATE,
    gender VARCHAR(1),
    age NUMERIC,
    сhild_qty NUMERIC,
    PRIMARY KEY (client_dk, actual_from_dt)
);
-- Заполнение данными clnt_data
INSERT INTO clnt_data (client_dk, actual_from_dt, actual_to_dt, gender, age, сhild_qty) 
VALUES 
(507851886, '2019-03-05', '2019-07-20', 'M', 25, 1),
(507851886, '2019-07-21', '2099-12-31', 'M', 25, 2),
(267188214, '2019-02-01', '2099-12-31', 'M', 46, 3),
(148849526, '2018-09-15', '2099-12-31', 'W', 18, 0),
(613898474, '2018-05-11', '2099-12-31', 'M', 73, 2);

-- Первый пункт
/*
На все отчетные даты за 2019 г. вывести количество клиентов и средний размер заработной
платы по территориальным банкам, полу и группе по возрасту (меньше 18 (включительно), от
18 до 30 (включительно), от 30 до 60(включительно), больше 60 лет).
*/
WITH client_info AS (
    -- Соединяем данные о клиентах с их финансовой информацией
    -- с учетом периодов актуальности
    SELECT 
        ca.client_dk,
        ca.tb_name,
        ca.salary,
        ca.report_dt,
        cd.gender,
        -- Определяем возрастную группу
        CASE 
            WHEN cd.age <= 18 THEN 'до 18 лет'
            WHEN cd.age <= 30 THEN '18-30 лет'
            WHEN cd.age <= 60 THEN '30-60 лет'
            ELSE 'старше 60 лет'
        END AS age_group
    FROM 
        clnt_aggr ca
    JOIN 
        clnt_data cd ON ca.client_dk = cd.client_dk
    WHERE 
        ca.report_dt BETWEEN cd.actual_from_dt AND cd.actual_to_dt
        AND ca.report_dt BETWEEN '2019-01-01' AND '2019-12-31'
)
-- Агрегируем данные по тербанкам, полу и возрастным группам
SELECT 
    report_dt AS "Отчетная дата",
    COUNT(DISTINCT client_dk) AS "Количество клиентов",
    ROUND(AVG(salary), 2) AS "Средняя зарплата",
    tb_name AS "Территориальный банк",
    gender AS "Пол",
    age_group AS "Возрастная группа"
FROM 
    client_info
GROUP BY 
    tb_name, gender, age_group, report_dt
ORDER BY 
    tb_name, gender, age_group, report_dt;


-- Второй пункт
/*
На самую актуальную дату вывести территориальный банк, возраст и заработную плату
клиентов, получающих максимальную заработную плату в своем территориальном банке.
*/
WITH current_data AS(
  SELECT
    ca.tb_name,
    ca.salary,
    cd.age,
    -- Ранжируем клиентов по зарплате в рамках каждого банка
    RANK() OVER (PARTITION BY ca.tb_name ORDER BY ca.salary DESC) as salary_rank
  FROM clnt_aggr ca
  JOIN 
       clnt_data cd ON ca.client_dk = cd.client_dk
  WHERE ca.report_dt = (SELECT MAX(report_dt) FROM clnt_aggr)
  AND ca.report_dt BETWEEN cd.actual_from_dt AND cd.actual_to_dt
)
SELECT 
    tb_name AS "Территориальный банк",
    age AS "Возраст",
    salary AS "Зарплата"
FROM 
    current_data
WHERE 
    salary_rank = 1  -- Берем только клиентов с максимальной зарплатой
ORDER BY 
    tb_name;

-- Третий пункт
/*
На самую актуальную дату вывести идентификаторы клиентов, у которых pos-оборот строго
больше, чем в среднем по базе.
*/

WITH pos_stats AS (
    SELECT 
        ca.client_dk,
        ca.pos_amt,
        AVG(pos_amt) OVER () AS avg_pos_amount
    FROM clnt_aggr ca
    JOIN 
       clnt_data cd ON ca.client_dk = cd.client_dk
    WHERE ca.report_dt = (SELECT MAX(report_dt) FROM clnt_aggr)
    AND ca.report_dt BETWEEN cd.actual_from_dt AND cd.actual_to_dt
)
SELECT 
    client_dk AS "Идентификатор клиента",
    pos_amt AS "POS-оборот",
    avg_pos_amount AS "Средний оборот по базе"
FROM 
    pos_stats
WHERE 
    pos_amt > avg_pos_amount
ORDER BY 
    pos_amt DESC;
