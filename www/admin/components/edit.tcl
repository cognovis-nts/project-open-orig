# /www/admin/categories/one.tcl
#
# Copyright (C) 2004 various parties
# The code is based on ArsDigita ACS 3.4
#
# This program is free software. You can redistribute it
# and/or modify it under the terms of the GNU General
# Public License as published by the Free Software Foundation;
# either version 2 of the License, or (at your option)
# any later version. This program is distributed in the
# hope that it will be useful, but WITHOUT ANY WARRANTY;
# without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.
# See the GNU General Public License for more details.

ad_page_contract {
    Displays and edits the location of one component plugins.
    @param plugin_id Which component is being worked on

    @author unknown@arsdigita.com
    @author guillermo.belcic@project-open.com
    @author frank.bergmann@project-open.com
    @author mai-bee@gmx.net
} {
    plugin_id:naturalnum
}

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "<li>You need to be a system administrator to see this page">
    return
}


# ---------------------------------------------------------------
# Format Component Data 
# ---------------------------------------------------------------

set page_title "Component Edit"
set context_bar [ad_context_bar $page_title]

if [catch {db_1row category_properties "
	select
		c.*
	from
		im_component_plugins c
	where
		c.plugin_id = :plugin_id
" } errmsg] {
    ad_return_complaint 1 "<li>Internal Error<br>
        Component \#$plugin_id does not exist (anymore)"
    return
}

set left_selected ""
set right_selected ""
set bottom_selected ""
set none_selected ""
set files_selected ""

switch $location {
    "left" { set left_selected " selected" }
    "right" { set right_selected " selected" }
    "bottom" { set bottom_selected " selected" }
    "none" { set none_selected " selected" }
    "files" { set none_selected " selected" }
}

# TODO add correct URL
set return_url ""

set page_body "
<form action=\"component-update.tcl\" method=GET>
[export_form_vars plugin_id return_url]

<TABLE border=0>
  <TBODY>
  <TR>
    <TD class=rowtitle align=middle colSpan=2>Component</TD></TR>
  <TR class=rowodd>
    <TD>Package Name</TD>
    <TD>$package_name</TD></TR>
  <TR class=roweven>
    <TD>Name</TD>
    <TD>$plugin_name</TD></TR>
  <TR class=rowodd>
    <TD>Location</TD>
    <TD><select name=location size=1>
        <option $left_selected>left</option>
        <option $right_selected>right</option>
        <option $bottom_selected>bottom</option>
        <option $files_selected>files</option>
        <option $none_selected>none</option>
        </select>
    </TD></TR>
  <TR class=roweven>
    <TD>Sort Order</TD>
    <TD><input type=text name=sort_order value=$sort_order></TD></TR>
  <TR class=rowodd>
    <TD>URL</TD>
    <TD>$page_url</TD></TR>
</TBODY></TABLE>
<input type=submit name=submit value=Update>
</form>
"
}

ad_return_template