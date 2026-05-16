CREATE OR REPLACE PROCEDURE "DM"."fill_f101_round_f"(i_OnDate date)
as $$
declare
    v_start_time TIMESTAMP;
    v_end_time TIMESTAMP;
    v_duration_sec INTEGER;
    v_rows INTEGER;
    v_error_message TEXT;
    v_process_name VARCHAR(255) := 'fill_f101_round_f'; 
    v_from_date DATE;
    v_to_date DATE;
    v_prev_date DATE;
BEGIN 
    v_from_date := date_trunc('month', i_OnDate - interval '1 month')::date;  
    v_to_date := (date_trunc('month', i_OnDate) - interval '1 day')::date; 
    v_prev_date := v_from_date - interval '1 day'; 
    v_start_time := now();
 
    insert into "LOGS"."ETL_LOG" (process_name, cur_date, start_time, status, source, user_name)
	values (v_process_name, i_OnDate, v_start_time, 'RUNNING', 'DM.DM_F101_ROUND_F', CURRENT_USER);
 
	delete from "DM"."DM_F101_ROUND_F"
	where "FROM_DATE" = v_from_date and "TO_DATE" = v_to_date;

	with accounts as (
		select
			acc.account_rk,
			substring(acc.account_number from 1 for 5) as ledger_account,
			acc.char_type,
			acc.currency_code,
			la.chapter
		from "DS"."MD_ACCOUNT_D" acc
		left join "DS"."MD_LEDGER_ACCOUNT_S" la on la.ledger_account = substring(acc.account_number from 1 for 5)::integer
		where v_to_date BETWEEN acc.data_actual_date and acc.data_actual_end_date),

	balance_in as (
        select
			b.account_rk,
			b.balance_out_rub
		from "DM"."DM_ACCOUNT_BALANCE_F" b
		where b.on_date = v_prev_date),

	balance_out as(
		select
			b.account_rk,
			b.balance_out_rub
		from "DM"."DM_ACCOUNT_BALANCE_F" b
		where b.on_date = v_to_date),

	turnover as (
		select
			t.account_rk,
			SUM(t.debet_amount_rub) as debet_amount_rub,
			SUM(t.credit_amount_rub) as credit_amount_rub
		from "DM"."DM_ACCOUNT_TURNOVER_F" t
		where t.on_date between v_from_date and v_to_date
		group by t.account_rk)

	INSERT INTO "DM"."DM_F101_ROUND_F"
	("FROM_DATE", "TO_DATE", "CHAPTER", "LEDGER_ACCOUNT", "CHARACTERISTIC", "BALANCE_IN_RUB", "BALANCE_IN_VAL", "BALANCE_IN_TOTAL", "TURN_DEB_RUB",
	 "TURN_DEB_VAL", "TURN_DEB_TOTAL", "TURN_CRE_RUB", "TURN_CRE_VAL", "TURN_CRE_TOTAL", "BALANCE_OUT_RUB", "BALANCE_OUT_VAL", "BALANCE_OUT_TOTAL") 

	select
	v_from_date, --Начало интервала расчета
	v_to_date, --Конец интервала расчета
	a.chapter, --Глава баланса
	a.ledger_account, --Балансовый счет
	a.char_type, --Характеристика счета

 		--Входящий остаток для рублевых счетов
		SUM(case when a.currency_code IN ('810', '643') then COALESCE(bi.balance_out_rub, 0) ELSE 0 END) as balance_in_rub,

		--Входящий остаток для счетов в валюте и драг. Металлах
		SUM(case when a.currency_code NOT IN ('810', '643') then COALESCE(bi.balance_out_rub, 0) ELSE 0 END) as balance_in_val,

		--Входящий остаток – итого
		SUM(COALESCE(bi.balance_out_rub, 0)) as balance_in_total,

		--Сумма дебетовых оборотов для рублевых счетов
		SUM(case when a.currency_code IN ('810', '643') then COALESCE(t.debet_amount_rub, 0) ELSE 0 END) as turn_deb_rub,

		--Сумма дебетовых оборотов для счетов в валюте и драг. Металлах
		SUM(case when a.currency_code NOT IN ('810', '643') then COALESCE(t.debet_amount_rub, 0) ELSE 0 END) as turn_deb_val,

		--Сумма дебетовых оборотов – итого
		SUM(COALESCE(t.debet_amount_rub, 0)) AS turn_deb_total,

		--Сумма кредитовых оборотов для рублевых счетов
		SUM(case when a.currency_code IN ('810', '643') then COALESCE(t.credit_amount_rub, 0) ELSE 0 END) as turn_cre_rub,

		--Сумма кредитовых оборотов для счетов в валюте и драг. Металлах
		SUM(case when a.currency_code NOT IN ('810', '643') then COALESCE(t.credit_amount_rub, 0) ELSE 0 END ) as turn_cre_val,

		--Сумма кредитовых оборотов – итого
		SUM(COALESCE(t.credit_amount_rub, 0)) as turn_cre_total,

		--Сумма исходящего остатка для рублевых счетов
		SUM(case when a.currency_code IN ('810', '643') then COALESCE(bo.balance_out_rub, 0) ELSE 0 END) as balance_out_rub,

		--Сумма исходящего остатка для счетов в валюте и драг. металлах
		SUM(case when a.currency_code NOT IN ('810', '643') then COALESCE(bo.balance_out_rub, 0) ELSE 0 END) as balance_out_val,

		--Сумма исходящего остатка - итого
		SUM(COALESCE(bo.balance_out_rub, 0)) as balance_out_total

	from accounts a
 		left join balance_in bi on bi.account_rk = a.account_rk
 		left join balance_out bo on bo.account_rk = a.account_rk
 		left join turnover t on t.account_rk = a.account_rk
 	group by a.chapter, a.ledger_account, a.char_type
 	ORDER BY a.ledger_account;

    -- Получаем количество вставленных строк
	GET DIAGNOSTICS v_rows = ROW_COUNT;
    
	-- Завершаем логирование
	v_end_time := now();
	v_duration_sec := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
    
    -- Логируем успешное завершение
	insert into "LOGS"."ETL_LOG" (process_name, cur_date, start_time, end_time, duration_sec, status, rows_written, source, user_name)
	values (v_process_name, i_OnDate, v_start_time, v_end_time, v_duration_sec, 'SUCCESS', v_rows, 'DM.DM_F101_ROUND_F', CURRENT_USER);

	raise notice 'Форма 101 за период % - % заполнена. Добавлено строк: %', v_from_date, v_to_date, v_rows;

	EXCEPTION
	WHEN OTHERS THEN
		GET STACKED DIAGNOSTICS v_error_message = MESSAGE_TEXT;
		v_end_time := CURRENT_TIMESTAMP;
		v_duration_sec := EXTRACT(EPOCH FROM (v_end_time - v_start_time));
        
 	insert into "LOGS"."ETL_LOG" (process_name, cur_date, start_time, end_time, duration_sec, status, error_message, rows_error, source, user_name)
	values(v_process_name, i_OnDate, v_start_time, v_end_time, v_duration_sec, 'ERROR', v_error_message, 1, 'DM.DM_F101_ROUND_F', CURRENT_USER);

	raise notice 'Ошибка при расчете формы 101 за %: %', i_OnDate, v_error_message;

END;
$$ language plpgsql;