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



/* WebSockets
 *
 * pl_curl_ws_open(+URL, +Options, -WS)
 *   Options: header(Name, Value), connect_timeout(Seconds), max_message(Bytes),
 *            text_as(codes|atom), ssl_verify(Bool), user_agent(Atom)
 * pl_curl_ws_send(+WS, +Data)          Data: atom or code list (text message),
 *                                      or binary(Bytes)
 * pl_curl_ws_recv(+WS, +TimeoutMs, -Msg)
 *   Msg = text(Data) | binary(Bytes) | close(Code, Reason) | timeout
 * pl_curl_ws_close(+WS)
 *
 * GNU Prolog has no blobs, so a connection is a small integer: the 1-based
 * index of its slot in gp_ws_table. The table only grows (a handle is never
 * reused for another connection), so a stale handle is either in range with
 * a NULL slot (existence_error) or out of range (type_error). There is no
 * garbage collector hook: a connection is only closed by pl_curl_ws_close/1
 * or when the process exits.
 *
 * Text arrives as bytes: GNU Prolog has no Unicode characters, so a UTF-8
 * message gives one code per byte. text_as(codes) is the default because GNU
 * Prolog's atom table is a fixed resource that is never garbage collected: a
 * long-running feed must not turn every message into an atom.
 */

typedef struct {
  pl_curl_ws *ws;      /* NULL once closed */
  int text_as_atom;
} gp_ws_slot;

static gp_ws_slot *gp_ws_table = NULL;
static int gp_ws_table_len = 0;
static int gp_ws_table_cap = 0;

/* returns the 1-based handle of a new slot, 0 if out of memory */
static long gp_ws_table_alloc(pl_curl_ws *ws, int text_as_atom)
{
  if (gp_ws_table_len == gp_ws_table_cap) {
    int newcap = gp_ws_table_cap ? gp_ws_table_cap * 2 : 16;
    gp_ws_slot *nt = (gp_ws_slot *)realloc(gp_ws_table, (size_t)newcap * sizeof(gp_ws_slot));
    if (!nt) {
      return 0;
    }
    gp_ws_table = nt;
    gp_ws_table_cap = newcap;
  }
  gp_ws_table[gp_ws_table_len].ws = ws;
  gp_ws_table[gp_ws_table_len].text_as_atom = text_as_atom;
  gp_ws_table_len++;
  return gp_ws_table_len;
}

/* the slot of an open connection; raises type_error for anything that is not
 * a handle and existence_error for a closed one (does not return then) */
static gp_ws_slot *gp_ws_get_open(PlTerm t)
{
  PlLong idx;

  if (!Pl_Builtin_Integer(t)) {
    Pl_Err_Type(Pl_Create_Atom("curl_websocket"), t);
    return NULL;
  }
  idx = Pl_Rd_Integer_Check(t);
  if (idx < 1 || idx > gp_ws_table_len) {
    Pl_Err_Type(Pl_Create_Atom("curl_websocket"), t);
    return NULL;
  }
  if (!gp_ws_table[idx - 1].ws) {
    Pl_Err_Existence(Pl_Create_Atom("curl_websocket"), t);
    return NULL;
  }
  return &gp_ws_table[idx - 1];
}

/* the text of an atom or code list as a newly malloc'd buffer (the
 * Pl_Rd_*_Check functions share one global buffer); *len is its length.
 * Raises type_error(text, t) for anything else (does not return then). */
static char *gp_ws_text_owned(PlTerm t, size_t *len)
{
  char *out;

  if (Pl_Builtin_Atom(t)) {
    const char *name = Pl_Atom_Name(Pl_Rd_Atom_Check(t));
    *len = strlen(name);
    out = (char *)malloc(*len + 1);
    if (out) {
      memcpy(out, name, *len + 1);
    }
    return out;
  }
  if (Pl_Builtin_List(t)) {
    int n = Pl_List_Length(t);
    if (n >= 0) {
      out = (char *)malloc((size_t)n + 1);
      if (out) {
        if (n > 0) {
          Pl_Rd_Codes_Str_Check(t, out);
        } else {
          out[0] = '\0';
        }
        *len = (size_t)n;
      }
      return out;
    }
  }
  Pl_Err_Type(Pl_Create_Atom("text"), t);
  return NULL;
}

/* bytes 0..255 of a list into a newly malloc'd buffer; raises an error
 * (does not return then) for anything else */
