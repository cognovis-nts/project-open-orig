ad_page_contract {
    List and manage contacts.

    @author Matthew Geddert openacs@geddert.com
    @creation-date 2004-07-28
    @cvs-id $Id$
} {
    {party_id:integer,multiple,optional}
    {party_ids:optional}
    {return_url "./"}
    {group_id:integer,multiple,optional}
    {confirmed_p "0"}
} -validate {
    valid_party_submission {
	if { ![exists_and_not_null party_id] && ![exists_and_not_null party_ids] } { 
	    ad_complain "[_ intranet-contacts.lt_Your_need_to_provide_]"
	}
    }
}
if { [exists_and_not_null party_id] } {
    set party_ids [list]
    foreach party_id $party_id {
	lappend party_ids $party_id
    }
}
foreach id $party_ids {
    contact::require_visiblity -party_id $id
}
if { [exists_and_not_null group_id] } {
    if { $group_id != [contacts::default_group] || $confirmed_p } {

	set group_ids $group_id
	db_transaction {
	    set message [list]
	    foreach group_id $group_ids {
		set contacts [list]
		foreach party_id $party_ids {
		    # relation_add verifies that they aren't already in the group
		    set contact_name [contact::name -party_id $party_id] 
		    if { $group_id != [contacts::default_group] } {
			lappend contacts "<a href=\"[contact::url -party_id $party_id]\">$contact_name</a>"
		    } else {
			lappend contacts $contact_name
		    }
		    group::remove_member -group_id $group_id -user_id $party_id
		}
		set contact_count [llength $contacts]
		set contacts [join $contacts ", "]
		set contact $contacts
		set group [lang::util::localize [group::get_element -group_id $group_id -element group_name]]
		if { $group_id != [contacts::default_group] } {
		    if { $contact_count > 1 } {
			util_user_message -html -message [_ intranet-contacts.lt_contacts_were_removed_from_group]
		    } else {
			util_user_message -html -message [_ intranet-contacts.lt_contacts_was_removed_from_group]
		    }
		} else {
		    if { $contact_count > 1 } {
			util_user_message -html -message [_ intranet-contacts.lt_contacts_were_deleted]
		    } else {
			util_user_message -html -message [_ intranet-contacts.lt_contacts_was_deleted]
		    }
		}
	    }
	}
	if { $group_id == [contacts::default_group] } {
	    # Also mark the user deleted
	    acs_user::delete -user_id $party_id
	}
	ad_returnredirect $return_url
	ad_script_abort
    } else {
	set delete_url [export_vars -base group-parties-remove -url {party_id group_id party_ids {confirmed_p 1} return_url}]
	set cancel_url $return_url
	ad_return_template group-delete-confirm
    }
}

set title "[_ intranet-contacts.Remove_From_to_Group]"
set user_id [ad_conn user_id]
set context [list $title]
set package_id [ad_conn package_id]
set recipients [list]
foreach party_id $party_ids {
    lappend recipients "<a href=\"[contact::url -party_id $party_id]\">[contact::name -party_id $party_id]</a>"
}
set recipients [join $recipients ", "]

set form_elements {
    party_ids:text(hidden)
    return_url:text(hidden)
    {recipients:text(inform),optional {label "[_ intranet-contacts.Contacts]"}}
}

set group_options [contact::groups -expand "all" -privilege_required "create"]
if { [llength $group_options] == "0" } {
    ad_return_error "[_ intranet-contacts.lt_Insufficient_Permissi]" "[_ intranet-contacts.lt_You_do_not_have_permi]"
}

append form_elements {
    {group_ids:text(checkbox),multiple {label "[_ intranet-contacts.Remove_from_Groups]"} {options $group_options}}
}
set edit_buttons [list [list "[_ intranet-contacts.lt_Remove_from_Selected_]" create]]




ad_form -action group-parties-remove \
    -name remove_from_group \
    -cancel_label "[_ intranet-contacts.Cancel]" \
    -cancel_url $return_url \
    -edit_buttons $edit_buttons \
    -form $form_elements \
    -on_request {
    } -on_submit {
	db_transaction {
            foreach group_id $group_ids {
                foreach party_id $party_ids {
                    # relation_add verifies that they aren't already in the group
                    group::remove_member -group_id $group_id -user_id $party_id
                }
            }
	}
    } -after_submit {
	contact::search::flush_results_counts
	ad_returnredirect $return_url
    }


