/*-------------------------------------------------------------------------*/
/* Prolog libcurl (HTTP) Interface                                         */
/*                                                                         */
/* File  : gp-curl.pl                                                      */
/* Descr.:                                                                 */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 2026 Alexander Diemand                                    */
/*                                                                         */
/*   This program is free software: you can redistribute it and/or modify  */
/*   it under the terms of the GNU General Public License as published by  */
/*   the Free Software Foundation, either version 3 of the License, or     */
/*   (at your option) any later version.                                   */
/*                                                                         */
/*   This program is distributed in the hope that it will be useful,       */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*   GNU General Public License for more details.                          */
/*                                                                         */
/*   You should have received a copy of the GNU General Public License     */
/*   along with this program.  If not, see <http://www.gnu.org/licenses/>. */
/*-------------------------------------------------------------------------*/

:- foreign(pl_curl_init).
:- foreign(pl_curl_get(+term, +term, term, term, term)).
% the C names differ from the predicate names, which the shared core uses
:- foreign(pl_curl_ws_open(+term, +term, term), [fct_name(gp_curl_ws_open)]).
:- foreign(pl_curl_ws_send(+term, +term), [fct_name(gp_curl_ws_send)]).
:- foreign(pl_curl_ws_recv(+term, +term, term), [fct_name(gp_curl_ws_recv)]).
:- foreign(pl_curl_ws_close(+term), [fct_name(gp_curl_ws_close)]).

:- initialization(pl_curl_init).

info_curl :- write('Prolog libcurl (HTTP) Interface'),nl,
             write('pl_curl_get(URL, Options, Status, Headers, Body)'),nl,
             write('  Options: param(Name,Value), header(Name,Value),'),nl,
             write('           basic_auth(User,Pass), bearer_auth(Token),'),nl,
             write('           timeout(Secs), connect_timeout(Secs), max_body(Bytes),'),nl,
             write('           body_as(atom|codes),'),nl,
             write('           follow_redirect(Bool), ssl_verify(Bool), user_agent(Atom)'),nl,
             write('pl_curl_ws_open(URL, Options, WS)'),nl,
             write('  Options: header(Name,Value), connect_timeout(Secs), max_message(Bytes),'),nl,
             write('           text_as(codes|atom), ssl_verify(Bool), user_agent(Atom)'),nl,
             write('pl_curl_ws_send(WS, Text | binary(Bytes))'),nl,
             write('pl_curl_ws_recv(WS, TimeoutMs, Msg)'),nl,
             write('  Msg: text(Data), binary(Bytes), close(Code,Reason) or timeout'),nl,
             write('pl_curl_ws_close(WS)'),nl.
