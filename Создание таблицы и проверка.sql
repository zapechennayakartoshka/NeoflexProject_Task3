CREATE TABLE "DM"."DM_F101_ROUND_F" ( 
	"FROM_DATE" DATE NOT NULL,
	"TO_DATE" DATE NOT NULL,
	"CHAPTER" CHAR(1),
	"LEDGER_ACCOUNT" CHAR(5),
	"CHARACTERISTIC" CHAR(1),
	"BALANCE_IN_RUB" NUMERIC(23,8),
	"BALANCE_IN_VAL" NUMERIC(23,8),
	"BALANCE_IN_TOTAL" NUMERIC(23,8),
	"TURN_DEB_RUB" NUMERIC(23,8),
	"TURN_DEB_VAL" NUMERIC(23,8),
	"TURN_DEB_TOTAL" NUMERIC(23,8),
	"TURN_CRE_RUB" NUMERIC(23,8),
	"TURN_CRE_VAL" NUMERIC(23,8),
	"TURN_CRE_TOTAL" NUMERIC(23,8),
	"BALANCE_OUT_RUB" NUMERIC(23,8),
	"BALANCE_OUT_VAL" NUMERIC(23,8),
	"BALANCE_OUT_TOTAL" NUMERIC(23,8) 
); 

CALL "DM"."fill_f101_round_f"('2018-02-01');

select * from "DM"."DM_F101_ROUND_F";

SELECT * FROM "LOGS"."ETL_LOG" ORDER BY log_id DESC;
 

 --ПРОВЕРКА

--Какие счета входят в 30110
select   acc.account_rk, acc.account_number, acc.currency_code,  acc.char_type
from "DS"."MD_ACCOUNT_D" acc
where substring(acc.account_number from 1 for 5) = '30110'
    and '2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date
order by acc.account_rk;

--Проверка входящих остатков


select acc.account_rk, acc.account_number, acc.currency_code, b.balance_out_rub
from "DS"."MD_ACCOUNT_D" acc
left join "DM"."DM_ACCOUNT_BALANCE_F" b on b.account_rk = acc.account_rk
and b.on_date = '2017-12-31'
where substring(acc.account_number from 1 for 5) = '30110'
and '2018-01-31' BETWEEN acc.data_actual_date AND acc.data_actual_end_date
 
 
--Проверка агрегирования входящих остатков
--balance_in_rub=1347893.83000000
--balance_in_val=248922.80000000
--balance_in_total=1596816.63000000

select
SUM(case when acc.currency_code IN ('810', '643') then COALESCE(b.balance_out_rub,0) ELSE 0 END ) as balance_in_rub,
SUM(case when acc.currency_code NOT IN ('810', '643') then COALESCE(b.balance_out_rub,0) ELSE 0 END ) as balance_in_val,
SUM(COALESCE(b.balance_out_rub,0)) as balance_in_total
from "DS"."MD_ACCOUNT_D" acc
left join "DM"."DM_ACCOUNT_BALANCE_F" b on b.account_rk = acc.account_rk AND b.on_date = '2017-12-31'
where substring(acc.account_number from 1 for 5) = '30110'
    and '2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date;
 
--Проверка строки формы 101
SELECT *
FROM "DM"."DM_F101_ROUND_F"
WHERE "LEDGER_ACCOUNT" = '30110';

-- Проверка оборотов

 
select acc.account_rk, acc.account_number, acc.currency_code,
 SUM(t.debet_amount_rub) AS deb_rub,
 SUM(t.credit_amount_rub) AS cre_rub
from "DS"."MD_ACCOUNT_D" acc
left join "DM"."DM_ACCOUNT_TURNOVER_F" t on t.account_rk = acc.account_rk
   and t.on_date BETWEEN '2018-01-01' and '2018-01-31'
where substring(acc.account_number from 1 for 5) = '30110'
    and '2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date
group by acc.account_rk, acc.account_number, acc.currency_code
order by acc.account_rk;
 
--Проверка итоговых оборотов
 --turn_deb_rub=373332.34000000
--turn_deb_val=0
--turn_deb_total=373332.34000000
--turn_cre_val=0
--turn_cre_total=1083668.65000000

select 
SUM(case when acc.currency_code IN ('810','643') then COALESCE(t.debet_amount_rub,0) ELSE 0 END) as turn_deb_rub,
SUM(case when acc.currency_code NOT IN ('810','643') then COALESCE(t.debet_amount_rub,0) ELSE 0 END )as turn_deb_val,
SUM(COALESCE(t.debet_amount_rub,0)) AS turn_deb_total,
SUM(case when acc.currency_code IN ('810','643') then COALESCE(t.credit_amount_rub,0) ELSE 0 END) as turn_cre_rub,
SUM(case when acc.currency_code NOT IN ('810','643') then COALESCE(t.credit_amount_rub,0) ELSE 0 END ) as turn_cre_val,
SUM(COALESCE(t.credit_amount_rub,0)) as turn_cre_total
from"DS"."MD_ACCOUNT_D" acc
left join "DM"."DM_ACCOUNT_TURNOVER_F" t on t.account_rk = acc.account_rk
	and t.on_date BETWEEN '2018-01-01' AND '2018-01-31'
where substring(acc.account_number from 1 for 5) = '30110'
 	and '2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date;

--Проверка строки формы 101
SELECT *
FROM "DM"."DM_F101_ROUND_F"
WHERE "LEDGER_ACCOUNT" = '30110';

--Проверка исходящих остатков
 
select acc.account_rk, acc.account_number, acc.currency_code,  b.balance_out_rub
from "DS"."MD_ACCOUNT_D" acc
left join  "DM"."DM_ACCOUNT_BALANCE_F" b on b.account_rk = acc.account_rk AND b.on_date = '2018-01-31'
where substring(acc.account_number from 1 for 5) = '30110'
  and'2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date
 

--Проверка итоговых исходящих остатков
  --balance_out_rub=637557.52000000
  --balance_out_val=248922.80000000
  --balance_out_total=886480.32000000

select
SUM(case when acc.currency_code IN ('810','643') then COALESCE(b.balance_out_rub,0) ELSE 0  END) as balance_out_rub,
SUM(case when acc.currency_code NOT IN ('810','643') then COALESCE(b.balance_out_rub,0) ELSE 0 END) as balance_out_val,
SUM(COALESCE(b.balance_out_rub,0)) as balance_out_total
from "DS"."MD_ACCOUNT_D" acc
left join "DM"."DM_ACCOUNT_BALANCE_F" b on b.account_rk = acc.account_rk and b.on_date = '2018-01-31'
where substring(acc.account_number from 1 for 5) = '30110' and '2018-01-31' BETWEEN acc.data_actual_date and acc.data_actual_end_date;

--Проверка строки формы 101
SELECT *
FROM "DM"."DM_F101_ROUND_F"
WHERE "LEDGER_ACCOUNT" = '30110';