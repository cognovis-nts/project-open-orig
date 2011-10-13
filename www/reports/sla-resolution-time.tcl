# /packages/intranet-sencha-ticket-tracker/report-tickets.tcl
#
# Copyright (c) 2011 ]project-open[
#
# All rights reserved. 
# Please see http://www.project-open.com/ for licensing.

ad_page_contract {
    Show Resolution time per ticket
} {
    { start_date "" }
    { end_date "" }
    { level_of_detail:integer 3 }
    { customer_id:integer 0 }
    { output_format "html" }
}


# ------------------------------------------------------------
# Security
#
set menu_label "reporting-helpdesk-sla-resolution-time"
set current_user_id [ad_maybe_redirect_for_registration]
set read_p [db_string report_perms "
	select	im_object_permission_p(m.menu_id, :current_user_id, 'read')
	from	im_menus m
	where	m.label = :menu_label
" -default 'f']

# For testing - set manually
set read_p "t"

if {![string equal "t" $read_p]} {
    set message "You don't have the necessary permissions to view this page"
    ad_return_complaint 1 "<li>$message"
    ad_script_abort
}

set locale [lang::user::locale -user_id $current_user_id]

set form_mode display


# ------------------------------------------------------------
# Check Parameters



# ------------------------------------------------------------
# Defaults

set days_in_past 7
db_1row todays_date "
select
	to_char(sysdate::date - :days_in_past::integer, 'YYYY') as todays_year,
	to_char(sysdate::date - :days_in_past::integer, 'MM') as todays_month,
	to_char(sysdate::date - :days_in_past::integer, 'DD') as todays_day
from dual
"

if {"" == $start_date} {
    set start_date "$todays_year-$todays_month-01"
}

db_1row end_date "
select
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'YYYY') as end_year,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'MM') as end_month,
	to_char(to_date(:start_date, 'YYYY-MM-DD') + 31::integer, 'DD') as end_day
from dual
"

if {"" == $end_date} {
    set end_date "$end_year-$end_month-01"
}


if {![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $start_date]} {
    ad_return_complaint 1 "Start Date doesn't have the right format.<br>
    Current value: '$start_date'<br>
    Expected format: 'YYYY-MM-DD'"
    ad_script_abort
}

if {![regexp {[0-9][0-9][0-9][0-9]\-[0-9][0-9]\-[0-9][0-9]} $end_date]} {
    ad_return_complaint 1 "End Date doesn't have the right format.<br>
    Current value: '$end_date'<br>
    Expected format: 'YYYY-MM-DD'"
    ad_script_abort
}

# Maxlevel is 3. 
if {$level_of_detail > 3} { set level_of_detail 3 }



# ------------------------------------------------------------
# Page Title, Bread Crums and Help
#

set page_title "Ticket Resolution Time"
set context_bar [im_context_bar $page_title]
set help_text "
	<strong>$page_title</strong><br>
"


# ------------------------------------------------------------
# Default Values and Constants

set rowclass(0) "roweven"
set rowclass(1) "rowodd"
set currency_format "999,999,999.09"
set date_format "YYYY-MM-DD"
set date_time_format "YYYY-MM-DD HH24:MI"
set company_url "/intranet/companies/view"
set project_url "/intranet/projects/view"
set ticket_url "/intranet-helpdesk/new"
set invoice_url "/intranet-invoices/view"
set user_url "/intranet/users/view"
set this_url [export_vars -base "/intranet-sla-management/reports/sla-resolution-time" {start_date end_date} ]

# Level of Details
set levels {2 "Customers" 3 "Customers+Projects"} 


# ------------------------------------------------------------
# Report Definition
#
# Reports are defined in a "declarative" style. The definition
# consists of a number of fields for header, lines and footer.

# Global Header Line
set header0 [list \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Customer "Customer"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_SLA "SLA"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Customer_Contact "Customer<br>Contact"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Name "Ticket<br>Name"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Type "Ticket<br>Type"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Status "Ticket<br>Status"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Priority "Ticket<br>Prio"]  \
		 [lang::message::lookup "" intranet-sla-management.Creation_User "Creation<br>User"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Last_Queue "Last<br>Queue"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Last_Assignee "Last<br>Assignee"]  \
		 [lang::message::lookup "" intranet-sla-management.Creation_Date "Creation<br>Date"]  \
		 [lang::message::lookup "" intranet-sla-management.Reaction_Date "Reaction<br>Date"]  \
		 [lang::message::lookup "" intranet-sla-management.Confirmation_Date "Confirmation<br>Date"]  \
		 [lang::message::lookup "" intranet-sla-management.Done_Date "Done<br>Date"]  \
		 [lang::message::lookup "" intranet-sla-management.Sign_Off_Date "Sign-Off<br>Date"]  \
		 [lang::message::lookup "" intranet-sla-management.Ticket_Resolution_Time "Resolution<br>Time"]  \
		]

set customer_header {
	"\#colspan=99 <b><a href=[export_vars -base $company_url {{company_id $company_id}}]>$company_name</a></b>"
}

set sla_header {
	""
	"\#colspan=98 <b><a href=[export_vars -base $project_url {{project_id $sla_id}}]>$sla_name</a></b>"
}

