﻿-- /packages/intranet-events/sql/postgresql/intranet-events-create.sql
--
-- Copyright (C) 2003-2013 ]project-open[
-- @author	frank.bergmann@project-open.com


-----------------------------------------------------------
-- Create the object type

SELECT acs_object_type__create_type (
	'im_event',			-- object_type
	'Event',			-- pretty_name
	'Events',			-- pretty_plural
	'acs_object',			-- supertype
	'im_events',			-- table_name
	'event_id',			-- id_column
	'intranet-events',		-- package_name
	'f',				-- abstract_p
	null,				-- type_extension_table
	'im_event__name'		-- name_method
);

insert into acs_object_type_tables (object_type,table_name,id_column)
values ('im_event', 'im_events', 'event_id');


-- Setup status and type columns for im_events
update acs_object_types set 
	status_type_table = 'im_events',
	status_column = 'event_status_id', 
	type_column = 'event_type_id' 
where object_type = 'im_event';

-- Define how to link to Event pages from the Forum or the
-- Search Engine
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_event','view','/intranet-events/events/new?form_mode=display&event_id=');
insert into im_biz_object_urls (object_type, url_type, url) values (
'im_event','edit','/intranet-events/events/new?event_id=');



------------------------------------------------------
-- Events Table
--
create table im_events (
	event_id		integer
				constraint im_events_pk
				primary key
				constraint im_events_id_fk
				references im_user_absences,

	event_name		text
				constraint im_events_name_nn not null,

	event_nr		text
				constraint im_events_nr_nn not null,

	-- Status and type for orderly objects...
	event_type_id		integer
				constraint im_events_type_fk
				references im_categories
				constraint im_events_type_nn
				not null,
	event_status_id		integer
				constraint im_events_status_fk
				references im_categories
				constraint im_events_type_nn 
				not null,

	-- Other content fields
	event_material_id	integer
				constraint im_events_material_fk
				references im_materials,
	event_location_id	integer
				constraint im_events_location_fk
				references im_conf_items,

	event_start_date	timestamptz
				constraint im_events_start_const not null,
	event_end_date		timestamptz
				constraint im_events_end_const not null,

	event_description	text
);

-- Unique constraint to avoid that you can add two identical events
-- alter table im_events drop constraint owner_and_start_date_unique;
alter table im_events 
add constraint owner_and_start_date_unique unique (event_name, event_type_id, event_start_date, event_end_date);

-- Incices to speed up frequent queries
create index im_events_dates_idx on im_events(event_start_date, event_end_date);
create index im_events_type_idx on im_events(event_type_id);


-----------------------------------------------------------
-- Create, Drop and Name PlPg/SQL functions
--
-- These functions represent creator/destructor
-- functions for the OpenACS object system.

create or replace function im_event__name(integer)
returns varchar as '
DECLARE
	p_event_id		alias for $1;
	v_name			varchar;
BEGIN
	select	event_name into v_name
	from	im_events
	where	event_id = p_event_id;

	return v_name;
end;' language 'plpgsql';


create or replace function im_event__new (
	integer, varchar, timestamptz,
	integer, varchar, integer,
	varchar, varchar, timestamptz, timestamptz,
	integer, integer
) returns integer as '
DECLARE
	p_event_id		alias for $1;		-- event_id  default null
	p_object_type   	alias for $2;		-- object_type default ''im_event''
	p_creation_date 	alias for $3;		-- creation_date default now()
	p_creation_user 	alias for $4;		-- creation_user default null
	p_creation_ip   	alias for $5;		-- creation_ip default null
	p_context_id		alias for $6;		-- context_id default null

	p_event_name		alias for $7;		-- event_name
	p_event_nr		alias for $8;		-- event_nr
	p_event_start_date	alias for $9;
	p_event_end_date	alias for $10;
	p_event_status_id	alias for $11;
	p_event_type_id		alias for $12;

	v_event_id	integer;
BEGIN
	v_event_id := acs_object__new (
		p_event_id,		-- object_id
		p_object_type,		-- object_type
		p_creation_date,	-- creation_date
		p_creation_user,	-- creation_user
		p_creation_ip,		-- creation_ip
		p_context_id,		-- context_id
		''f''			-- security_inherit_p
	);

	insert into im_events (
		event_id, event_name, event_nr,
		event_start_date, event_end_date,
		event_status_id, event_type_id
	) values (
		v_event_id, p_event_name, p_event_nr,
		p_event_start_date, p_event_end_date,
		p_event_status_id, p_event_type_id
	);

	return v_event_id;
END;' language 'plpgsql';


create or replace function im_event__delete(integer)
returns integer as '
DECLARE
	p_event_id	alias for $1;
BEGIN
	-- Delete any data related to the object
	delete from im_events
	where	event_id = p_event_id;

	-- Finally delete the object iself
	PERFORM acs_object__delete(p_event_id);

	return 0;
end;' language 'plpgsql';




------------------------------------------------------
-- Events Permissions
--

-- add_events makes it possible to restrict the event registering to internal stuff
SELECT acs_privilege__create_privilege('add_events','Add Events','Add Events');
SELECT acs_privilege__add_child('admin', 'add_events');

-- view_events_all restricts possibility to see events of others
SELECT acs_privilege__create_privilege('view_events_all','View Events All','View Events All');
SELECT acs_privilege__add_child('admin', 'view_events_all');

-- edit_events_all restricts possibility to see events of others
SELECT acs_privilege__create_privilege('edit_events_all','Edit Events All','Edit Events All');
SELECT acs_privilege__add_child('admin', 'edit_events_all');


-- Set default permissions per group
SELECT im_priv_create('add_events', 'Employees');
SELECT im_priv_create('view_events_all', 'Employees');
SELECT im_priv_create('edit_events_all', 'Project Managers');
SELECT im_priv_create('edit_events_all', 'Senior Managers');
SELECT im_priv_create('edit_events_all', 'Accounting');


-----------------------------------------------------------
-- Type and Status
--
-- 82000-81999  Events (1000)
-- 82000-82099	Event Status (100)
-- 82100-82199	Event Type (100)
-- 82200-82999	reserved (800)


SELECT im_category_new (82000, 'Unplanned', 'Intranet Event Status');
SELECT im_category_new (82002, 'Planned', 'Intranet Event Status');
SELECT im_category_new (82004, 'Reserved', 'Intranet Event Status');
SELECT im_category_new (82006, 'Booked', 'Intranet Event Status');

SELECT im_category_new (82100, 'Default', 'Intranet Event Type');


-----------------------------------------------------------
-- Create views for shortcut
--

create or replace view im_event_status as
select	category_id as event_status_id, category as event_status
from	im_categories
where	category_type = 'Intranet Event Status'
	and (enabled_p is null or enabled_p = 't');

create or replace view im_event_types as
select	category_id as event_type_id, category as event_type
from	im_categories
where	category_type = 'Intranet Eventy Type'
	and (enabled_p is null or enabled_p = 't');



-- ------------------------------------------------------
-- Menus
-- ------------------------------------------------------


create or replace function inline_0 ()
returns integer as $body$
declare
	v_menu		integer;	
	v_parent_menu	integer;
	v_employees	integer;
	v_count		integer;
BEGIN
	select group_id into v_employees from groups where group_name = 'Employees';

	select count(*) into v_count from im_menus where label = 'events';
	IF v_count > 0 THEN return 1; END IF;

	select menu_id into v_parent_menu from im_menus where label = 'main';

	v_menu := im_menu__new (
		null,				-- p_menu_id
		'im_menu',			-- object_type
		now(),				-- creation_date
		null,				-- creation_user
		null,				-- creation_ip
		null,				-- context_id
		'intranet-events',		-- package_name
		'events',			-- label
		'Events',			-- name
		'/intranet-events/index?',	-- url
		78,				-- sort_order
		v_parent_menu,			-- parent_menu_id
		null				-- p_visible_tcl
	);

	PERFORM acs_permission__grant_permission(v_menu, v_employees, 'read');

	return 0;
end;$body$ language 'plpgsql';
select inline_0 ();
drop function inline_0 ();






-----------------------------------------------------------
-- EventListPage Main View
-----------------------------------------------------------

-- 970-979              intranet-events


delete from im_view_columns where view_id = 970;
delete from im_views where view_id = 970;

insert into im_views (view_id, view_name, visible_for, view_type_id)
values (970, 'event_list', 'view_events_all', 1400);


-- Add a "select all" checkbox to select all events in the list
insert into im_view_columns (
        column_id, view_id, sort_order,
	column_name,
	column_render_tcl,
        visible_for
) values (
        97099,970,0,
        '<input type=checkbox name=_dummy onclick="acs_ListCheckAll(''event'',this.checked)">',
        '$action_checkbox',
        ''
);


insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97010,970,10,'Name','"<a href=/intranet-events/new?form_mode=display&event_id=$event_id>$event_name</A>"');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97020,970,20,'Material','$material_name');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97030,970,30,'Type','$event_type');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97050,970,50,'Start','$event_start_date_formatted');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97060,970,60,'Duration','$event_duration_days');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97070,970,70,'Location','$event_location_name');

insert into im_view_columns (column_id, view_id, sort_order, column_name, column_render_tcl) values
(97090,970,90,'Status','$event_status');

