# /packages/intranet-core/www/member-update.tcl
#
# Copyright (C) 1998-2004 various parties
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
    Allows to delete project members and to update
    their time/cost estimates for this project.
} {
    object_id:integer
    days:array,optional
    { return_url "" }
    { submit "" }
    { delete_user:multiple,integer "" }
}

set current_user_id [ad_maybe_redirect_for_registration]

# Determine our permissions for the current object_id.
# We can build the permissions command this ways because
# all Project/Open object types define procedures
# im_ObjectType_permissions $user_id $object_id view read write admin.
#
set object_type [db_string acs_object_type "select object_type from acs_objects where object_id=:object_id"]
set perm_cmd "${object_type}_permissions \$current_user_id \$object_id view read write admin"
eval $perm_cmd

if {!$write} {
    ad_return_complaint 1 "You have no rights to modify members of this object."
    return
}

ns_log Notice "object_id=$object_id"
ns_log Notice "submit=$submit"
ns_log Notice "delete_user(multiple)=$delete_user"

# "Del" button pressed: delete the marked users
#
if {[string equal $submit "Del"]} {

    foreach user $delete_user {
	ns_log Notice "delete user: $user"
	group::remove_member \
	    -object_id $object_id \
	    -user_id $user
    }
}


# "Save" button pressed: Save the new estimation values
#
if {[string equal $submit "Save"]} {
    set user_list [array names days]
    foreach user $user_list {
	regsub {\,} $days($user) {.} days($user)
	ns_log Notice "days(user)=$days($user)"
	set sql "
		update USER_GROUP_MEMBER_FIELD_MAP
		set field_value='$days($user)'
		where object_id=:object_id
		and user_id='$user'
		and field_name='estimation_days'"
        db_dml update_days $sql
    }
}

#doc_return  200 text/html ""
ad_returnredirect $return_url












