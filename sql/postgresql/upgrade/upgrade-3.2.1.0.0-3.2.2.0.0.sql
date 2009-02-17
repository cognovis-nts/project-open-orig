-- upgrade-3.2.1.0.0-3.2.2.0.0.sql

SELECT acs_log__debug('/packages/intranet-exchange-rate/sql/postgresql/upgrade/upgrade-3.2.1.0.0-3.2.2.0.0.sql','');


create or replace function im_day_enumerator (
	date, date
) returns setof date as '
declare
	p_start_date		alias for $1;
	p_end_date		alias for $2;
	v_date			date;
BEGIN
	v_date := p_start_date;
	WHILE (v_date < p_end_date) LOOP
		RETURN NEXT v_date;
		v_date := v_date + 1;
	END LOOP;
	RETURN;
end;' language 'plpgsql';


create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		integer;
	v_admin_menu	integer;

	-- Groups
	v_accounting	integer;
	v_senman	integer;
	v_admins	integer;

	v_count				integer;
BEGIN
	select  count(*) into v_count from im_menus
	where   label = ''admin_exchange_rates'';
	if v_count = 1 then return 0; end if;

	select group_id into v_admins from groups where group_name = ''P/O Admins'';
	select group_id into v_senman from groups where group_name = ''Senior Managers'';
	select group_id into v_accounting from groups where group_name = ''Accounting'';

	select menu_id into v_admin_menu from im_menus where label=''admin'';

	v_menu := im_menu__new (
		null,			-- p_menu_id
		''acs_object'',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		''intranet-exchange-rate'',  -- package_name
		''admin_exchange_rates'',	-- label
		''Exchange Rates'',	-- name
		''/intranet-exchange-rate/index'',   -- url
		80,			-- sort_order
		v_admin_menu,		-- parent_menu_id
		null			-- p_visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');

	return 0;
end;' language 'plpgsql';
select inline_0 ();
drop function inline_0 ();



create or replace function inline_0 ()
returns integer as '
declare
	-- Menu IDs
	v_menu		integer;
	v_finance_menu	integer;

	-- Groups
	v_accounting	integer;
	v_senman	integer;
	v_admins	integer;

	v_count				integer;
BEGIN
	select  count(*) into v_count from im_menus
	where   label = ''finance_exchange_rates'';
	if v_count = 1 then return 0; end if;

	select group_id into v_admins from groups where group_name = ''P/O Admins'';
	select group_id into v_senman from groups where group_name = ''Senior Managers'';
	select group_id into v_accounting from groups where group_name = ''Accounting'';

	select menu_id into v_finance_menu from im_menus where label=''finance'';

	v_menu := im_menu__new (
		null,			-- p_menu_id
		''acs_object'',		-- object_type
		now(),			-- creation_date
		null,			-- creation_user
		null,			-- creation_ip
		null,			-- context_id
		''intranet-exchange-rate'',  -- package_name
		''finance_exchange_rates'',	-- label
		''Exchange Rates'',	-- name
		''/intranet-exchange-rate/index'',   -- url
		80,			-- sort_order
		v_finance_menu,		-- parent_menu_id
		null			-- p_visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_menu, v_admins, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_senman, ''read'');
	PERFORM acs_permission__grant_permission(v_menu, v_accounting, ''read'');

	return 0;
end;' language 'plpgsql';
select inline_0();
drop function inline_0 ();





-- Fills ALL "holes" in the im_exchange_rates table.
-- Populate im_exchange_rates for the next 5 years
create or replace function im_exchange_rate_fill_holes (varchar)
returns integer as '
DECLARE
    p_currency			alias for $1;
    v_max			integer;
    v_start_date		date;
    v_rate			numeric;
    row2			RECORD;
    exists			integer;
BEGIN
    RAISE NOTICE ''im_exchange_rate_fill_holes: cur=%'', p_currency;

    v_start_date := to_date(''1999-01-01'', ''YYYY-MM-DD'');
    v_max := 365 * 16;

    -- Loop through all dates and check if there
    -- is a hole (no entry for a date)
    FOR row2 IN
	select	im_day_enumerator as day
	from	im_day_enumerator(v_start_date, v_start_date + v_max)
		LEFT OUTER JOIN (
			select	*
			from	im_exchange_rates 
			where	currency = p_currency
		) ex on (im_day_enumerator = ex.day)
	where	ex.rate is null
    LOOP
	-- RAISE NOTICE ''im_exchange_rate_fill_holes: day=%'', row2.day;
	-- get the latest manually entered exchange rate
	select	rate
	into	v_rate
	from	im_exchange_rates 
	where	day = (
			select	max(day) 
			from	im_exchange_rates 
			where	day < row2.day
				and currency = p_currency
				and manual_p = ''t''
		      )
		and currency = p_currency;
	-- RAISE NOTICE ''im_exchange_rate_fill_holes: rate=%'', v_rate;
	-- use the latest exchange rate for the next few years...
	select	count(*) into exists
	from im_exchange_rates 
	where day=row2.day and currency=p_currency;
	IF exists > 0 THEN
		update im_exchange_rates
		set	rate = v_rate,
			manual_p = ''f''
		where	day = row2.day
			and currency = p_currency;
	ELSE
	RAISE NOTICE ''im_exchange_rate_fill_holes: day=%, cur=%, rate=%, x=%'',row2.day, p_currency, v_rate, exists;
		insert into im_exchange_rates (
			day, rate, currency, manual_p
		) values (
			row2.day, v_rate, p_currency, ''f''		
		);
	END IF;

    END LOOP;	

    return 0;
end;' language 'plpgsql';


select	im_exchange_rate_fill_holes(currency)
from	(
	select	distinct currency
	from	im_exchange_rates
	) t
;





-- Deletes all entries AFTER a new entry, until an
-- entry is found with manual_t = 't'.
-- This function is useful after adding a new entriy
-- to delete all those entries that need to be updated.
create or replace function im_exchange_rate_invalidate_entries (date, char(3))
returns integer as '
DECLARE
	p_date			alias for $1;
	p_currency			alias for $2;

	v_next_entry_date		date;
	v_max			integer;
	v_start_date		date;
	v_rate			numeric;
	row				RECORD;
	row2			RECORD;
BEGIN
	v_start_date := to_date(''1999-01-01'', ''YYYY-MM-DD'');
	v_max := 365 * 16;

	select	min(day)
	into	v_next_entry_date
	from	im_exchange_rates
	where	day > p_date
		and manual_p = ''t''
		and currency = p_currency;

	IF v_next_entry_date is NULL THEN
	v_next_entry_date := v_start_date + v_max;
	END IF;

	-- Delete entries between current date and v_next_entry_date-1
	delete
	from	im_exchange_rates
	where	currency = p_currency
		and day < v_next_entry_date
		and day > p_date
		and manual_p = ''f'';

	return 0;
end;' language 'plpgsql';
-- select im_exchange_rate_invalidate_entries ('2005-07-02'::date, 'EUR');






delete from im_exchange_rates
where
	day >= to_date('2005-07-01', 'YYYY-MM-DD')
	and day <= to_date('2006-08-31', 'YYYY-MM-DD')
	and currency = 'EUR'
;


COPY im_exchange_rates (day, rate, currency, manual_p) FROM stdin;
2005-07-29	1.212746	EUR	t
2005-07-28	1.209924	EUR	t
2005-07-27	1.199170	EUR	t
2005-07-26	1.200169	EUR	t
2005-07-25	1.205267	EUR	t
2005-07-22	1.207002	EUR	t
2005-07-21	1.211232	EUR	t
2005-07-20	1.204522	EUR	t
2005-07-19	1.200103	EUR	t
2005-07-18	1.207509	EUR	t
2005-07-15	1.203102	EUR	t
2005-07-14	1.208753	EUR	t
2005-07-13	1.209082	EUR	t
2005-07-12	1.219659	EUR	t
2005-07-11	1.206390	EUR	t
2005-07-08	1.193322	EUR	t
2005-07-07	1.193316	EUR	t
2005-07-06	1.191530	EUR	t
2005-07-05	1.191307	EUR	t
2005-07-01	1.208672	EUR	t
2005-08-31	1.233268	EUR	t
2005-08-30	1.220422	EUR	t
2005-08-29	1.223923	EUR	t
2005-08-26	1.232104	EUR	t
2005-08-25	1.230583	EUR	t
2005-08-24	1.224062	EUR	t
2005-08-23	1.221237	EUR	t
2005-08-22	1.223159	EUR	t
2005-08-19	1.215282	EUR	t
2005-08-18	1.217454	EUR	t
2005-08-17	1.228987	EUR	t
2005-08-16	1.233890	EUR	t
2005-08-15	1.235932	EUR	t
2005-08-12	1.242407	EUR	t
2005-08-11	1.243167	EUR	t
2005-08-10	1.234691	EUR	t
2005-08-09	1.234559	EUR	t
2005-08-08	1.235912	EUR	t
2005-08-05	1.232400	EUR	t
2005-08-04	1.238123	EUR	t
2005-08-03	1.233432	EUR	t
2005-08-02	1.220556	EUR	t
2005-08-01	1.221817	EUR	t
2005-09-30	1.205955	EUR	t
2005-09-29	1.201805	EUR	t
2005-09-28	1.201542	EUR	t
2005-09-27	1.201005	EUR	t
2005-09-26	1.205442	EUR	t
2005-09-23	1.207346	EUR	t
2005-09-22	1.214887	EUR	t
2005-09-20	1.217583	EUR	t
2005-09-19	1.215247	EUR	t
2005-09-16	1.221159	EUR	t
2005-09-15	1.222745	EUR	t
2005-09-14	1.228077	EUR	t
2005-09-13	1.226177	EUR	t
2005-09-12	1.228642	EUR	t
2005-09-09	1.242250	EUR	t
2005-09-08	1.239870	EUR	t
2005-09-07	1.244543	EUR	t
2005-09-06	1.248134	EUR	t
2005-09-02	1.254194	EUR	t
2005-09-01	1.245539	EUR	t
2005-10-31	1.199325	EUR	t
2005-10-28	1.208829	EUR	t
2005-10-27	1.214679	EUR	t
2005-10-26	1.208096	EUR	t
2005-10-25	1.210226	EUR	t
2005-10-24	1.199548	EUR	t
2005-10-21	1.195780	EUR	t
2005-10-20	1.197361	EUR	t
2005-10-19	1.198443	EUR	t
2005-10-18	1.194167	EUR	t
2005-10-17	1.203771	EUR	t
2005-10-14	1.207155	EUR	t
2005-10-13	1.193561	EUR	t
2005-10-12	1.203663	EUR	t
2005-10-11	1.201475	EUR	t
2005-10-07	1.211368	EUR	t
2005-10-06	1.213277	EUR	t
2005-10-05	1.198146	EUR	t
2005-10-04	1.191635	EUR	t
2005-10-03	1.191388	EUR	t
2005-11-30	1.178894	EUR	t
2005-11-29	1.178371	EUR	t
2005-11-28	1.180246	EUR	t
2005-11-25	1.172268	EUR	t
2005-11-23	1.179656	EUR	t
2005-11-22	1.173489	EUR	t
2005-11-21	1.173281	EUR	t
2005-11-18	1.174183	EUR	t
2005-11-17	1.171320	EUR	t
2005-11-16	1.167234	EUR	t
2005-11-15	1.169354	EUR	t
2005-11-14	1.166481	EUR	t
2005-11-10	1.173958	EUR	t
2005-11-09	1.174709	EUR	t
2005-11-08	1.177191	EUR	t
2005-11-07	1.179244	EUR	t
2005-11-04	1.182554	EUR	t
2005-11-03	1.196665	EUR	t
2005-11-02	1.206604	EUR	t
2005-11-01	1.199654	EUR	t
2005-12-30	1.184008	EUR	t
2005-12-29	1.184549	EUR	t
2005-12-28	1.187502	EUR	t
2005-12-27	1.185206	EUR	t
2005-12-23	1.185521	EUR	t
2005-12-22	1.188049	EUR	t
2005-12-21	1.181544	EUR	t
2005-12-20	1.184705	EUR	t
2005-12-19	1.199612	EUR	t
2005-12-16	1.201162	EUR	t
2005-12-15	1.197041	EUR	t
2005-12-14	1.204092	EUR	t
2005-12-13	1.192472	EUR	t
2005-12-12	1.196814	EUR	t
2005-12-09	1.182568	EUR	t
2005-12-08	1.182834	EUR	t
2005-12-07	1.172109	EUR	t
2005-12-06	1.178270	EUR	t
2005-12-05	1.178630	EUR	t
2005-12-02	1.170496	EUR	t
2005-12-01	1.170138	EUR	t
2006-01-31	1.215588	EUR	t
2006-01-30	1.209051	EUR	t
2006-01-27	1.213028	EUR	t
2006-01-26	1.222751	EUR	t
2006-01-25	1.224890	EUR	t
2006-01-24	1.228531	EUR	t
2006-01-23	1.227595	EUR	t
2006-01-20	1.210104	EUR	t
2006-01-19	1.211659	EUR	t
2006-01-18	1.208202	EUR	t
2006-01-17	1.207422	EUR	t
2006-01-16	1.211786	EUR	t
2006-01-13	1.210399	EUR	t
2006-01-12	1.203361	EUR	t
2006-01-11	1.213471	EUR	t
2006-01-10	1.205976	EUR	t
2006-01-09	1.206393	EUR	t
2006-01-06	1.214639	EUR	t
2006-01-05	1.209958	EUR	t
2006-01-04	1.209221	EUR	t
2006-01-03	1.197853	EUR	t
2006-02-28	1.192384	EUR	t
2006-02-27	1.185929	EUR	t
2006-02-24	1.187719	EUR	t
2006-02-23	1.192165	EUR	t
2006-02-22	1.190391	EUR	t
2006-02-21	1.191155	EUR	t
2006-02-17	1.190337	EUR	t
2006-02-16	1.187602	EUR	t
2006-02-15	1.188406	EUR	t
2006-02-14	1.189389	EUR	t
2006-02-13	1.190360	EUR	t
2006-02-10	1.191753	EUR	t
2006-02-09	1.196307	EUR	t
2006-02-08	1.193323	EUR	t
2006-02-07	1.197324	EUR	t
2006-02-06	1.196852	EUR	t
2006-02-03	1.201761	EUR	t
2006-02-02	1.209952	EUR	t
2006-02-01	1.209010	EUR	t
2006-03-30	1.213131	EUR	t
2006-03-29	1.202861	EUR	t
2006-03-28	1.207579	EUR	t
2006-03-27	1.201366	EUR	t
2006-03-24	1.203281	EUR	t
2006-03-23	1.198051	EUR	t
2006-03-22	1.209329	EUR	t
2006-03-21	1.207782	EUR	t
2006-03-20	1.216665	EUR	t
2006-03-17	1.219543	EUR	t
2006-03-16	1.215049	EUR	t
2006-03-15	1.204565	EUR	t
2006-03-14	1.202300	EUR	t
2006-03-13	1.193847	EUR	t
2006-03-10	1.188306	EUR	t
2006-03-09	1.191931	EUR	t
2006-03-08	1.191320	EUR	t
2006-03-07	1.188768	EUR	t
2006-03-06	1.200240	EUR	t
2006-03-03	1.202708	EUR	t
2006-03-02	1.200433	EUR	t
2006-03-01	1.189403	EUR	t
2006-04-28	1.262362	EUR	t
2006-04-27	1.252348	EUR	t
2006-04-26	1.246612	EUR	t
2006-04-25	1.241018	EUR	t
2006-04-24	1.237584	EUR	t
2006-04-21	1.233911	EUR	t
2006-04-20	1.232435	EUR	t
2006-04-19	1.234446	EUR	t
2006-04-18	1.227242	EUR	t
2006-04-17	1.226771	EUR	t
2006-04-13	1.210594	EUR	t
2006-04-12	1.210592	EUR	t
2006-04-11	1.212364	EUR	t
2006-04-10	1.208892	EUR	t
2006-04-07	1.210705	EUR	t
2006-04-06	1.221368	EUR	t
2006-04-05	1.226958	EUR	t
2006-04-04	1.225803	EUR	t
2006-04-03	1.212309	EUR	t
2006-05-31	1.283221	EUR	t
2006-05-30	1.286660	EUR	t
2006-05-26	1.273822	EUR	t
2006-05-25	1.277051	EUR	t
2006-05-24	1.274566	EUR	t
2006-05-23	1.284299	EUR	t
2006-05-22	1.275235	EUR	t
2006-05-19	1.274777	EUR	t
2006-05-18	1.278709	EUR	t
2006-05-17	1.272213	EUR	t
2006-05-16	1.281614	EUR	t
2006-05-15	1.282321	EUR	t
2006-05-12	1.288768	EUR	t
2006-05-11	1.285193	EUR	t
2006-05-10	1.279761	EUR	t
2006-05-09	1.274663	EUR	t
2006-05-08	1.271763	EUR	t
2006-05-05	1.273159	EUR	t
2006-05-04	1.268348	EUR	t
2006-05-03	1.263758	EUR	t
2006-05-02	1.264250	EUR	t
2006-05-01	1.260603	EUR	t
2006-06-30	1.277585	EUR	t
2006-06-29	1.253097	EUR	t
2006-06-28	1.253034	EUR	t
2006-06-27	1.258726	EUR	t
2006-06-26	1.255215	EUR	t
2006-06-23	1.252038	EUR	t
2006-06-22	1.258090	EUR	t
2006-06-21	1.266442	EUR	t
2006-06-20	1.256681	EUR	t
2006-06-19	1.257650	EUR	t
2006-06-16	1.262193	EUR	t
2006-06-15	1.261258	EUR	t
2006-06-14	1.263202	EUR	t
2006-06-13	1.257254	EUR	t
2006-06-12	1.258609	EUR	t
2006-06-09	1.263560	EUR	t
2006-06-08	1.264707	EUR	t
2006-06-07	1.279990	EUR	t
2006-06-06	1.282655	EUR	t
2006-06-05	1.295253	EUR	t
2006-06-02	1.291111	EUR	t
2006-06-01	1.282084	EUR	t
2006-07-31	1.276246	EUR	t
2006-07-28	1.274673	EUR	t
2006-07-27	1.272997	EUR	t
2006-07-26	1.262724	EUR	t
2006-07-25	1.257504	EUR	t
2006-07-24	1.262995	EUR	t
2006-07-21	1.268247	EUR	t
2006-07-20	1.263670	EUR	t
2006-07-19	1.255822	EUR	t
2006-07-18	1.249916	EUR	t
2006-07-17	1.252700	EUR	t
2006-07-14	1.264005	EUR	t
2006-07-13	1.267193	EUR	t
2006-07-12	1.270464	EUR	t
2006-07-11	1.275276	EUR	t
2006-07-10	1.274972	EUR	t
2006-07-07	1.281851	EUR	t
2006-07-06	1.275536	EUR	t
2006-07-05	1.272491	EUR	t
2006-07-03	1.278928	EUR	t
2006-08-31	1.279180	EUR	t
2006-08-30	1.282189	EUR	t
2006-08-29	1.276543	EUR	t
2006-08-28	1.278241	EUR	t
2006-08-25	1.276639	EUR	t
2006-08-24	1.275955	EUR	t
2006-08-23	1.279370	EUR	t
2006-08-22	1.280274	EUR	t
2006-08-21	1.291226	EUR	t
2006-08-18	1.280990	EUR	t
2006-08-17	1.285897	EUR	t
2006-08-16	1.286202	EUR	t
2006-08-15	1.278527	EUR	t
2006-08-14	1.273316	EUR	t
2006-08-11	1.275444	EUR	t
2006-08-10	1.276394	EUR	t
2006-08-09	1.288708	EUR	t
2006-08-08	1.283854	EUR	t
2006-08-07	1.284916	EUR	t
2006-08-04	1.289384	EUR	t
2006-08-03	1.277754	EUR	t
2006-08-02	1.279722	EUR	t
2006-08-01	1.277704	EUR	t
\.



-- Update the entire currency table
delete from im_exchange_rates where manual_p = 'f';
select im_exchange_rate_fill_holes ();

