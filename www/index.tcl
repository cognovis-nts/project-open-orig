# /www/intranet/forum/index.tcl

# ---------------------------------------------------------------
# Page Contract
# ---------------------------------------------------------------

ad_page_contract { 
    List all projects with dimensional sliders.

    @param order_by project display order 
    @param include_subprojects_p whether to include sub projects
    @param mine_p show my projects or all projects
    @param status_id criteria for project status
    @param type_id criteria for project_type_id
    @param letter criteria for im_first_letter_default_to_a(ug.group_name)
    @param start_idx the starting index for query
    @param how_many how many rows to return

    @author mbryzek@arsdigita.com
    @cvs-id index.tcl,v 3.24.2.9 2000/09/22 01:38:44 kevin Exp
} {
    { forum_order_by "Project" }
    { forum_view_name "forum_list_forum" }
    { forum_mine_p "t" }
    { forum_topic_type_id:integer 0 }
    { forum_status_id 0 }
    { forum_group_id:integer 0 }
    { forum_start_idx:integer "1" }
    { forum_how_many 0 }
    { forum_folder 0 }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

# User id already verified by filters
set user_id [ad_get_user_id]
set current_user_id $user_id
set view_types [list "t" "Mine" "f" "All"]
set page_title "Forum"
set context_bar [ad_context_bar $page_title]
set page_focus "im_header_form.keywords"
set user_admin_p [im_is_user_site_wide_or_intranet_admin $current_user_id]

set return_url [im_url_with_query]
set current_url [ns_conn url]

# Unprivileged users (clients & freelancers) can only see their
# own projects and no subprojects.
if {![im_permission $current_user_id "view_forum_topics_of_others"]} {
    set forum_mine_p "t"
}

if { [empty_string_p $forum_how_many] || $forum_how_many < 1 } {
    set forum_how_many [ad_parameter NumberResultsPerPage intranet 100]
} 

set end_idx [expr $forum_start_idx + $forum_how_many - 1]

if {[string equal $forum_view_name "forum_list_tasks"]} {
    set forum_view_name "forum_list_forum"
    # Preselect "Tasks & Incidents"
    set forum_topic_type_id 1
}

# ---------------------------------------------------------------
# Define Filter Categories
# ---------------------------------------------------------------

# Forum Topic Types come from a category list, but we need
# some manual extensions...
#
set forum_topic_types [im_memoize_list select_forum_topic_types \
			   "select * from im_forum_topic_types order by topic_type_id"]
set forum_topic_types [linsert $forum_topic_types 0 1 "Tasks & Incidents"]
set forum_topic_types [linsert $forum_topic_types 0 0 All]
ns_log Notice "/intranet/forum/index: forum_topic_types=$forum_topic_types"

# project_types will be a list of pairs of (project_type_id, project_type)
set project_types [im_memoize_list select_project_types \
        "select project_type_id, project_type
         from im_project_types
        order by lower(project_type)"]
set project_types [linsert $project_types 0 0 All]

# ---------------------------------------------------------------
# Format the Filter
# ---------------------------------------------------------------

# Note that we use a nested table because im_slider might
# return a table with a form in it (if there are too many
# options
set filter_html "
<table border=0 cellpadding=0 cellspacing=0>
<tr>
  <td colspan='2' class=rowtitle align=center>Filter Topics</td>
</tr>\n"

if {[im_permission $current_user_id "view_forum_topics_of_others"]} {
    append filter_html "
<tr>
  <td valign=top>View:</td>
  <td valign=top>[im_select forum_mine_p $view_types ""]</td>
</tr>"
}
if {[im_permission $current_user_id "view_forum_topics_of_others"]} {
    append filter_html "
<!--
<tr>
  <td valign=top>Project Status:</td>
  <td valign=top>[im_select status_id $forum_topic_types ""]</td>
</tr>
-->
"
}

append filter_html "
<tr>
  <td valign=top>Topic Type:</td>
  <td valign=top>
    [im_select forum_topic_type_id $forum_topic_types $forum_topic_type_id]
          <input type=submit value=Go name=submit>
  </td>
</tr>\n"

append filter_html "</table>"


# ---------------------------------------------------------------
# Prepare parameters for the Forum Component
# ---------------------------------------------------------------

# Variables of this page to pass through im_forum_component to maintain the
# current selection and view of the current project

set export_var_list [list forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name forum_mine_p]

set restrict_to_asignee_id 0
set restrict_to_new_topics 0

set forum_content [im_forum_component $current_user_id $forum_group_id $current_url $return_url $export_var_list $forum_view_name $forum_order_by $forum_mine_p $forum_topic_type_id $forum_status_id $restrict_to_asignee_id $forum_how_many $forum_start_idx $restrict_to_new_topics $forum_folder]

#ad_proc im_forum_component {user_id group_id current_page_url return_url export_var_list {view_name "forum_list_short"} {forum_order_by "priority"} {restrict_to_mine_p f} {restrict_to_topic_type_id 0} {restrict_to_topic_status_id 0} {restrict_to_asignee_id 0} {max_entries_per_page 0} {start_idx 1} {restrict_to_new_topics 0} {restrict_to_folder 0} }


# ---------------------------------------------------------------
# Join all parts together
# ---------------------------------------------------------------

set page_body "
  <form method=get action='/index'>
  [export_form_vars forum_group_id forum_start_idx forum_order_by forum_how_many forum_view_name]
    $filter_html
  </form>

[im_forum_navbar "/intranet/projects/index" [list forum_group_id forum_start_idx forum_order_byforum_how_many forum_mine_p forum_view_name]]

$forum_content

"

db_release_unused_handles


doc_return  200 text/html [im_return_template]
