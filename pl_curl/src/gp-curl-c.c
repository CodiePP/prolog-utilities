/*   Prolog Interface to libcurl (HTTP) -- GNU Prolog bridge
 *   Copyright (C) 2026  Alexander Diemand
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

#if !defined(__GPROLOG_VERSION__) || __GPROLOG_VERSION__ < 10400
#error "needs GNU Prolog >= 1.4.0"
#endif
#include "curl_core.h"

/* pl_curl_get(+URL, +Options, -Status, -Headers, -Body)
 *
 * Options is a list of:
 *   param(Name, Value)          query parameter (URL-encoded)
 *   header(Name, Value)         extra request header
 *   basic_auth(User, Pass)      HTTP Basic authentication
 *   bearer_auth(Token)          Authorization: Bearer <Token>
 *   timeout(Seconds)            total request timeout, default 300
 *   connect_timeout(Seconds)    connect-phase timeout, default 30
 *   max_body(Bytes)             max. response body size, default 64 MiB
 *   body_as(Type)               atom (default) or codes
 *   follow_redirect(Bool)       true/false, default true
 *   ssl_verify(Bool)            true/false, default true
 *   user_agent(Atom)
 *
 * Headers is unified with a list of Name-Value atom pairs.
 * on transport error, error(curl_error(Message), context(pl_curl_get/5, _))
 * is thrown.
 */

enum gp_body_type { GP_BODY_ATOM, GP_BODY_CODES };

/* unifies body with the response body as a code list; unlike an atom, the
 * list keeps NUL bytes */
static PlBool gp_unify_body_codes(const pl_curl_response *resp, PlTerm body)
{
  PlTerm *codes;
  PlBool ok;
  size_t i;

  if (resp->body_len == 0) {
    return Pl_Un_Proper_List_Check(0, NULL, body);
  }
  codes = (PlTerm *)malloc(resp->body_len * sizeof(PlTerm));
  if (!codes) {
    return PL_FALSE;
  }
  for (i = 0; i < resp->body_len; i++) {
    codes[i] = Pl_Mk_Integer((unsigned char)resp->body[i]);
  }
  ok = Pl_Un_Proper_List_Check((int)resp->body_len, codes, body);
  free(codes);
  return ok;
}

/* throws error(Formal(Message), context(Name/Arity, _)); does not return,
 * so everything must be freed before */
static PlBool gp_throw_error(const char *formal, const char *msg, const char *name, int arity)
{
  PlTerm f[1], pi[2], ctx[2], err[2];

  f[0] = Pl_Mk_Atom(Pl_Create_Allocate_Atom((char *)msg));
  pi[0] = Pl_Mk_Atom(Pl_Create_Atom((char *)name));
  pi[1] = Pl_Mk_Integer(arity);
  ctx[0] = Pl_Mk_Compound(Pl_Create_Atom("/"), 2, pi);
  ctx[1] = Pl_Mk_Variable();
  err[0] = Pl_Mk_Compound(Pl_Create_Atom((char *)formal), 1, f);
  err[1] = Pl_Mk_Compound(Pl_Create_Atom("context"), 2, ctx);
  Pl_Throw(Pl_Mk_Compound(Pl_Create_Atom("error"), 2, err));
  return PL_FALSE;
}

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
  enum gp_body_type body_type = GP_BODY_ATOM;

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
    } else if (args && arity == 1 && strcmp(name, "max_body") == 0) {
      req.max_body = (long)Pl_Rd_Integer_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "body_as") == 0) {
      const char *t = Pl_Atom_Name(Pl_Rd_Atom_Check(args[0]));
      if (strcmp(t, "codes") == 0) {
        body_type = GP_BODY_CODES;
      } else if (strcmp(t, "atom") == 0) {
        body_type = GP_BODY_ATOM;
      } else {
        Pl_Err_Domain(Pl_Create_Atom("body_as"), args[0]);
      }
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
    return gp_throw_error("curl_error", resp.errbuf, "pl_curl_get", 5);
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
        !(body_type == GP_BODY_CODES
              ? gp_unify_body_codes(&resp, p_body)
              /* an atom ends at the first NUL byte; use body_as(codes) for binary data */
              : Pl_Un_String_Check(resp.body ? resp.body : "", p_body))) {
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
