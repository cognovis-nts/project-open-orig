# /packages/intranet-invoices/www/new-2.tcl
#
# Copyright (C) 2003-2008 ]project-open[
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.


ad_page_contract {
    Saves invoice changes and set the invoice status to "Created".<br>
    Please note that there are different forms to create invoices for
    example in the intranet-trans-invoicing module of the 
    intranet-server-hosting module.
    @author frank.bergmann@project-open.com
} {
    invoice_id:integer
    { customer_id:integer "" }
    { provider_id:integer "" }
    { select_project:integer,multiple {} }
    { company_contact_id:integer,trim "" }
    { invoice_office_id "" }
    { project_id:integer "" }
    invoice_nr
    invoice_date
    cost_status_id:integer 
    cost_type_id:integer
    cost_center_id:integer
    payment_days:integer
    { payment_method_id:integer "" }
    template_id:integer
    vat:trim,float
    tax:trim,float
    { discount_perc "0" }
    { surcharge_perc "0" }
    { discount_text "" }
    { surcharge_text "" }
    { canned_note_id:integer,multiple "" }
    { note ""}
    item_sort_order:array
    item_name:array
    item_units:float,array
    item_uom_id:integer,array
    item_type_id:integer,array
    item_project_id:integer,array
    item_rate:trim,float,array
    item_currency:array
    { return_url "/intranet-invoices/" }
}

# ---------------------------------------------------------------
# Determine whether it's an Invoice or a Bill
# ---------------------------------------------------------------

# Invoices and Quotes have a "Company" fields.
set invoice_or_quote_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_quote]]
ns_log Notice "intranet-invoices/new-2: invoice_or_quote_p=$invoice_or_quote_p"

# Invoices and Bills have a "Payment Terms" field.
set invoice_or_bill_p [expr $cost_type_id == [im_cost_type_invoice] || $cost_type_id == [im_cost_type_bill]]
ns_log Notice "intranet-invoices/new-2: invoice_or_bill_p=$invoice_or_bill_p"

if {$invoice_or_quote_p} {
    set company_id $customer_id
    if {"" == $customer_id || 0 == $customer_id} {
	ad_return_complaint 1 "You need to specify a value for customer_id"
	return
    }
} else {
    set company_id $provider_id
    if {"" == $provider_id || 0 == $provider_id} {
	ad_return_complaint 1 "You need to specify a value for provider_id"
	return
    }
}

# rounding precision can be 2 (USD,EUR, ...) .. -5 (Old Turkish Lira).
set rounding_precision 2
set rf [expr exp(log(10) * $rounding_precision)]


# ---------------------------------------------------------------
# Check Currency Consistency
# ---------------------------------------------------------------

set default_currency [ad_parameter -package_id [im_package_cost_id] "DefaultCurrency" "" "EUR"]
set invoice_currency [lindex [array get item_currency] 1]
if {"" == $invoice_currency} { set invoice_currency $default_currency }

foreach item_nr [array names item_currency] {
    if {$item_currency($item_nr) != $invoice_currency} {
        ad_return_complaint 1 "<b>[_ intranet-invoices.Error_multiple_currencies]:</b><br>
        [_ intranet-invoices.Blurb_multiple_currencies]"
        ad_script_abort
    }
}

# ---------------------------------------------------------------
# Defaults & Security
# ---------------------------------------------------------------

set user_id [ad_maybe_redirect_for_registration]
set write_p [im_cost_center_write_p $cost_center_id $cost_type_id $user_id]
if {!$write_p || ![im_permission $user_id add_invoices] || "" == $cost_center_id} {
    set cost_type_name [db_string ccname "select im_category_from_id(:cost_type_id)" -default "not found"]
    set cost_center_name [db_string ccname "select im_cost_center_name_from_id(:cost_center_id)" -default "not found"]
    ad_return_complaint 1 "<li>You don't have sufficient privileges to create documents of type '$cost_type_name' in CostCenter '$cost_center_name'."
    ad_script_abort
}


# Invoices and Bills need a payment method, quotes and POs don't.
if {$invoice_or_bill_p && ("" == $payment_method_id || 0 == $payment_method_id)} {
    ad_return_complaint 1 "<li>No payment method specified"
    return
}

if {"" == $provider_id || 0 == $provider_id} { set provider_id [im_company_internal] }
if {"" == $customer_id || 0 == $customer_id} { set customer_id [im_company_internal] }



# ---------------------------------------------------------------
# Check if there is a single project to which this document refers.
# ---------------------------------------------------------------


# Look for common super-projects for multi-project documents
set select_project [im_invoices_unify_select_projects $select_project]

if {1 == [llength $select_project]} {
    set project_id [lindex $select_project 0]
}

if {[llength $select_project] > 1} {

    # Get the list of all parent projects.
    set parent_list [list]
    foreach pid $select_project {
        set parent_id [db_string pid "select parent_id from im_projects where project_id = :pid" -default ""]
        while {"" != $parent_id} {
            set pid $parent_id
            set parent_id [db_string pid "select parent_id from im_projects where project_id = :pid" -default ""]
        }
        lappend parent_list $pid
    }

    # Check if all parent projects are the same...
    set project_id [lindex $parent_list 0]
    foreach pid $parent_list {
        if {$pid != $project_id} { set project_id "" }
    }

    # Reset the list of "select_project", because we've found the superproject.
    if {"" != $project_id} { set select_project [list $project_id] }
}


# ---------------------------------------------------------------
# Choose the default contact for this invoice.
if {"" == $company_contact_id } {
   set company_contact_id [im_invoices_default_company_contact $company_id $project_id]
}

set canned_note_enabled_p [ad_parameter -package_id [im_package_invoices_id] "EnabledInvoiceCannedNoteP" "" 1]


