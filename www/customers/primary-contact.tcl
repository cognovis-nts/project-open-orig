# /packages/intranet-core/companies/primary-contact.tcl
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
    Lets you select a primary contact from users assigned to this group

    @param company_id company's group id
    @author mbryzek@arsdigita.com
    @author frank.bergmann@project-open.com
} {
    company_id:integer,notnull
}

set user_id [ad_maybe_redirect_for_registration]
set page_title "Add primary contact"
set context_bar [ad_context_bar [list /intranet/companies/ "Companies"] $page_title]

set company_name [db_string company_name {
select
	c.company_name
from 
	im_companies c
where
	c.company_id = :company_id
}]

set sql "
select distinct
        u.user_id,
        im_name_from_user_id(u.user_id) as name,
        im_email_from_user_id(u.user_id) as email
from
        users u,
        acs_rels r
where
        r.object_id_one = :company_id
        and r.object_id_two = u.user_id
        and not exists (
		select	member_id
		from	group_member_map m
		where	m.member_id = u.user_id
			and m.group_id = [im_employee_group_id]
	)
order by lower(im_name_from_user_id(u.user_id))
"


set contact_info ""
db_foreach address_book_info $sql  {
    append contact_info "<li>$name, $email  </a>(<a href=primary-contact-2?[export_url_vars company_id user_id]>make primary contact</a>)"
} 

db_release_unused_handles


if { [empty_string_p $contact_info] } {
    set page_body "
<H3>No Company Employees in our Database</H3>
We have no contacts in our database for $company_name<BR>
<UL>
  <LI>Please create a <A HREF=/intranet/users/new>new client contact</A>.

  <LI>Make the new client contact a <A HREF=/intranet/companies/view?company_id=$company_id>company employee</A> $company_name.

  <LI>Finally, revisit this page and an option will appear to add the new client contact.

</UL>

Also, please make sure that the client isn't defined multiple with similar names.
"

    doc_return  200 text/html [im_return_template]
    return
}

set return_url "[im_url_stub]/companies/view?[export_url_vars company_id]"

set page_title "Select primary contact for $company_name"
set context_bar [ad_context_bar [list ./ "Companies"] [list view?[export_url_vars company_id] "One company"] "Select contact"]

set page_body "
<ul>
$contact_info
</ul>
"

doc_return  200 text/html [im_return_template]
