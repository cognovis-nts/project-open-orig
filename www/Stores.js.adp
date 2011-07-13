/**
 * intranet-sencha-ticket-tracker/www/Stores.js
 * Data stores.
 *
 * @author Frank Bergmann (frank.bergmann@project-open.com)
 * @creation-date 2011-05
 * @cvs-id $Id: Stores.js.adp,v 1.36 2011/07/13 11:00:02 po34demo Exp $
 *
 * Copyright (C) 2011, ]project-open[
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 *  This program is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

/*
 * Status Engine for the StoreManager
 * There are dependencies with stores,
 * which we handle here explicitely.
 */
Ext.data.StoreManager.addListener('add', function(index, store, key) {
	var storeId = store.storeId;
	// console.log('StoreManager: add: ' + storeId);
});



// ----------------------------------------------------------------
// Employees
// ----------------------------------------------------------------

// Loads all the IDs of the members of the "Employees" group.
// This store needs to load before the userStore,
// because we need to filter users into employees.
var employeeMembershipRelStore = Ext.create('Ext.data.Store', {
	storeId:	'employeeMembershipRelStore',
	model:		'TicketBrowser.EmployeeMembershipRel',
	autoLoad: 	true,			// Load ASAP
	remoteSort:	false,			// Doesn't need sorting
	remoteFilter:	false,			// Doesn't need filtering
	pageSize: 	1000000			// Load entire table
});

// EmployeeStore is a "child store" of userStore
Ext.define('PO.data.EmployeeStore', {
	extend: 'Ext.data.Store',
	load: function(options) {
		// Delete whatever was there before
		this.removeAll();
		// Copy values from userStore if the user is member of Employees group
		userStore.each(function(record) {
			var user_id = record.get('user_id');
			var emp_rec = employeeMembershipRelStore.findRecord('object_id_two',user_id);
			if (null != emp_rec) { 
				userEmployeeStore.add(record); 
			}
		});
	}
});

// Create a copy of the userStore with filtered values.
// Performs the filtering once the original store has been loaded.
var userEmployeeStore = Ext.create('PO.data.EmployeeStore', {
	storeId: 'userEmployeeStore',
	model: 'TicketBrowser.User'
});




// ----------------------------------------------------------------
// Customers
// ----------------------------------------------------------------

// Loads all the IDs of the members of the "Customers" group.
// This store needs to load before the userStore,
// because we need to filter users into customers.
var customerMembershipRelStore = Ext.create('Ext.data.Store', {
	storeId:	'customerMembershipRelStore',
	model:		'TicketBrowser.CustomerMembershipRel',
	autoLoad: 	true,			// Load ASAP
	remoteSort:	false,			// Doesn't need sorting
	remoteFilter:	false,			// Doesn't need filtering
	pageSize: 	1000000			// Load entire table
});

// CustomerStore is a "child store" of userStore
Ext.define('PO.data.CustomerStore', {
	extend: 'Ext.data.Store',
	load: function(options) {
		// Delete whatever was there before
		this.removeAll();
		// Copy values from userStore if the user is member of Customers group
		userStore.each(function(record) {
			var user_id = record.get('user_id');
			var emp_rec = customerMembershipRelStore.findRecord('object_id_two',user_id);
			if (null != emp_rec) { 
				userCustomerStore.add(record); 
			}
		});
	}
});

// Create a copy of the userStore with filtered values.
// Performs the filtering once the original store has been loaded.
var userCustomerStore = Ext.create('PO.data.CustomerStore', {
	storeId: 'userCustomerStore',
	model: 'TicketBrowser.User'
});




// ----------------------------------------------------------------
// User Store
// ----------------------------------------------------------------

var userStore = Ext.create('PO.data.UserStore', {
	storeId:	'userStore',
	model:		'TicketBrowser.User',
	remoteSort:	false,
	remoteFilter:	true,
	autoLoad: 	false,			// Load manually below in order to create child stores.
	autoSync: 	true,			// Write changes to the REST server ASAP
	// Load all users into this table, this is rarely more than 2000...
	// ToDo: Replace this with a server-side search function plus cache(?)
	pageSize: 	1000000,
	sorters: [{
		property: 'first_names',
		direction: 'ASC'
	}, {
		property: 'last_name',
		direction: 'ASC'
	}]
});


userStore.load(
	function(record, operation) {
		// This code is called once the reply from the server has arrived.
		userStore.sort('name');

		// Now we can load (re-load possibly?) the child stores
		// The child stores will be sorted in the same order as userStore
		userEmployeeStore.load();
		userCustomerStore.load();
	}
);


var ticketAreaStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'ticketAreaStore',
	model: 'TicketBrowser.Category',
	remoteFilter:	true,
	autoLoad:	true,
	pageSize:	1000,
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Sencha Ticket Tracker Area\''
		},
		reader: { type: 'json', root: 'data' }
	}
});
ticketAreaStore.load(
	function(record, operation) {
		// This code is called once the reply from the server has arrived.
		ticketAreaStore.sort('tree_sortkey');
	}
);


var ticketTypeStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'ticketTypeStore',
	remoteFilter:	true,
	autoLoad:	true,
	model: 'TicketBrowser.Category',
	pageSize:	1000,
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Ticket Type\''
		},
		reader: { type: 'json', root: 'data' }
	}
});
ticketTypeStore.load(
      function(record, operation) {
      // This code is called once the reply from the server has arrived.
      ticketTypeStore.sort('tree_sortkey');
    }
);



var ticketStatusStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'ticketStatusStore',
	autoLoad:	true,
	remoteFilter:	true,
	model: 'TicketBrowser.Category',
	pageSize:	1000,

	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Ticket Status\''
		},
		reader: { type: 'json', root: 'data' }
	}
});

var companyTypeStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'companyTypeStore',
	autoLoad:	true,
	remoteFilter:	true,
	model: 'TicketBrowser.Category',
	pageSize:	1000,

	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Company Type\''
		},
		reader: { type: 'json', root: 'data' }
	}
});


var ticketPriorityStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'ticketPriorityStore',
	autoLoad:	true,
	remoteFilter:	true,
	model:		'TicketBrowser.Category',
	pageSize:	1000,
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Ticket Priority\''
		},
		reader: { type: 'json', root: 'data' }
	}
});


// Incoming and Outgoing channels are both 'Intranet Ticket Origin' category
var ticketOriginStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'ticketOriginStore',
	autoLoad:	true,
	remoteFilter:	true,
	model:		'TicketBrowser.Category',
	pageSize:	1000,
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Ticket Origin\''
		},
		reader: { type: 'json', root: 'data' }
	}
});


var requestAreaStore = Ext.create('Ext.data.Store', {
	storeId:	'requestAreaStore',
	autoLoad:	true,
	remoteFilter:	true,
	pageSize:	500,
	model: 		'TicketBrowser.Category',
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Request Area\''
		},
		reader: { type: 'json', root: 'data' }
	}
});



var requestAreaProgramStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'requestAreaProgramStore',
	autoLoad:	true,
	remoteFilter:	true,
	pageSize:	1000,
	model:		'TicketBrowser.Category',
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Request Area\''
		},
		reader: { type: 'json', root: 'data' }
	}
});


var bizObjectRoleStore = Ext.create('PO.data.CategoryStore', {
	storeId:	'bizObjectRoleStore',
	autoLoad:	true,
	remoteFilter:	true,
	pageSize:	1000,
	model:		'TicketBrowser.Category',
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_category',
		appendId: true,
		extraParams: {
			format: 'json',
			category_type: '\'Intranet Biz Object Role\''
		},
		reader: { type: 'json', root: 'data' }
	}
});


var programStore = Ext.create('Ext.data.Store', {
	storeId:	'programStore',
	autoLoad:	true,
	remoteFilter:	true,
	fields:		['project_id', 'project_name'],
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_project',
		appendId: true,
		extraParams: {
			format: 'json',
			format_variant: 'sencha',
			project_type_id: '2510'		// project_type_id = "Program"
		},
		reader: { type: 'json', root: 'data' }
	}
});



var ticketSlaStore = Ext.create('Ext.data.Store', {
	storeId:	'ticketSlaStore',
	autoLoad:	true,
	remoteFilter:	true,
	fields:		['project_id', 'project_name'],
	proxy: {
		type: 'rest',
		url: '/intranet-rest/im_project',
		appendId: true,
		extraParams: {
			format: 'json',
			format_variant: 'sencha',
			project_type_id: '2502'		// project_type_id = "Service Level Agreement"
		},
		reader: { type: 'json', root: 'data' }
	}
});



var ticketStore = Ext.create('Ext.data.Store', {
	storeId: 'ticketStore',
	model: 'TicketBrowser.Ticket',
	remoteSort: true,
	remoteFilter:	true,
	pageSize: 12,				// Enable pagination
	// autoSync: true,			// Write changes to the REST server ASAP
	sorters: [{
		property: 'creation_date',
		direction: 'DESC'
	}]
});
	

var companyStore = Ext.create('PO.data.CompanyStore', {
	storeId: 'companyStore',
	model: 'TicketBrowser.Company',
	remoteSort: true,
	remoteFilter:	true,
	pageSize: 1000000,
	autoSync: true,				// Write changes to the REST server ASAP
	autoLoad: true,
	sorters: [{
		property: 'company_name',
		direction: 'ASC'
	}]
});



var profileStore = Ext.create('PO.data.ProfileStore', {
	storeId: 'profileStore',
	model: 'TicketBrowser.Profile',
	autoLoad: false,
	remoteSort: true,
	remoteFilter:	true,
	pageSize: 1000,				// There should never be more then dozen groups or so...
	sorters: [{
		property: 'group_name',
		direction: 'DESC'
	}]
});


// Create a copy of the profileStore with filtered values.
// Performs the filtering once the original store has been loaded.
var profileFilteredStore = Ext.create('Ext.data.Store', {
	storeId: 'profileFilteredStore',
	model: 'TicketBrowser.Profile'
});

profileStore.load(
	function(record, operation) {
		// This code is called once the reply from the server has arrived.
		profileStore.sort('group_name');

		profileStore.each(function(record) {
			var groupId = record.get('group_id');
			if (groupId > 1000) {		// Ignore built-in groups with low IDs
				profileFilteredStore.add(record);
			}
		});
	}
);



// Store for keeping the filtered groups per program.
// Initialize to an empty store. There is a procedure
// updating its values depending on the "program/area".
var programGroupStore = Ext.create('PO.data.ProfileStore', {
	model:		'TicketBrowser.Profile',
	autoLoad:	false
});


// fake store while developing
var ticketServiceTypeStore = ticketSlaStore;
var ticketChannelStore = ticketOriginStore; // look up for ticket_incoming_channel_id
var ticketQueueStore = ticketPriorityStore;