# ---------------------------------------------------------------
# Update invoice base data
# ---------------------------------------------------------------

set invoice_exists_p [db_string invoice_count "select count(*) from im_invoices where invoice_id=:invoice_id"]

# Just update the invoice if it already exists:
if {!$invoice_exists_p} {

    # Let's create the new invoice
    set invoice_id [db_exec_plsql create_invoice ""]

    # Audit the creation of the invoice
    im_audit -object_id $invoice_id -action create

}

# Check if the cost item was changed via outside SQL
im_audit -object_id $invoice_id -action pre_update

# Update the invoice itself
db_dml update_invoice "
update im_invoices 
set 
	invoice_nr	= :invoice_nr,
	payment_method_id = :payment_method_id,
	company_contact_id = :company_contact_id,
	invoice_office_id = :invoice_office_id,
	discount_perc	= :discount_perc,
	discount_text	= :discount_text,
	surcharge_perc	= :surcharge_perc,
	surcharge_text	= :surcharge_text
where
	invoice_id = :invoice_id
"

db_dml update_costs "
update im_costs
set
	project_id	= :project_id,
	cost_name	= :invoice_nr,
	customer_id	= :customer_id,
	cost_nr		= :invoice_id,
	provider_id	= :provider_id,
	cost_status_id	= :cost_status_id,
	cost_type_id	= :cost_type_id,
	cost_center_id	= :cost_center_id,
	template_id	= :template_id,
	effective_date	= :invoice_date,
	start_block	= ( select max(start_block) 
			    from im_start_months 
			    where start_block < :invoice_date),
	payment_days	= :payment_days,
	vat		= :vat,
	tax		= :tax,
	note		= :note,
	variable_cost_p = 't',
	amount		= null,
	currency	= :invoice_currency
where
	cost_id = :invoice_id
"

# Audit the update
im_audit -object_id $invoice_id -action update

if {$canned_note_enabled_p} {

    set attribute_id [db_string attrib_id "
			select	attribute_id 
			from	im_dynfield_attributes
			where	acs_attribute_id = (
					select	attribute_id
					from	acs_attributes
					where	object_type = 'im_invoice'
						and attribute_name = 'canned_note_id'
				)
    " -default 0]

    # Delete the old values
    db_dml del_attr "
	delete from im_dynfield_attr_multi_value 
	where	object_id = :invoice_id
		and attribute_id = :attribute_id
    "

    foreach cid $canned_note_id {
	db_dml insert_note "
		insert into im_dynfield_attr_multi_value (object_id, attribute_id, value) 
		values (:invoice_id, :attribute_id, :cid);
        "
    }
}


# ---------------------------------------------------------------
# Create the im_invoice_items for the invoice
# ---------------------------------------------------------------

# Delete the old items if they exist
db_dml delete_invoice_items "
	DELETE from im_invoice_items
	WHERE invoice_id=:invoice_id
"

set item_list [array names item_name]
foreach nr $item_list {
    set name $item_name($nr)
    set units $item_units($nr)
    set uom_id $item_uom_id($nr)
    set type_id $item_type_id($nr)
    set project_id $item_project_id($nr)
    set rate $item_rate($nr)
    set sort_order $item_sort_order($nr)
    ns_log Notice "item($nr, $name, $units, $uom_id, $project_id, $rate)"

    # Insert only if it's not an empty line from the edit screen
    if {!("" == [string trim $name] && (0 == $units || "" == $units))} {
	set item_id [db_nextval "im_invoice_items_seq"]
	set insert_invoice_items_sql "
	INSERT INTO im_invoice_items (
		item_id, item_name, 
		project_id, invoice_id, 
		item_units, item_uom_id, 
		price_per_unit, currency, 
		sort_order, item_type_id, 
		item_status_id, description
	) VALUES (
		:item_id, :name, 
		:project_id, :invoice_id, 
		:units, :uom_id, 
		:rate, :invoice_currency, 
		:sort_order, :type_id, 
		null, ''
	)"

        db_dml insert_invoice_items $insert_invoice_items_sql

	# Don't audit the update/creation of invoice items!
	# That would be too much, and we re-create them, so
	# audit doesn't make much sense...
    }
}

# ---------------------------------------------------------------
# Associate the invoice with the project via acs_rels
# ---------------------------------------------------------------

# ad_return_complaint 1 [llength $select_project]

foreach project_id $select_project {
    db_1row "get relations" "
		select	count(*) as v_rel_exists
                from    acs_rels
                where   object_id_one = :project_id
                        and object_id_two = :invoice_id
    "
    if {0 ==  $v_rel_exists} {
	set rel_id [db_exec_plsql create_rel ""]
    }
}

# ---------------------------------------------------------------
# Update the invoice amount and currency 
# based on the invoice items
# ---------------------------------------------------------------

set currencies [db_list distinct_currencies "
	select distinct
		currency
	from	im_invoice_items
	where	invoice_id = :invoice_id
		and currency is not null
"]

if {1 != [llength $currencies]} {
	ad_return_complaint 1 "<b>[_ intranet-invoices.Error_multiple_currencies]:</b><br>
	[_ intranet-invoices.Blurb_multiple_currencies] <pre>$currencies</pre>"
	return
}

if {"" == $discount_perc} { set discount_perc 0.0 }
if {"" == $surcharge_perc} { set surcharge_perc 0.0 }


# ---------------------------------------------------------------
# Update the invoice value
# ---------------------------------------------------------------

im_invoice_update_rounded_amount \
    -invoice_id $invoice_id \
    -discount_perc $discount_perc \
    -surcharge_perc $surcharge_perc




db_release_unused_handles
ad_returnredirect "/intranet-invoices/view?invoice_id=$invoice_id"
