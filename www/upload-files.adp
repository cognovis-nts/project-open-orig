
<master src="@master_file;noquote@">

<property name="title">@page_title;noquote@</property>

<br><br><br><br><br>


@company_placeholder;noquote@

<h1>File to upload</h1>
<table border="0" cellpadding="5px" cellspacing="5px">
<tr>

<if @anonymous_p@ false>
<th valign="top">
Project
</th>
</if>

<th valign="top">
File
</th>
<th valign="top">
Source Language
</th>
<th valign="top">
Target Language
</th>
<th valign="top">
Desired Delivery Date
</th>
<th valign="top">
</th>
</tr>

<tr>

<if @anonymous_p@ false>
<!--<td valign="top">
	<%=[im_project_select -include_empty_p 1 -include_empty_name "New project" -project_status_id [im_project_status_open] -exclude_subprojects_p 0 project_id "" "open"]%>
</td>-->
</if>

<td valign="top">
    <div id="fi-basic"></div>
</td>

<td valign="top">
    <form id="form_source_language">@source_language_combo;noquote@</form>
</td>
<td valign="top">
    <div id="form_target_languages"></div>    
</td>

<td valign="top">
    <!--<input type="text" id="dateField">-->
    <div id='delivery_date_placeholder'></div>
</td>

<td valign="top">
    <button id="btnSendFileandMetaData">Upload</button>
</td>

</tr>

</table>

<br><br><br>

<table cellpadding="0" cellspacing="0" border="0">
<tr>
	<td><div id="panel_files_uploaded_placeholder"></div></td>
	<td><div id="panel_uploaded_files"></div></td>
</tr>
<tr>
	<td colspan="2" align="right"><button id="continue">Continue >></button></td>
</tr>

</table>


<div id="sidebar"></div>
