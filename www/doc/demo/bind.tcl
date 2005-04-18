ad_page_contract {
  @cvs-id $Id: bind.tcl,v 1.1 2005/04/18 21:32:35 cvs Exp $
} {
  user_id:integer
} -properties {
  users:onerow
}



set query "select 
             first_name, last_name
           from
             ad_template_sample_users
           where user_id = :user_id"

db_1row users_query $query -column_array users