static char *gp_ws_bytes_owned(PlTerm t, size_t *len)
{
  int n = Pl_List_Length(t);
  PlTerm lst = t;
  char *out;
  int i;

  if (n < 0) {
    Pl_Err_Type(Pl_Create_Atom("list"), t);
    return NULL;
  }
  out = (char *)malloc((size_t)n + 1);
  if (!out) {
    Pl_Err_Resource(Pl_Create_Atom("memory"));
    return NULL;
  }
  for (i = 0; i < n; i++) {
    PlTerm *cons = Pl_Rd_List_Check(lst);
    PlLong b;
    if (!Pl_Builtin_Integer(cons[0])) {
      free(out);
      Pl_Err_Type(Pl_Create_Atom("byte"), cons[0]);
      return NULL;
    }
    b = Pl_Rd_Integer_Check(cons[0]);
    if (b < 0 || b > 255) {
      free(out);
      Pl_Err_Type(Pl_Create_Atom("byte"), cons[0]);
      return NULL;
    }
    out[i] = (char)b;
    lst = cons[1];
  }
  *len = (size_t)n;
  return out;
}

/* a list of the byte values of data */
static PlTerm gp_ws_mk_codes(const char *data, size_t len)
{
  PlTerm *codes;
  PlTerm lst;
  size_t i;

  if (len == 0) {
    return Pl_Mk_Atom(Pl_Atom_Nil());
  }
  codes = (PlTerm *)malloc(len * sizeof(PlTerm));
  if (!codes) {
    Pl_Err_Resource(Pl_Create_Atom("memory"));
  }
  for (i = 0; i < len; i++) {
    codes[i] = Pl_Mk_Integer((unsigned char)data[i]);
  }
  lst = Pl_Mk_Proper_List((int)len, codes);
  free(codes);
  return lst;
}

#define GP_WS_MAX_HEADERS 64

/* frees what gp_ws_open collected so far */
static void gp_ws_free_strings(char **strs, int n)
{
  int i;
  for (i = 0; i < n; i++) {
    free(strs[i]);
  }
}

PlBool gp_curl_ws_open(PlTerm p_url, PlTerm p_opts, PlTerm p_ws)
{
  pl_curl_ws_request req;
  pl_curl_kv headers[GP_WS_MAX_HEADERS];
  char *strs[2 * GP_WS_MAX_HEADERS + 2];   /* every copied string, freed at the end */
  int n_strs = 0;
  int n_headers = 0;
  int text_as_atom = 0;
  char errbuf[CURL_ERROR_SIZE];
  PlTerm lst = p_opts;
  PlTerm *cons;
  pl_curl_ws *ws;
  size_t len;
  long handle;

  memset(&req, 0, sizeof(req));
  req.ssl_verify = 1;

  /* checks that raise errors come first, so that nothing is allocated yet */
  if (Pl_List_Length(p_opts) < 0) {
    Pl_Err_Type(Pl_Create_Atom("list"), p_opts);
  }
  while ((cons = Pl_Rd_List_Check(lst)) != NULL) {
    int func, arity;
    PlTerm *args = Pl_Rd_Compound_Check(cons[0], &func, &arity);
    const char *name = Pl_Atom_Name(func);

    if (args && arity == 1 && strcmp(name, "text_as") == 0) {
      const char *t = Pl_Atom_Name(Pl_Rd_Atom_Check(args[0]));
      if (strcmp(t, "codes") == 0) {
        text_as_atom = 0;
      } else if (strcmp(t, "atom") == 0) {
        text_as_atom = 1;
      } else {
        Pl_Err_Domain(Pl_Create_Atom("text_as"), args[0]);
      }
    } else if (args && arity == 1 && strcmp(name, "connect_timeout") == 0) {
      req.connect_timeout_sec = (long)Pl_Rd_Integer_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "max_message") == 0) {
      req.max_message = (long)Pl_Rd_Integer_Check(args[0]);
    } else if (args && arity == 1 && strcmp(name, "ssl_verify") == 0) {
      req.ssl_verify = gp_curl_bool(args[0]);
    } else if (args && arity == 2 && strcmp(name, "header") == 0) {
      if (n_headers >= GP_WS_MAX_HEADERS) {
        Pl_Err_Resource(Pl_Create_Atom("curl_headers"));
      }
      n_headers++;
    }
    lst = cons[1];
  }

  /* then copy the strings; a type error here frees what was copied */
  n_headers = 0;
  lst = p_opts;
  while ((cons = Pl_Rd_List_Check(lst)) != NULL) {
    int func, arity;
    PlTerm *args = Pl_Rd_Compound_Check(cons[0], &func, &arity);
    const char *name = Pl_Atom_Name(func);
    char *s1, *s2;

    if (args && arity == 2 && strcmp(name, "header") == 0) {
      if (!Pl_Builtin_Atom(args[0]) && !Pl_Builtin_List(args[0])) {
        gp_ws_free_strings(strs, n_strs);
        Pl_Err_Type(Pl_Create_Atom("text"), args[0]);
      }
      if (!Pl_Builtin_Atom(args[1]) && !Pl_Builtin_List(args[1])) {
        gp_ws_free_strings(strs, n_strs);
        Pl_Err_Type(Pl_Create_Atom("text"), args[1]);
      }
      s1 = gp_ws_text_owned(args[0], &len);
      s2 = s1 ? gp_ws_text_owned(args[1], &len) : NULL;
      if (!s1 || !s2) {
        free(s1);
        gp_ws_free_strings(strs, n_strs);
        Pl_Err_Resource(Pl_Create_Atom("memory"));
      }
      strs[n_strs++] = s1;
      strs[n_strs++] = s2;
      headers[n_headers].name = s1;
      headers[n_headers].value = s2;
      n_headers++;
    } else if (args && arity == 1 && strcmp(name, "user_agent") == 0) {
      if (!Pl_Builtin_Atom(args[0]) && !Pl_Builtin_List(args[0])) {
        gp_ws_free_strings(strs, n_strs);
        Pl_Err_Type(Pl_Create_Atom("text"), args[0]);
      }
      s1 = gp_ws_text_owned(args[0], &len);
      if (!s1) {
        gp_ws_free_strings(strs, n_strs);
        Pl_Err_Resource(Pl_Create_Atom("memory"));
      }
      strs[n_strs++] = s1;
      req.user_agent = s1;
    }
    lst = cons[1];
  }
  {
    char *url = gp_ws_text_owned(p_url, &len);
    if (!url) {
      gp_ws_free_strings(strs, n_strs);
      Pl_Err_Resource(Pl_Create_Atom("memory"));
    }
    strs[n_strs++] = url;
    req.url = url;
  }
  req.headers = headers;
  req.n_headers = n_headers;

  ws = pl_curl_ws_open(&req, errbuf);
  gp_ws_free_strings(strs, n_strs);
  if (!ws) {
    return gp_throw_error("curl_error", errbuf, "pl_curl_ws_open", 3);
  }
  handle = gp_ws_table_alloc(ws, text_as_atom);
  if (!handle) {
    pl_curl_ws_free(ws);
    Pl_Err_Resource(Pl_Create_Atom("memory"));
  }
  return Pl_Un_Integer_Check(handle, p_ws);
}

