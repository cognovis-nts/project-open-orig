-- upgrade-3.2.11.0.0-3.2.12.0.0.sql

alter table im_hours 
add constraint im_hours_project_fk 
foreign key(project_id) references im_projects;

