create or replace package body api_idcs
as
	-- you will need
	--		1) An Oracle Identity Cloud Services account, yes available for free
	--		2) To set up a couple of users, just to fetch out some data
	--		3) Links to artilces on the various steps
	--		4) Create an Application within your IDCS. This provides the client id and secret
	-- 	https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/OATOAuthClientWebApp.html
	--		5) API instructions for users and groups
	--	https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/op-admin-v1-users-id-get.html
	--
	-- URL for Identity Cloud Services https://<IDCS-Service-Instance>.identity.oraclecloud.com/admin/v1/
	--
	-- Hey, no I did not do the entire API for you. The rest is just work, coding, and knowing what is expected
	-- to meet the operational needs of your community.
	--

	g_base_url				constant varchar2(100)		:= 	'https://idcs-XXXXXXXXXXXXXXXXXXXXXXXXXXXX.identity.oraclecloud.com';
	g_client_id   		constant VARCHAR2(100)		:=	'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';    	-- Replace with Client ID
	g_client_pwd  		constant VARCHAR2(100)		:=	'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX';	-- Replace with Client Secret
	g_wallet_path 		constant VARCHAR2(200)		:= 	'file:/home/oracle/wallet';           	-- Replace with DB Wallet location
	g_wallet_pwd  		constant VARCHAR2(50)			:= 	'Welcome1';                            -- Replace with DB Wallet password

	-- provided by API instructions
	g_users_uri   		constant VARCHAR2(200)		:=	'/admin/v1/Users';
	g_groups_uri  		constant VARCHAR2(200)		:=	'/admin/v1/Groups';
	g_auth_token_uri	constant varchar2(200)		:= 	'/oauth2/v1/token';
	g_bearer_token		VARCHAR2(32767);    																		-- Stores Access token

	g_package					constant varchar2(30)			:= 'api_idcs';
	g_charset 				constant varchar2(8) 			:= 'AL32UTF8';
	g_encode_charset	constant varchar2(20)			:= 'WE8ISO8859P1';	
	ht								constant varchar2(2)			:= chr(9);
	crlf							constant varchar2(2) 			:= chr(13) || chr(10);
	cr								constant varchar2(2)			:= chr(13);	
	lf								constant varchar2(1)			:= chr(10); 
	amp								constant varchar2(1)			:= chr(38);		-- I hate doing "set define off;" !!

--------------------------------------------------------------------------------
--		I N T E R N A L  P R O C E D U R E S
--------------------------------------------------------------------------------
procedure request_headers (
	r_staging						in out api_staging%rowtype
	)
as
begin
	r_staging.request_headers := '';
	for i in 1.. apex_web_service.g_request_headers.count loop
		r_staging.request_headers := r_staging.request_headers || apex_web_service.g_request_headers(i).name||':';
		r_staging.request_headers := r_staging.request_headers || apex_web_service.g_request_headers(i).value || lf;
	end loop;
end request_headers;

procedure response_headers (
	r_staging						in out api_staging%rowtype
	)
as
begin
	for i in 1.. apex_web_service.g_headers.count loop
		r_staging.response_headers := r_staging.response_headers || apex_web_service.g_headers(i).name||':';
		r_staging.response_headers := r_staging.response_headers || apex_web_service.g_headers(i).value || lf;
	end loop;	
end response_headers;

procedure write_staging_data (
	R_STAGING			in out api_staging%ROWTYPE
	) 
as
--------------------------------------------------------------------------------------------------------------------------------
-- Writes captured Data to STAGING 
-- 
-- SDuVall 08may2020
--
-- Modifications
--	
/* the call
write_staging_data(r_staging);
*/
--------------------------------------------------------------------------------------------------------------------------------
	PRAGMA 							AUTONOMOUS_TRANSACTION; -- capture data even if there is a subsequent rollback
begin
	insert into api_staging values r_staging;
	commit;
end write_staging_data;

function write_staging_data (
	R_STAGING			in out api_staging%ROWTYPE
	) return number
