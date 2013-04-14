
Ext.application({
    name: 'PO',
    models: ['Note'],
    stores: ['Notes', 'Contacts'],

    requires: [
        'Ext.MessageBox',
        'Ext.data.Store',
        'Ext.List',
        'Ext.plugin.PullRefresh'
    ],

    launch: function() {
	Ext.create("Ext.tab.Panel", {
	    fullscreen: true,
	    tabBarPosition: 'bottom',

	    items: [{
		    title: 'Home',
		    iconCls: 'home',
		    html: [
			'<center><img src="/senchatouch-notes/resources/startup/320x460.png"/></center>',
			'<h1>]project-open[ Sencha Touch Notes</h1>',
			"<p>This demo shows how to build Sencha Touch applications using ]po[."
		    ].join("")
	     }, {
		    xtype: 'nestedlist',
		    title: 'Blog',
		    iconCls: 'star',
		    displayField: 'title',

		    detailCard: {
			xtype: 'panel',
			scrollable: true,
			styleHtmlContent: true
		    },

		    listeners: {
		    	itemtap: function(nestedList, list, index, element, post) {
				 this.getDetailCard().setHtml(post.get('content'));
		    	}
		    },

		    store: {
			type: 'tree',

			fields: [
			    'title', 'link', 'author', 'contentSnippet', 'content',
			    {name: 'leaf', defaultValue: true}
			],

			root: {
			    leaf: false
			},

			proxy: {
			    type: 'jsonp',
			    url: 'https://ajax.googleapis.com/ajax/services/feed/load?v=1.0&q=http://feeds.feedburner.com/SenchaBlog',
			    reader: {
				type: 'json',
				rootProperty: 'responseData.feed.entries'
			    }
			}
		    }
	     }, {
		    xtype: 'list',
		    title: 'List',
		    iconCls: 'star',
		    itemTpl: '<div class="contact2"><strong>{firstName}</strong> {lastName}</div>',
		    disclosure: true,
		    grouped: true,
		    indexBar: true,
		    onItemDisclosure: function(record, item, index, e) {
                    	//show a messagebox alert which shows the persons firstName
                	e.stopEvent();
                	Ext.Msg.alert('Disclose', 'Disclose more info for ' + record.get('firstName'));
            	    },

		    store: 'Contacts'

		}, {
                    title: 'Contact',
                    iconCls: 'user',
                    xtype: 'formpanel',
                    url: 'contact.php',
                    layout: 'vbox',

                    items: [{
                            xtype: 'fieldset',
                            title: 'Contact Us',
                            instructions: '(email address is optional)',
                            items: [
                                {
                                    xtype: 'textfield',
                                    label: 'Name'
                                },
                                {
                                    xtype: 'emailfield',
                                    label: 'Email'
                                },
                                {
                                    xtype: 'textareafield',
                                    label: 'Message'
                                }
                            ]
                        },
                        {
                            xtype: 'button',
                            text: 'Send',
                            ui: 'confirm',
                            handler: function() {
                                this.up('formpanel').submit();
                            }
                        }
                    ]
                }


	    ]
	});
    }
});