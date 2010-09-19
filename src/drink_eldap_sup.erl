%%%-------------------------------------------------------------------
%%% File    : drink_eldap_sup.erl
%%% Author  : Dan Willemsen <dan@csh.rit.edu>
%%% Purpose : 
%%%
%%%
%%% edrink, Copyright (C) 2008 Dan Willemsen
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%                         
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%-------------------------------------------------------------------

-module (drink_eldap_sup).
-behaviour (gen_server).

-export ([start_link/0]).
-export ([init/1]).
-export ([handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).
-export ([get_conn/0]).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	case connect() of
		{ok, Ldap} -> {ok, Ldap};
		{error, Reason} -> {stop, {error, Reason}}
	end.

terminate(_Reason, _State) -> ok.

code_change(_OldVsn, State, _Extra) -> {ok, State}.

handle_cast (_Request, State) ->
	{noreply, State}.

handle_call({ldap}, _From, State) ->
	{reply, {ok, State}, State};
handle_call(_, _From, State) ->
	{noreply, State}.

handle_info(_, State) ->
	{noreply, State}.

get_conn() ->
	case catch gen_server:call(?MODULE, {ldap}) of
		{'EXIT', {noproc, _}} ->
			{error, ldap_no_conn};
		Out -> Out
	end.

get_pass() ->
	File = filename:join("etc", "ldappass"),
	case filelib:is_file(File) of
		true ->
			case file:read_file(File) of
				{ok, Bin} -> {ok, binary_to_list(Bin) -- "\n"};
				_ ->
					error_logger:error_msg("Unable to read Ldap Pass file: ~p~n", [File]),
					{error, read_failed}
			end;
		false ->
			error_logger:error_msg("Unable to find Ldap Pass file: ~p~n", [File]),
			{error, pass_not_found}
	end.

connect() ->
	{ok, Hostname} = application:get_env(drink_user_auth_ldap, host),
	{ok, User} = application:get_env(drink_user_auth_ldap, user),
	{ok, Password} = get_pass(),
	case eldap:open([Hostname]) of
		{ok, Ldap} ->
			case eldap:simple_bind(Ldap, User, Password) of
				ok -> {ok, Ldap};
				E ->
					error_logger:error_msg("error logging into LDAP: ~p~n", [E]),
					eldap:close(Ldap),
					{error, ldap_login_failed}
			end;
		E ->
			error_logger:error_msg("error starting LDAP: ~p~n", [E]),
			{error, ldap_conn_failed}
	end.