set ticket_header {
	"$company_path"
	"$sla_nr"
	"<a href=[export_vars -base $user_url {{user_id $ticket_customer_contact_id}}]>$ticket_customer_contact_name</a>"
	"<a href=[export_vars -base $ticket_url {{ticket_id $ticket_id} form_mode}]>$project_nr - $project_name_pretty</a>"
	$ticket_type
	$ticket_status
	$ticket_prio
	"<a href=[export_vars -base $user_url {{user_id $creation_user}}]>$creation_user_name</a>"
	$ticket_queue
	$ticket_assignee
	$creation_date_pretty
	$ticket_creation_date_pretty
	$ticket_reaction_date_pretty
	$ticket_confirmation_date_pretty
	$ticket_done_date_pretty
	"\#align=right $ticket_resolution_time"
}



# ------------------------------------------------------------
# Add all Project and Company DynFields to list

set dynfield_sql "
	select  aa.attribute_name,
		aa.pretty_name,
		w.widget as tcl_widget,
		w.widget_name as dynfield_widget,
		w.deref_plpgsql_function
	from	im_dynfield_attributes a,
		im_dynfield_widgets w,
		acs_attributes aa
	where	a.widget_name = w.widget_name and
		a.acs_attribute_id = aa.attribute_id and
		aa.object_type = 'im_ticket' and
		aa.attribute_name not like 'default%' and
		(also_hard_coded_p is null OR also_hard_coded_p = 'f') and
		aa.attribute_name not in (
			-- Fields already hard coded in the report
			'ticket_customer_contact_id'
		)
	order by aa.object_type, aa.sort_order
"

set derefs [list]
db_foreach dynfield_attributes $dynfield_sql {

    # Avoid DynField configuration errors.
    if {![im_column_exists "im_tickets" $attribute_name]} { continue }

    # Calculate the "dereference" DynField value
    set deref "substring(${deref_plpgsql_function}($attribute_name)::text for 100) as ${attribute_name}_deref"
    if {"" == $deref} { set deref "substring($attribute_name::text for 100) as ${attribute_name}_deref" }
    regsub -all {[^a-zA-Z0-9\ \-\.]} $pretty_name {} pretty_name
    lappend header0 $pretty_name
    lappend derefs $deref
    set var_name "\$${attribute_name}_deref"
    lappend ticket_header $var_name
}


# ----------------------------------------------------------------
# Add the ticket resolution time per group
# ----------------------------------------------------------------

# Calculate a list of groups for storing resolution times per group
set group_sql "
	select	g.*
	from	groups g
	where	g.group_id > 0
	order by g.group_id
"
set cnt 0
db_foreach groups $group_sql {
    lappend header0 $group_name
    set var_name "group${group_id}_restime"
    lappend ticket_header "\$$var_name"
    set deref "t.ticket_resolution_time_per_queue\[$cnt\] as $var_name"
    lappend derefs $deref
    incr cnt
}



# ----------------------------------------------------------------
# The entries in this list include <a HREF=...> tags
# in order to link the entries to the rest of the system (New!)
# ----------------------------------------------------------------
#
set report_def [list \
		    group_by company_id \
		    header $customer_header \
		    content [list \
				 group_by sla_id \
				 header $sla_header \
				 content [list \
					      group_by ticket_id \
					      header $ticket_header \
					      content {} \
					      footer {} \
					     ] \
				 footer {} \
				 ]\
		    ]


# Global Footer Line
set footer0 {}



# ------------------------------------------------------------
# Report SQL - This SQL statement defines the raw data 
# that are to be shown.


set report_sql "
	select
		o.*,
		im_name_from_user_id(o.creation_user) as creation_user_name,
		to_char(o.creation_date, :date_time_format) as creation_date_pretty,
		t.*,
		im_category_from_id(t.ticket_status_id) as ticket_status,
		im_category_from_id(t.ticket_type_id) as ticket_type,
		im_category_from_id(t.ticket_prio_id) as ticket_prio,
		im_name_from_user_id(t.ticket_assignee_id) as ticket_assignee,
		to_char(t.ticket_creation_date, :date_time_format) as ticket_creation_date_pretty,
		to_char(t.ticket_reaction_date, :date_time_format) as ticket_reaction_date_pretty,
		to_char(t.ticket_done_date, :date_time_format) as ticket_done_date_pretty,
		to_char(t.ticket_reaction_date, :date_time_format) as ticket_reaction_date_pretty,
		to_char(t.ticket_confirmation_date, :date_time_format) as ticket_confirmation_date_pretty,
		to_char(t.ticket_signoff_date, :date_time_format) as ticket_signoff_date_pretty,
		im_name_from_user_id(t.ticket_customer_contact_id) as ticket_customer_contact_name,
		p.*,
		substring(p.project_name for 30) as project_name_pretty,
		g.*,
		g.group_name as ticket_queue,
		cust.*,
		im_category_from_id(cust.company_type_id) as company_type,
		sla_project.project_id as sla_id,
		sla_project.project_nr as sla_nr,
		sla_project.project_name as sla_name,
		[join $derefs "\t,\n"]
	from
		acs_objects o,
		im_projects p
		LEFT OUTER JOIN im_companies cust ON (p.company_id = cust.company_id)
		LEFT OUTER JOIN im_offices office ON (office.office_id = cust.main_office_id)
		LEFT OUTER JOIN im_projects sla_project ON (p.parent_id = sla_project.project_id),
		im_tickets t
		LEFT OUTER JOIN persons p_contact ON (t.ticket_customer_contact_id = p_contact.person_id)
		LEFT OUTER JOIN parties pa_contact ON (t.ticket_customer_contact_id = pa_contact.party_id)
		LEFT OUTER JOIN groups g ON (t.ticket_queue_id = g.group_id)
	where
		t.ticket_id = o.object_id and
		t.ticket_id = p.project_id and
		t.ticket_creation_date >= :start_date and
		t.ticket_creation_date <= :end_date
	order by
		lower(cust.company_name),
		lower(sla_project.project_name),
		lower(im_name_from_user_id(o.creation_user)),
		lower(p.project_nr)
