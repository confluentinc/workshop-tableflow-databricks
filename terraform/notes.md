### Important Manual Steps for Databricks

To grant an admin role to a service principal in Databricks, you need to be either an account admin or a workspace admin. You can add the service principal to the admins group through the Settings > Identity and Access > Groups section. This grants it the same permissions as a standard admin user.
Steps to grant admin role to a service principal:
Login as a Workspace Admin: Log in to your Databricks workspace with an account that has admin privileges.
Navigate to Identity and Access: Click your username in the top bar, select "Settings," then "Identity and Access".
Manage Groups: Click "Manage" next to "Groups".
Select the Admins Group: Choose the "admins" system group.
Add Members: Click "Add members" and select the service principal you want to add.
Confirm: Confirm the addition of the service principal to the group.



ANOTHER ONE

When setting up the Service Principal, need to grant it privilege to create external locations
Find the `Application ID` from the Workspace Settings >> Identity and access >> Service principals UI
Run this statement in the SQL editor:
GRANT CREATE EXTERNAL LOCATION ON METASTORE TO `your_service_principal_application_id`;

GRANT CREATE EXTERNAL LOCATION ON METASTORE TO `1718b555-05ea-4664-afcf-8b08473286fc`;
