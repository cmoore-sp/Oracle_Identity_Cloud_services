## Background
The team at Oracle provides generic documentation for writing and maintaining APIs for Oracle Identity Cloud Services (IDCS) but the instructions do not provide PL/SQL “answers”. After research and trials, I thought that Storm Petrel could share the starting point for a user-management API. 
We’ve only touched on the first steps of working with IDCS and provided a very fundamental list of users in json. 
During the recent years, I have become frustrated with the hours I spend (or is it waste) on plodding through the Authorization process. For something that is standards based, each organization takes their own path through those standards. I have developed the arrogance or confidence that if I can get the Authorization process working acceptably well, I can finish an API in the time it takes for me to type. It is just work from that point forward. What data do you need in local tables, what do you pull from the API on-the-fly, etc. 
## Articles & Links
There are some good articles worth studying on IDCS:

[REST API For IDCS – Authorization](https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/Authorization.html)

[REST API for IDCS – Users](https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/op-admin-v1-users-id-get.html)

## API Staging Table
We use a table for trapping and storing most of the data involved with an API – successes and failures. It provides a detailed log of activities and can be helpful when troubleshooting. 
1.	For this package to compile you will need to create the table [API_STAGING](https://github.com/cmoore-sp/Oracle_Identity_Cloud_services/blob/main/create_table_api_staging.sql) 
2.	For your results, look in the JSON response
We use api_staging.json_response as the foundation for the SQL statement that extract the JSON data we want for classic Oracle tables. 
## Closing
As Chef John from Food Wishes dot com says, “and as always, ENJOY”.
