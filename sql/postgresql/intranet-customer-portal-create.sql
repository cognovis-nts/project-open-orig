-- /packages/intranet-customer-portal/sql/postgres/intranet-customer-portal-create.sql
--
-- Copyright (C) 2011-2012 ]project-open[ 
--
-- This program is free software. You can redistribute it
-- and/or modify it under the terms of the GNU General
-- Public License as published by the Free Software Foundation;
-- either version 2 of the License, or (at your option)
-- any later version. This program is distributed in the
-- hope that it will be useful, but WITHOUT ANY WARRANTY;
-- without even the implied warranty of MERCHANTABILITY or
-- FITNESS FOR A PARTICULAR PURPOSE.
-- See the GNU General Public License for more details.
--
-- @author klaus.hofeditz@project-open.com

-- Create table for inquiries 

create sequence im_inquiries_customer_portal_seq start 1;
create table im_inquiries_customer_portal (
        inquiry_id              integer
                                primary key,
        user_id 	        integer,
        first_names             varchar(50),
        last_names              varchar(80),
	title			varchar(80),
        email	                varchar(50),
        company_name            varchar(80),
        phone			varchar(20),
        security_token 		varchar(40),
	company_id		integer,
	status_id		integer,
	session_id		varchar(200),
	project_id		integer,
	inquiry_date		date,
	comment			varchar(1000)
);


create sequence im_inquiries_files_seq start 1;
create table im_inquiries_files (
        inquiry_files_id        integer
                                primary key,
        inquiry_id              integer,
        file_name               varchar(50)
                                not null,
	source_language 	varchar(4) 
                                not null,
	target_languages	varchar(200)
                                not null, 
	deliver_date		date,
	project_id		integer,
	file_path		varchar(200)
);

-- Create DynView for project list  

delete from im_view_columns where view_id = 960; 
delete from im_views where view_id = 960; 

insert into im_views (view_id, view_name, visible_for, view_type_id)
values (960, 'project-list-customer-portal', 'view_projects', 1415);

CREATE OR REPLACE FUNCTION inline_0 ()
RETURNS INTEGER AS '
declare
        v_count                 integer;
begin
	select column_id+1 into v_count from im_view_columns order by column_id desc limit 1;

	insert into im_view_columns (column_id, view_id, group_id, column_name, column_render_tcl,
	extra_select, extra_where, sort_order, visible_for, ajax_configuration) values (v_count,960,NULL,''[lang::message::lookup "" intranet-core.Project "Project"]'',
	''project_name'','''','''',1,'''', ''def '');

        return 1;

end;' LANGUAGE 'plpgsql';
SELECT inline_0 ();
DROP FUNCTION inline_0 ();

SELECT  im_component_plugin__new (
        null,       	             -- plugin_id
        'acs_object',                -- object_type
        now(),                       -- creation_date
        null,                        -- creation_user
        null,                        -- creation_ip
        null,                           -- context_id
        'Requests for Quote',		-- plugin_name
        'intranet-customer-portal',     -- package_name
        'top',	                        -- location
        '/intranet/index',              -- page_url
        null,                           -- view_name
        1,                              -- sort_order
        'im_list_rfqs_component'  	-- component_tcl
);


-- create new Category to 
SELECT im_category_new ('380', 'Quote accepted', 'Intranet Project Status');



-- create function that assigns PM to project

create or replace function im_customer_portal_assign_pm(int4,text, text) returns int4 as '
        declare
                p_case_id               alias for $1;
                p_transition_key        alias for $2;
                p_custom_arg            alias for $3;
        
        	v_task_id		integer;	v_case_id		integer;
        	v_creation_ip		varchar; 	v_creation_user		integer;
        	v_object_id		integer;	v_object_type		varchar;
        	v_journal_id		integer;
        	v_transition_key	varchar;	v_workflow_key		varchar;
               	v_group_id		integer;	v_group_name		varchar;
		v_task_owner		integer;
        begin
        	-- Select out some frequently used variables of the environment
        	select	c.object_id, c.workflow_key, task_id, c.case_id, co.object_type, co.creation_ip
        	into	v_object_id, v_workflow_key, v_task_id, v_case_id, v_object_type, v_creation_ip
        	from	wf_tasks t, wf_cases c, acs_objects co
        	where	c.case_id = p_case_id
        		and c.case_id = co.object_id
        		and t.case_id = c.case_id
        		and t.workflow_key = c.workflow_key
        		and t.transition_key = p_transition_key;

		-- set PM to 
		select 
			creation_user 
		into 
			v_task_owner 
		from 
			acs_objects 
		where 
			object_id = (select journal_id from journal_entries where object_id=v_case_id and action_pretty = ''Create quote finish'') and
			object_type = ''journal_entry'';

		update im_projects set project_lead_id = v_task_owner where project_id = v_object_id;    

                -- IF v_group_id is not null THEN
                --      v_journal_id := journal_entry__new(
                --          null, v_case_id,
                --          v_transition_key || '' assign_to_user '' || v_group_name,
                --          v_transition_key || '' assign_to_user '' || v_group_name,
                --          now(), v_creation_user, v_creation_ip,
                --          ''Setting Project Manager'' || v_task_owner
                --      );
                -- END IF;
                return 0;
	end;
' language 'plpgsql';


create or replace function inline_1 ()
returns integer as '
declare
        v_menu                  integer;
        v_parent_menu           integer;
        v_customers             integer;
begin
        select group_id into v_customers from groups where group_name = ''Customers'';

        select menu_id into v_parent_menu
        from im_menus where label = ''main'';

        v_menu := im_menu__new (
                null,                                   -- p_menu_id
                ''im_menu'',                            -- object_type
                now(),                                  -- creation_date
                null,                                   -- creation_user
                null,                                   -- creation_ip
                null,                                   -- context_id
                ''intranet-customer-portal'',  		-- package_name
                ''intranet_customer_portal'', 		-- label
                ''Request for Quote'',      		-- name
                ''/intranet-customer-portal/upload-files'',   -- url
                900,                                    -- sort_order
                v_parent_menu,                          -- parent_menu_id
                null                                    -- p_visible_tcl
        );

        PERFORM acs_permission__grant_permission(v_menu, v_customers, ''read'');
        return 0;
end;' language 'plpgsql';
select inline_1 ();
drop function inline_1();

-- creating wf notification 

create function inline_0()
returns integer as '
declare
        impl_id integer;
        v_notif_type_id  integer;
begin
        -- the notification type impl
        impl_id := acs_sc_impl__new (
                      ''NotificationType'',
                      ''inquiry_notif_type'',
                      ''inquiries''
        );

        PERFORM acs_sc_impl_alias__new (
                    ''NotificationType'',
                    ''inquiry_notif_type'',
                    ''GetURL'',
                    ''im_inquiry::notification::get_url'',
                    ''TCL''
        );

        PERFORM acs_sc_impl_alias__new (
                    ''NotificationType'',
                    ''inquiry_notif_type'',
                    ''ProcessReply'',
                    ''im_inquiry::notification::process_reply'',
                    ''TCL''
        );

        PERFORM acs_sc_binding__new (
                    ''NotificationType'',
                    ''inquiry_notif_type''
        );

        v_notif_type_id:= notification_type__new (
                NULL,
                impl_id,
                ''inquiry_notif'',
                ''Inquiry Notifications'',
                ''Notifications of status of inquiry'',
                now(),
                NULL,
                NULL,
        NULL
        );

        -- enable the various intervals and delivery methods
        insert into notification_types_intervals (type_id, interval_id)
        select v_notif_type_id, interval_id
        from notification_intervals where name in (''instant'',''hourly'',''daily'');

        insert into notification_types_del_methods (type_id, delivery_method_id)
        select v_notif_type_id, delivery_method_id
        from notification_delivery_methods where short_name in (''email'');

        return (0);
end;' language 'plpgsql';
select inline_0();
drop function inline_0();


--PERFORM workflow_case__notify_assignee (v_task_id, v_creation_user, null, null, ''inquiry_notif'');


create or replace function im_customer_portal_notify_customer(int4,int4,varchar,varchar,varchar) returns int4 as '
       declare
       	notify__task_id                alias for $1;
       	notify__user_id                alias for $2;
       	notify__callback               alias for $3;
       	notify__custom_arg             alias for $4;
       	notify__notification_type      alias for $5;
       
       	v_str					varchar;
       	v_custom_arg				varchar;
       	v_object_name                           text; 
       	v_transition_key                        wf_transitions.transition_key%TYPE;
       	v_transition_name                       wf_transitions.transition_name%TYPE;
       	v_party_from                            parties.party_id%TYPE;
       	v_party_to                              parties.party_id%TYPE;
       	v_subject                               text; 
       	v_body                                  text; 
       	v_request_id                            integer; 
       	v_workflow_url			  	text;
       	v_acs_lang_package_id			integer;
       
       	v_notification_type			varchar;
       	v_notification_type_id		  	integer;
       	v_workflow_package_id			integer;
       	v_notification_n_seconds		integer;
       	v_locale				text;
       	v_count				  	integer;

       begin
       	RAISE NOTICE ''KHD: Notify_assignee_project_approval: enter'';
       		-- Default notification type
       		v_notification_type := notify__notification_type;
       		IF v_notification_type is null THEN
       		  v_notification_type := ''inquiry_notif'';
       		END IF;
       
       	select acs_object__name(c.object_id), tr.transition_key, tr.transition_name
       	into   v_object_name, v_transition_key, v_transition_name
       	  from wf_tasks ta, wf_transitions tr, wf_cases c
       	 where ta.task_id = notify__task_id
       	   and c.case_id = ta.case_id
       	   and tr.workflow_key = c.workflow_key
       	   and tr.transition_key = ta.transition_key;
       
       	v_party_from := -1;
       
       	-- Get locale of user 
       	select	language_preference into v_locale
       	from	user_preferences
	where   user_id = notify__user_id; 

       	-- make sure there are no null values - replaces(...,null) returns null...
       	IF v_workflow_url is NULL THEN v_workflow_url := ''undefined''; END IF;
       
       	-- ------------------------------------------------------------
       	-- Try with specific translation first
       	v_subject := ''Notification_Subject_Notify_Customer_Quote_Created'';
       	v_subject := acs_lang_lookup_message(v_locale, ''intranet-customer-portal'', v_subject);
       
       	-- Fallback to generic (no transition key) translation
       	IF substring(v_subject from 1 for 7) = ''MISSING'' THEN
       		v_subject := ''A quote has been created'';
       	END IF;
       	
       	-- Replace variables
       	-- v_subject := replace(v_subject, ''%object_name%'', v_object_name);
       	-- v_subject := replace(v_subject, ''%transition_name%'', v_transition_name);
       
       	-- ------------------------------------------------------------
       	-- Try with specific translation first
       	v_body := ''Notification_Body_Notify_Customer_QuoteCreated'';
       	v_body := acs_lang_lookup_message(v_locale, ''intranet-customer-portal'', v_body);
       
       	-- Fallback to generic (no transition key) translation
       	IF substring(v_body from 1 for 7) = ''MISSING'' THEN
       		v_body := ''Please check your RFQ box for a new quote'';
       	END IF;
       
       	-- Replace variables
       	-- v_body := replace(v_body, ''%object_name%'', v_object_name);
       	-- v_body := replace(v_body, ''%transition_name%'', v_transition_name);
       	-- v_body := replace(v_body, ''%workflow_url%'', v_workflow_url);
       
       	RAISE NOTICE ''KHD: Notify_assignee_project_approval: Subject=%, Body=%'', v_subject, v_body;
       
       	v_custom_arg := notify__custom_arg;
       	IF v_custom_arg is null THEN v_custom_arg := ''null''; END IF;
       
       	IF length(notify__callback) > 0 and notify__callback is not null THEN
       
       		v_str :=  ''select '' || notify__callback || '' ('' ||
       		      notify__task_id || '','' ||
       		      quote_literal(v_custom_arg) || '','' ||
       		      notify__user_id || '','' ||
       		      v_party_from || '','' ||
       		      quote_literal(v_subject) || '','' ||
       		      quote_literal(v_body) || '')'';
       
       		execute v_str;
       	else
       		v_request_id := acs_mail_nt__post_request (
       ~/packages/intranet-customer-portal/		v_party_from,                 -- party_from
       		notify__user_id,     	      -- party_to
       		''f'',                        -- expand_group
       		v_subject,                    -- subject
       		v_body,                       -- message
       		0                             -- max_retries
       		);
       	end if;
       
       	  return 0; 
end;' language 'plpgsql';
	   