--------------------------------------------------------------------------------------------------------------------------------
-- Writes captured Data to STAGING 
-- 
-- EDuVall 08may2020
--
-- Modifications
--	
/* the call
write_staging_data(r_staging);
*/
--------------------------------------------------------------------------------------------------------------------------------
as
	PRAGMA 							AUTONOMOUS_TRANSACTION; -- capture data even if there is a subsequent rollback
begin
	insert into api_staging (
			schema_name,
			api_name,
			api_module,
			data_type,
			action,
			action_date,
			base_url,
			append,
			url,
			status_code,
			json_response,
			http_response,
			request_headers,
			response_headers,
			body,
			delete_ok
		)values (
			r_staging.schema_name,
			r_staging.api_name,
			r_staging.api_module,
			r_staging.data_type,
			r_staging.action,
			r_staging.action_date,
			r_staging.base_url,
			r_staging.append,
			r_staging.url,
			r_staging.status_code,
			r_staging.json_response,
			r_staging.http_response,
			r_staging.request_headers,
			r_staging.response_headers,
			r_staging.body,
			r_staging.delete_ok		
		) returning staging_pk into r_staging.staging_pk;
	commit;
	return r_staging.staging_pk;
end write_staging_data;
--------------------------------------------------------------------------------
--		E X T E R N A L  P R O C E D U R E S
--------------------------------------------------------------------------------

procedure auth_token
as
--------------------------------------------------------------------------------
-- Auth Token
--	cmoore 03AUG2021
--
-- oAuth2 Access to API requires an authorization token
-- See: 
-- 	https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/OATOAuthClientWebApp.html
-- 	this article describes the steps taken below
--
/* the call
begin
	api_idcs.auth_token;
end;
*/
--------------------------------------------------------------------------------
	r_staging								api_staging%rowtype;
	l_credentials						varchar2(500);
	l_client_credentials		varchar2(1000);	

	l_logging								boolean				:= true;
	l_procedure							varchar2(100)	:= g_package || '.auth_token';
begin
	r_staging.append			:= '/oauth2/v1/token';
	r_staging.action			:= 'POST';
	r_staging.api_name		:= g_package;
	r_staging.api_module	:= l_procedure;
	r_staging.action_date	:= sysdate;	
	r_staging.data_type		:= 'auth token';

	r_staging.base_url    := g_base_url;
	r_staging.url 				:= r_staging.base_url || r_staging.append;

	-- STEP 1: Register a confidential application in IDCS
	l_credentials					:= g_client_id || ':' || g_client_pwd; 

	-- STEP 2: Base64 Encode the Client ID and Client Secret
	-- 	Recreating: echo -n "clientid:clientsecret" | base64 -w 0
	-- 	resulting value should have no text wrapping
	--	clean up any extra characters like horizontal tab (HT), line feed, carriage return
	l_credentials					:= utl_encode.text_encode(l_credentials, g_encode_charset, UTL_ENCODE.BASE64);
	l_client_credentials	:=replace(replace(replace(l_credentials,ht),lf),cr);

	-- STEP 3: Obtain Access Token
	/* copied cURL from example at Oracle site
	curl -i
	-H "Authorization: Basic <base64encoded clientid:secret>"
	-H "Content-Type: application/x-www-form-urlencoded;charset=UTF-8"
	--request POST https://tenant-base-url/oauth2/v1/token
	-d "grant_type=client_credentials&scope=urn:opc:idm:__myscopes__"
	*/
	r_staging.body := 'grant_type=client_credentials' || amp ||'scope=urn:opc:idm:__myscopes__';

	-- prepare Request Headers
	apex_web_service.g_request_headers.delete();
	apex_web_service.g_request_headers(1).name 	:= 'Authorization';
	apex_web_service.g_request_headers(1).value := 'Basic ' || l_client_credentials;
	apex_web_service.g_request_headers(2).name 	:= 'Content-Type';
	apex_web_service.g_request_headers(2).value := 'application/x-www-form-urlencoded; charset=UTF-8';

	-- capture request headers in the API_STAGING Table
	request_headers(r_staging);

	r_staging.json_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
		 p_url              => r_staging.url
		,p_http_method      => r_staging.action
		,p_body							=> r_staging.body
		--,p_wallet_path		=> g_wallet_path
		--,p_wallet_pwd			=> g_wallet_pwd
		);  
	r_staging.status_code	:= apex_web_service.g_status_code;
	-- capture the response headers in the API_STAGING Table
	response_headers(r_staging);

	if r_staging.status_code like '2%' then
		r_staging.http_response := null; -- No errors came back
		apex_json.parse(r_staging.json_response); -- Parse JSON response. 
		g_bearer_token 					:= apex_json.get_varchar2(p_path => 'access_token'); 
		-- we can delete from staging after data extracted from json
		r_staging.delete_ok			:= sysdate; 
	else
		r_staging.http_response := r_staging.json_response;
		r_staging.json_response	:= null;
		g_bearer_token 					:= null;
	end if; -- response type			

	-- because this code may run everytime an API call is made, we turn off the logging
	if l_logging then
		write_staging_data(r_staging);	
	end if;
	--dbms_output.put_line('Bearer Token: '|| g_bearer_token);
	exception when others then
		r_staging.status_code := nvl(r_staging.status_code,'FAIL');
		write_staging_data(r_staging); -- write the API staging data even upon failure
		raise; 