PlBool gp_curl_ws_send(PlTerm p_ws, PlTerm p_data)
{
  gp_ws_slot *slot = gp_ws_get_open(p_ws);
  char errbuf[CURL_ERROR_SIZE];
  char *data;
  size_t len = 0;
  int binary = 0;
  int ok;
  int func, arity;
  PlTerm *args = NULL;

  if (Pl_Builtin_Compound(p_data)) {
    args = Pl_Rd_Compound_Check(p_data, &func, &arity);
  }
  if (args && arity == 1 && strcmp(Pl_Atom_Name(func), "binary") == 0) {
    data = gp_ws_bytes_owned(args[0], &len);
    binary = 1;
  } else {
    data = gp_ws_text_owned(p_data, &len);
  }
  if (!data) {
    Pl_Err_Resource(Pl_Create_Atom("memory"));
  }
  ok = pl_curl_ws_send(slot->ws, data, len, binary, errbuf);
  free(data);
  if (!ok) {
    return gp_throw_error("curl_error", errbuf, "pl_curl_ws_send", 2);
  }
  return PL_TRUE;
}

PlBool gp_curl_ws_recv(PlTerm p_ws, PlTerm p_timeout, PlTerm p_msg)
{
  gp_ws_slot *slot = gp_ws_get_open(p_ws);
  long timeout = (long)Pl_Rd_Integer_Check(p_timeout);
  char errbuf[CURL_ERROR_SIZE];
  pl_curl_ws_msg msg;
  PlTerm result;
  PlTerm args[2];

  if (!pl_curl_ws_recv(slot->ws, timeout, &msg, errbuf)) {
    return gp_throw_error("curl_error", errbuf, "pl_curl_ws_recv", 3);
  }
  switch (msg.kind) {
    case PL_CURL_WS_TEXT:
      args[0] = slot->text_as_atom ? Pl_Mk_Atom(Pl_Create_Allocate_Atom(msg.data))
                                   : gp_ws_mk_codes(msg.data, msg.len);
      result = Pl_Mk_Compound(Pl_Create_Atom("text"), 1, args);
      break;
    case PL_CURL_WS_BINARY:
      args[0] = gp_ws_mk_codes(msg.data, msg.len);
      result = Pl_Mk_Compound(Pl_Create_Atom("binary"), 1, args);
      break;
    case PL_CURL_WS_CLOSE:
      args[0] = Pl_Mk_Integer(msg.close_code);
      args[1] = Pl_Mk_Atom(Pl_Create_Allocate_Atom(msg.data));
      result = Pl_Mk_Compound(Pl_Create_Atom("close"), 2, args);
      break;
    case PL_CURL_WS_TIMEOUT:
    default:
      result = Pl_Mk_Atom(Pl_Create_Atom("timeout"));
      break;
  }
  pl_curl_ws_msg_free(&msg);
  return Pl_Unif(result, p_msg);
}

PlBool gp_curl_ws_close(PlTerm p_ws)
{
  gp_ws_slot *slot = gp_ws_get_open(p_ws);

  pl_curl_ws_free(slot->ws);
  slot->ws = NULL;
  return PL_TRUE;
}
