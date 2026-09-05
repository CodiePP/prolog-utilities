/*-------------------------------------------------------------------------*/
/* Prolog libcurl (HTTP) Interface                                         */
/*                                                                         */
/* File  : gp-curl.pl                                                      */
/* Descr.:                                                                 */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2026 Alexander Diemand                               */
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

:- initialization(pl_curl_init).

info_curl :- write('Prolog libcurl (HTTP) Interface'),nl,
             write('pl_curl_get(URL, Options, Status, Headers, Body)'),nl,
             write('  Options: param(Name,Value), header(Name,Value),'),nl,
             write('           basic_auth(User,Pass), bearer_auth(Token),'),nl,
             write('           timeout(Secs), connect_timeout(Secs),'),nl,
             write('           follow_redirect(Bool), ssl_verify(Bool), user_agent(Atom)'),nl.
