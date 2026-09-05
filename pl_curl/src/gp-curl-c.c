/*   Prolog Interface to libcurl (HTTP) -- GNU Prolog bridge
 *   Copyright (C) 1999-2026  Alexander Diemand
 *
 *   This program is free software: you can redistribute it and/or modify
 *   it under the terms of the GNU General Public License as published by
 *   the Free Software Foundation, either version 3 of the License, or
 *   (at your option) any later version.
 *
 *   This program is distributed in the hope that it will be useful,
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *   GNU General Public License for more details.
 *
 *   You should have received a copy of the GNU General Public License
 *   along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "gprolog.h"
#include "curl_core.h"

/* pl_curl_get(+URL, +Options, -Status, -Headers, -Body)
 *
 * Options is a list of:
 *   param(Name, Value)          query parameter (URL-encoded)
 *   header(Name, Value)         extra request header
 *   basic_auth(User, Pass)      HTTP Basic authentication
 *   bearer_auth(Token)          Authorization: Bearer <Token>
 *   timeout(Seconds)            total request timeout
 *   connect_timeout(Seconds)    connect-phase timeout
 *   follow_redirect(Bool)       true/false, default true
 *   ssl_verify(Bool)            true/false, default true
 *   user_agent(Atom)
 *
 * Headers is unified with a list of Name-Value atom pairs.
 * on transport error, an exception is thrown.
 */

static int gp_curl_bool(PlTerm t)
{
  int a = Pl_Rd_Atom_Check(t);
  return strcmp(Pl_Atom_Name(a), "false") != 0;
}

PlBool pl_curl_get(PlTerm p_url, PlTerm p_opts, PlTerm p_status, PlTerm p_headers, PlTerm p_body)
{
  pl_curl_request req;
  pl_curl_response resp;
  pl_curl_kv params[64];
  pl_curl_kv headers[64];
  int n_params = 0, n_headers = 0;
  PlTerm lst = p_opts;
  PlTerm exc;

  memset(&req, 0, sizeof(req));
  req.follow_redirect = 1;
  req.ssl_verify = 1;
  req.url = Pl_Rd_String_Check(p_url);

  PlTerm *cons;
  while ((cons = Pl_Rd_List_Check(lst)) != NULL) {
    PlTerm opt = cons[0];
    int func, arity;
    PlTerm *args = Pl_Rd_Compound_Check(opt, &func, &arity);
    const char *name = Pl_Atom_Name(func);

    if (args && arity == 2 && strcmp(name, "param") == 0 && n_params < 64) {
      params[n_params].name = Pl_Rd_String_Check(args[0]);
      params[n_params].value = Pl_Rd_String_Check(args[1]);
      n_params++;
    } else if (args && arity == 2 && strcmp(name, "header") == 0 && n_headers < 64) {
      headers[n_headers].name = Pl_Rd_String_Check(args[0]);
      headers[n_headers].value = Pl_Rd_String_Check(args[1]);
      n_headers++;
    } else if (args && arity == 2 && strcmp(name, "basic_auth") == 0) {
      req.auth_mode = PL_CURL_AUTH_BASIC;
      req.auth_user = Pl_Rd_String_Check(args[0]);
      req.auth_pass = Pl_Rd_String_Check(args[1]);
    } else if (args && arity == 1 && strcmp(name, "bearer_auth") == 0) {
      req.auth_mode = PL_CURL_AUTH_BEARER;
      req.auth_pass = Pl_Rd_String_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "timeout") == 0) {
      req.timeout_sec = (long)Pl_Rd_Integer_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "connect_timeout") == 0) {
      req.connect_timeout_sec = (long)Pl_Rd_Integer_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "follow_redirect") == 0) {
      req.follow_redirect = gp_curl_bool(args[0]);
    } else if (args && arity == 1 && strcmp(name, "ssl_verify") == 0) {
      req.ssl_verify = gp_curl_bool(args[0]);
    } else if (args && arity == 1 && strcmp(name, "user_agent") == 0) {
      req.user_agent = Pl_Rd_String_Check(args[0]);
    }

    lst = cons[1];
  }

  req.params = params;
  req.n_params = n_params;
  req.headers = headers;
  req.n_headers = n_headers;

  if (!pl_curl_get_perform(&req, &resp)) {
    exc = Pl_Mk_String(resp.errbuf);
    Pl_Throw(exc);
    return PL_FALSE;
  }

  {
    PlTerm hvals[resp.n_headers ? resp.n_headers : 1];
    int i;
    for (i = 0; i < resp.n_headers; i++) {
      PlTerm pair[2];
      pair[0] = Pl_Mk_String(resp.headers[i].name);
      pair[1] = Pl_Mk_String(resp.headers[i].value);
      hvals[i] = Pl_Mk_Compound(Pl_Create_Atom("-"), 2, pair);
    }

    if (!Pl_Un_Integer_Check(resp.status_code, p_status) ||
        !Pl_Un_Proper_List_Check(resp.n_headers, hvals, p_headers) ||
        !Pl_Un_String_Check(resp.body ? resp.body : "", p_body)) {
      pl_curl_response_free(&resp);
      return PL_FALSE;
    }
  }

  pl_curl_response_free(&resp);
  return PL_TRUE;
}

PlBool pl_curl_init(void)
{
  pl_curl_global_init();
  return PL_TRUE;
}
