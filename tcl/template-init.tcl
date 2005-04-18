# Initialization of ArsDigita Templating System as a Tcl-only module

# Copyright (C) 1999-2000 ArsDigita Corporation
# Author: Karl Goldstein (karlg@arsdigita.com)
# $Id: template-init.tcl,v 1.1 2005/04/18 21:32:35 cvs Exp $

# This is free software distributed under the terms of the GNU Public
# License.  Full text of the license is available from the GNU Project:
# http://www.fsf.org/copyleft/gpl.html

# XXX (bquinn): This file should not be here.

set pkg_id [apm_package_id_from_key acs-templating]

if { [ad_parameter -package_id $pkg_id ShowCompiledTemplatesP dummy 0] } {
  ad_register_filter postauth GET *.cmp cmp_page_filter
}

if { [ad_parameter -package_id $pkg_id ShowDataDictionariesP  dummy 0] } {
  ad_register_filter postauth GET *.dat dat_page_filter
  ad_register_filter postauth GET *.frm frm_page_filter
}