"

# --------------------------------------------------------
# Write out HTTP header, considering CSV/MS-Excel formatting
im_report_write_http_headers -output_format $output_format

switch $output_format {
    html {
	ns_write "
	[im_header]
	[im_navbar]
	<table cellspacing=0 cellpadding=0 border=0>
	<tr valign=top>
	  <td width='30%'>
		<!-- 'Filters' - Show the Report parameters -->
		<form>
		<table cellspacing=2>
		<tr class=rowtitle>
		  <td class=rowtitle colspan=2 align=center>Filters</td>
		</tr>
		<tr>
		  <td><nobr>Start Date:</nobr></td>
		  <td><input type=text name=start_date value='$start_date'></td>
		</tr>
		<tr>
		  <td>End Date:</td>
		  <td><input type=text name=end_date value='$end_date'></td>
		</tr>
		<tr>
		  <td class=form-label>Format</td>
		  <td class=form-widget>
		    [im_report_output_format_select output_format "" $output_format]
		  </td>
		</tr>
		<tr>
		  <td</td>
		  <td><input type=submit value='Submit'></td>
		</tr>
		</table>
		</form>
	  </td>
	  <td align=center>
		<table cellspacing=2 width='90%'>
		<tr>
		  <td>$help_text</td>
		</tr>
		</table>
	  </td>
	</tr>
	</table>
	
	<!-- Here starts the main report table -->
	<table border=0 cellspacing=1 cellpadding=1>
    "
    }
    printer {
	ns_write "
	<link rel=StyleSheet type='text/css' href='/intranet-reporting/printer-friendly.css' media=all>
	<div class=\"fullwidth-list\">
	<table border=0 cellspacing=1 cellpadding=1 rules=all>
	<colgroup>
		<col id=datecol>
		<col id=hourcol>
		<col id=datecol>
		<col id=datecol>
		<col id=hourcol>
		<col id=hourcol>
		<col id=hourcol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
		<col id=datecol>
	</colgroup>
	"
    }

}

set footer_array_list [list]
set last_value_list [list]

im_report_render_row \
    -output_format $output_format \
    -row $header0 \
    -row_class "rowtitle" \
    -cell_class "rowtitle"

set counter 0
set class ""
db_foreach sql $report_sql {

	# Select either "roweven" or "rowodd" from
	# a "hash", depending on the value of "counter".
	# You need explicite evaluation ("expre") in TCL
	# to calculate arithmetic expressions. 
	set class $rowclass([expr $counter % 2])

	im_report_display_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -footer_array_list $footer_array_list \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class

	if {"" != $ticket_type} {
	    set category_key "intranet-core.[lang::util::suggest_key $ticket_type]"
	    set ticket_type [lang::message::lookup $locale $category_key $ticket_type]
	}

	if {"" != $company_type} {
	    set category_key "intranet-core.[lang::util::suggest_key $company_type]"
	    set company_type [lang::message::lookup $locale $category_key $company_type]
	}

	if {"Employees" == $ticket_queue} { set ticket_queue "" }

	set last_value_list [im_report_render_header \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	set footer_array_list [im_report_render_footer \
	    -output_format $output_format \
	    -group_def $report_def \
	    -last_value_array_list $last_value_list \
	    -level_of_detail $level_of_detail \
	    -row_class $class \
	    -cell_class $class
	]

	incr counter
}

im_report_display_footer \
    -output_format $output_format \
    -group_def $report_def \
    -footer_array_list $footer_array_list \
    -last_value_array_list $last_value_list \
    -level_of_detail $level_of_detail \
    -display_all_footers_p 1 \
    -row_class $class \
    -cell_class $class

im_report_render_row \
    -output_format $output_format \
    -row $footer0 \
    -row_class $class \
    -cell_class $class \
    -upvar_level 1

ns_log Notice "report-tickets: $output_format"

# Write out the HTMl to close the main report table
# and write out the page footer.
#
switch $output_format {
    html { ns_write "</table>[im_footer]\n" }
    printer { ns_write "</table>\n</div>\n" }
    cvs { }
}

