# /packages/intranet-exchange-rate/www/index.tcl
#
# Copyright (C) 2003-2004 Project/Open
#
# All rights reserved. Please check
# http://www.project-open.com/license/ for details.

ad_page_contract {
    @author Frank Bergmann frank.bergmann@project-open.com
    @creation-date 2005-06-04
    @cvs-id $Id$

} {
    {orderby "package_key"}
    {year ""}
}

# ---------------------------------------------------------------
# Default & Security
# ---------------------------------------------------------------

set page_title [lang::message::lookup "" intranet-exchange-rate.Exchange_Rates "Exchange Rates"]
set context [list $page_title]
set page_focus "im_header_form.keywords"

set user_id [ad_maybe_redirect_for_registration]
set user_is_admin_p [im_is_user_site_wide_or_intranet_admin $user_id]
if {!$user_is_admin_p} {
    ad_return_complaint 1 "You have insufficient privileges to use this page"
    return
}

if {"" == $year} {
    set year [lindex [split [ns_localsqltimestamp] "-"] 0]
}

set form_id "exchange_rates"

# ------------------------------------------------------------------
# Build the form
# ------------------------------------------------------------------

set supported_currencies [im_supported_currencies]

set dimensional_list {
    {
	year "Year:" 2006 {
	    { 1999 "1999" {where "to_char(days.day, 'YYYY') = '1999'"} }
	    { 2000 "2000" {where "to_char(days.day, 'YYYY') = '2000'"} }
	    { 2001 "2001" {where "to_char(days.day, 'YYYY') = '2001'"} }
	    { 2002 "2002" {where "to_char(days.day, 'YYYY') = '2002'"} }
	    { 2003 "2003" {where "to_char(days.day, 'YYYY') = '2003'"} }
	    { 2004 "2004" {where "to_char(days.day, 'YYYY') = '2004'"} }
	    { 2005 "2005" {where "to_char(days.day, 'YYYY') = '2005'"} }
	    { 2006 "2006" {where "to_char(days.day, 'YYYY') = '2006'"} }
	    { 2007 "2007" {where "to_char(days.day, 'YYYY') = '2007'"} }
	    { 2008 "2008" {where "to_char(days.day, 'YYYY') = '2008'"} }
	    { 2009 "2009" {where "to_char(days.day, 'YYYY') = '2009'"} }
	    { 2010 "2010" {where "to_char(days.day, 'YYYY') = '2010'"} }
	    { all "All" {} }
	}
    }
}

set missing_text "<strong>No packages match criteria.</strong>"

set filter_html "<center><table><tr><td>[ad_dimensional $dimensional_list]</td></tr></table></center>"

set use_watches_p [expr ! [ad_parameter -package_id [ad_acs_kernel_id] PerformanceModeP request-processor 1]]

set return_url "[ad_conn url]?[ad_conn query]"

set table_def {
    { xchg_date "Date" "" "<td><a href=\"[export_vars -base new {{form_mode edit} {today $day} return_url}]\">$day</a></td>" }
}

set rate_select ""
set rate_from ""
foreach currency [im_supported_currencies] {
    set low_cur [string tolower $currency]
    lappend table_def [list $currency "$currency" "" "<td><font color=\${${low_cur}_color}>\${$low_cur}</font></td>"]

    append rate_select "\t\t,$low_cur.rate as $low_cur\n"
    append rate_select "\t\t,CASE WHEN $low_cur.manual_p ='t' THEN 'black' ELSE 'grey' END as ${low_cur}_color\n"

    append rate_from "\t\tLEFT OUTER JOIN (select day, rate, manual_p from im_exchange_rates where currency='$currency') $low_cur\n\t\tON (days.day = $low_cur.day)\n"

}

doc_body_flush
set table [ad_table -Torderby $orderby -Tmissing_text $missing_text exchange_rates "" $table_def]
db_release_unused_handles
