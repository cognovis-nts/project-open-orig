/**
 * intranet-sencha-ticket-tracker/www/CompanyGrid.js
 * Grid table for ]po[ companies
 *
 * @author Frank Bergmann (frank.bergmann@project-open.com)
 * @creation-date 2011-05
 * @cvs-id $Id: CompanyGrid.js.adp,v 1.9 2011/07/15 18:13:35 po34demo Exp $
 *
 * Copyright (C) 2011, ]project-open[
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *	This program is distributed in the hope that it will be useful,
 *	but WITHOUT ANY WARRANTY; without even the implied warranty of
 *	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.	See the
 *	GNU General Public License for more details.
 *
 *	You should have received a copy of the GNU General Public License
 *	along with this program.	If not, see <http://www.gnu.org/licenses/>.
 */


var companyGridSelModel = Ext.create('Ext.selection.CheckboxModel', {
	mode:	'SINGLE'
});

var companyGrid = Ext.define('TicketBrowser.CompanyGrid', {
	extend:		'Ext.grid.Panel',	
	alias:		'widget.companyGrid',
	id:		'companyGrid',
	minHeight:	200,
	store:		companyStore,
	selModel:	companyGridSelModel,

	listeners: {
		itemdblclick: function(view, record, item, index, e) {
	
			// Load the company into the CompanyCompoundPanel
			var compoundPanel = Ext.getCmp('companyCompoundPanel');
			compoundPanel.loadCompany(record);
		}
	},

	columns: [
		{
			header: '#intranet-core.Company_Name#',
			dataIndex: 'company_name',
			flex: 1,
			minWidth: 150,
			renderer: function(value, metaData, record, rowIndex, colIndex, store) {
				return '<a href="/intranet/companies/view?company_id=' + 
					record.get('company_id') + 
					'" target="_blank">' + 
					value +
					'</a>';
			}
		}, {
			header: '#intranet-core.VAT_Number#',
			dataIndex: 'vat_number'
		}, {
			header: '#intranet-sencha-ticket-tracker.Province#',
			dataIndex: 'company_province'
		}, {
			header: '#intranet-core.Primary_contact#',
			dataIndex: 'primary_contact_id',
			renderer: function(value, o, record) {
				return userStore.name_from_id(record.get('primary_contact_id'));
			}
		}, {
 			header: '#intranet-helpdesk.Status#',
			dataIndex: 'company_status_id',
			renderer: function(value, o, record) {
				return companyStatusStore.category_from_id(record.get('company_status_id'));
			},
			field: {
				xtype: 'combobox',
				typeAhead: false,
				triggerAction: 'all',
				selectOnTab: true,
				queryMode: 'local',
				store: companyStatusStore,
				displayField: 'category',
				valueField: 'category_id'
			}
		}, {
 			header: '#intranet-helpdesk.Type#',
			dataIndex: 'company_type_id',
			renderer: function(value, o, record) {
				return companyTypeStore.category_from_id(record.get('company_type_id'));
			}
		}

	],
	dockedItems: [{
		xtype: 'toolbar',
		cls: 'x-docked-noborder-top',
		items: [{
			text: '#intranet-sencha-ticket-tracker.New_Company#',
			iconCls: 'icon-new-ticket',
			handler: function(){
			alert('Not implemented');
			}
		}] 
	}, {
		xtype: 'pagingtoolbar',
		store: companyStore,
		dock: 'bottom',
		displayInfo: true
	}],


	// Called from CompanyFilterForm in order to limit the list of
	// companies according to filter variables.
	// filterValues is a key-value list (object).
	filterCompanies: function(filterValues){
		var store = this.store;
		var proxy = store.getProxy();
		var value = '';
		var query = '1=1';
	
		// delete filters added by other accordion filters
		delete proxy.extraParams['query'];
	
		// Apply the filter values directly to the proxy.
		// This only works if the filters are named according
		// to the REST interface specs.
		for(var key in filterValues) {
			if (filterValues.hasOwnProperty(key)) {
	
				value = filterValues[key];
				if (value == '' || value == undefined || value == null) {
					// Delete the filter
					delete proxy.extraParams[key];
				} else {
		
					// special treatment for special filter variables
					switch (key) {
					case 'vat_number':
						// The customer's VAT number is not part of the REST
						// company fields. So translate into a query:
						value = value.toLowerCase();
						query = query + ' and company_id in (select company_id from im_companies where lower(vat_number) like \'%' + value + '%\')';
						key = 'query';
						value = query;
						break;
					case 'company_type_id':
						// The customer's company type is not part of the REST company fields.
						query = query + ' and company_id in (select company_id from im_companies where company_type_id in (select im_sub_categories from im_sub_categories(' + value + ')))';
						key = 'query';
						value = query;
						break;
					case 'company_name':
						// The customer's company name is not part of the REST
						// company fields. So translate into a query:
						value = value.toLowerCase();
						query = query + ' and company_id in (select company_id from im_companies where lower(company_name) like \'%' + value + '%\')';
						key = 'query';
						value = query;
						break;
					case 'start_date':
						// I can't get the proxy to quote (') the date, so we do it manually here:
						var	year = '' + value.getFullYear(),
							month =  '' + (1 + value.getMonth()),
							day = '' + value.getDate();
						if (month.length < 2) { month = '0' + month; }
						if (day.length < 2) { day = '0' + day; }
						value = '\'' + year + '-' + month + '-' + day + '\'';
						// console.log(value);
						query = query + ' and company_creation_date >= ' + value;
						key = 'query';
						value = query;
						break;
					case 'end_date':
						// I can't get the proxy to quote (') the date, so we do it manually here:
						var	year = '' + value.getFullYear(),
							month =  '' + (1 + value.getMonth()),
							day = '' + value.getDate();
						if (month.length < 2) { month = '0' + month; }
						if (day.length < 2) { day = '0' + day; }
						value = '\'' + year + '-' + month + '-' + day + '\'';
						// console.log(value);
						query = query + ' and company_creation_date <= ' + value;
						key = 'query';
						value = query;
						break;
					break;
					}
		
					// Save the property in the proxy, which will pass it directly to the REST server
					proxy.extraParams[key] = value;
				}
			}
		}
		
		store.loadPage(1);
	}

});
