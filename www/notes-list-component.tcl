# -------------------------------------------------------------
# /packages/intranet-notes/www/notes-list-component.tcl
#
# Copyright (c) 2007 ]project-open[
# All rights reserved.
#
# Author: frank.bergmann@project-open.com
#

# -------------------------------------------------------------
# Variables:
#	object_id:integer
#	return_url

if {![info exists object_id]} {

    ad_page_contract {
	@author frank.bergmann@project-open.com
    } {
	object_id
    }

}


if {![info exists return_url] || "" == $return_url} { set return_url [im_url_with_query] }
set user_id [ad_maybe_redirect_for_registration]
set new_note_url [export_vars -base "/intranet-notes/new" {object_id return_url}]


# Check the permissions
# Permissions for all usual projects, companies etc.
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id"]
set perm_cmd "${object_type}_permissions \$user_id \$object_id object_view object_read object_write object_admin"
eval $perm_cmd


# ----------------------------------------------------
# Create a "multirow" to show the results

multirow create notes note_type note note_formatted

if {$object_read} {

    set notes_sql "
	select	n.*,
		im_category_from_id(n.note_type_id) as note_type
	from	im_notes n
	where	n.object_id = :object_id
    "
    
    db_multirow -extend { note_formatted } notes notes_query $notes_sql {

	regsub -all {[^0-9a-zA-Z]} $note_type "_" note_type_key
	set note_type [lang::message::lookup "" intranet-notes.$note_type_key $note_type]

	set note_pieces [split $note " "]
	set first_note [lindex $note_pieces 0]
	set rest_note [join [lrange $note_pieces 1 end] " "]

	set notes_edit_url [export_vars -base "/intranet-notes/new" {note_id return_url}]

	switch $note_type_id {
	    11502 {
		# Email
		set note_formatted "<a href=\"mailto:$first_note\">$first_note</a> $rest_note"
	    }
	    11504 {
		# Http
		set note_formatted "<a href=\"$first_note\" target=\"_\">$first_note</a> $rest_note"
	    }
	    11506 {
		# FTP
		set note_formatted "<a href=\"$first_note\" target=\"_\">$first_note</a> $rest_note"
	    }
	    default {
		set note_formatted "$first_note $rest_note"
	    }
	}
    }
}