end auth_token;

procedure user_get (
	P_QUERY					varchar2 default null
	)
--------------------------------------------------------------------------------
-- User Get
--	cmoore 04AUG2021
--	
-- Should add some error checking to the Query String
-- See this link
--	https://docs.oracle.com/en/cloud/paas/identity-cloud/rest-api/op-admin-v1-users-id-get.html
--
/* the call
begin
	api_idcs.user_get;
end;
*/
--------------------------------------------------------------------------------
as
	r_staging								api_staging%rowtype;
	l_credentials						varchar2(500);
	l_client_credentials		varchar2(1000);	

	l_logging								boolean				:= true;
	l_procedure							varchar2(100)	:= g_package || '.user_get';
begin
	-- P_QUERY is the information appended to URL
	r_staging.append			:= P_QUERY;
	r_staging.action			:= 'GET';
	r_staging.api_name		:= g_package;
	r_staging.api_module	:= l_procedure;
	r_staging.action_date	:= sysdate;	
	r_staging.data_type		:= 'users';

	r_staging.base_url    := g_base_url || g_users_uri;
	if r_staging.append is not null then
		r_staging.url 			:= r_staging.base_url || r_staging.append;
	else
		r_staging.url 			:= r_staging.base_url;
	end if;

	r_staging.body := null;
	if g_bearer_token is null then
		api_idcs.auth_token; -- Get Access Token
	end if;
	-- prepare Request Headers
	apex_web_service.g_request_headers.delete();
	apex_web_service.g_request_headers(1).name := 'Authorization';
	apex_web_service.g_request_headers(1).value := 'Bearer ' || g_bearer_token;
	apex_web_service.g_request_headers(2).name := 'Content-Type';
	apex_web_service.g_request_headers(2).value := 'application/scim+json';	
	request_headers(r_staging);

	r_staging.json_response := APEX_WEB_SERVICE.MAKE_REST_REQUEST(
		 p_url              => r_staging.url
		,p_http_method      => r_staging.action
		--,p_wallet_path		=> g_wallet_path
		--,p_wallet_pwd			=> g_wallet_pwd
		);  
	r_staging.status_code	:= apex_web_service.g_status_code;
	response_headers(r_staging);

	if r_staging.status_code like '2%' then
		r_staging.http_response := null; -- No errors came back
	else
		r_staging.http_response := r_staging.json_response;
		r_staging.json_response	:= null;
	end if; -- status code		
	r_staging.staging_pk := write_staging_data(r_staging);	

	exception when others then
		r_staging.status_code := nvl(r_staging.status_code,'FAIL');
		write_staging_data(r_staging); -- write the API staging data even upon failure
		raise; 
end user_get;

end api_idcs;
