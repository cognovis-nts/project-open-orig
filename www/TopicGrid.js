Ext.define('ForumBrowser.TopicGrid', {

    extend: 'Ext.grid.Panel',    
    alias: 'widget.topicgrid',
    
    initComponent: function(){
        var store = Ext.create('Ext.data.Store', {
            model: 'ForumBrowser.Topic',
            remoteSort: true,
            sorters: [{
                property: 'lastpost',
                direction: 'DESC'
            }],
            proxy: {
                type: 'rest',
                url: '/intranet-sencha-ticket-tracker/tickets',
		extraParams: {
                        format: 'json',
			sla_id: 0		// overwritten when loading forum
                },
                reader: {
                    type: 'json',
                    root: 'data',
                    totalProperty: 'total'
                },
		buildUrl: function(request) {
		    var	me        = this,
		    	operation = request.operation,
		    	records   = operation.records || [],
		    	record    = records[0],
		    	format    = me.format,
		    	url       = me.getUrl(request),
		    	id        = record ? record.getId() : operation.id;
		    
		    request.url = url;		    
		    return url;
		}
		
            }
        });
        
        Ext.apply(this, {
            store: store,
            viewConfig: {
                plugins: [{
                    pluginId: 'preview',
                    ptype: 'preview',
                    bodyField: 'excerpt',
                    expanded: true
                }]
            },
            selModel: Ext.create('Ext.selection.RowModel', {
                mode: 'SINGLE',
                listeners: {
                    scope: this,
                    select: this.onSelect
                }    
            }),
            columns: [
            {
                header: 'Topic',
                dataIndex: 'title',
                flex: 1,
                renderer: function(value, o, record) {
                     return Ext.String.format('<div class="topic"><b>{0}</b><span class="author">{1}</span></div>',
                         value, record.get('author'));
                }
            }, {
                header: 'Author',
                dataIndex: 'author',
                width: 100
                //hidden: true
            }, {
                header: 'Replies',
                dataIndex: 'replycount',
                width: 70,
                align: 'right'
            }, {
                header: 'Last Post',
                dataIndex: 'lastpost',
                width: 150
            }
            ],
            dockedItems: [{
                xtype: 'toolbar',
                cls: 'x-docked-noborder-top',
                items: [{
                    text: 'New Topic',
                    iconCls: 'icon-new-topic',
                    handler: function(){
                        alert('Not implemented');
                    }
                }, '-', {
                    text: 'Preview Pane',
                    iconCls: 'icon-preview',
                    enableToggle: true,
                    pressed: true,
                    scope: this,
                    toggleHandler: this.onPreviewChange
                }, {
                    text: 'Summary',
                    iconCls: 'icon-summary',
                    enableToggle: true,
                    pressed: true,
                    scope: this,
                    toggleHandler: this.onSummaryChange
                }]
            }, {
                dock: 'bottom',
                xtype: 'pagingtoolbar',
                store: store,
                displayInfo: true,
                displayMsg: 'Displaying topics {0} - {1} of {2}',
                emptyMsg: 'No topics to display'
            }]
        });
        this.callParent();
    },
    
    onSelect: function(selModel, rec){
        this.ownerCt.onSelect(rec);
    },
    
    loadForum: function(id){
        var store = this.store;
        store.getProxy().extraParams.sla_id = id;
        store.loadPage(1);
    },
    
    onPreviewChange: function(btn, pressed){
        this.ownerCt.togglePreview(pressed);
    },
    
    onSummaryChange: function(btn, pressed){
        this.getView().getPlugin('preview').toggleExpanded(pressed);
    }
});
