create or replace package api_idcs as

procedure auth_token;

procedure user_get (
	P_QUERY					varchar2 default null
	);

end api_idcs;
