/*   Prolog Interface to libcurl (HTTP) -- SWI-Prolog bridge
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

#include "SWI-Prolog.h"

#if PLVERSION < 80000
#error "needs SWI-Prolog >= 8.0"
#endif
#include "curl_core.h"

/* pl_curl_get(+URL, +Options, -Status, -Headers, -Body)
 * see gp-curl.pl / README.md for the meaning of Options.
 */

foreign_t swi_curl_get(term_t p_url, term_t p_opts, term_t p_status,
                        term_t p_headers, term_t p_body);

#define PLException(msg, who)                                                         \
	{                                                                                  \
		term_t except = PL_new_term_ref();                                            \
		if (!PL_unify_term(except, PL_FUNCTOR_CHARS, "error", 2, PL_CHARS, msg, PL_CHARS, who)) \
			return FALSE;                                                             \
		return PL_raise_exception(except);                                            \
	}

install_t install()
{
	pl_curl_global_init();
	PL_register_foreign("pl_curl_get", 5, swi_curl_get, 0);
}

static int swi_curl_bool(term_t t)
{
	char *s;
	if (PL_get_atom_chars(t, &s)) {
		return strcmp(s, "false") != 0;
	}
	return 1;
}

/* Strings taken from the options. They are copied (BUF_MALLOC) because the
 * request may hold more of them than SWI-Prolog's temporary buffers keep
 * alive; all are released by strings_free() before returning to Prolog. */
typedef struct {
	char **v;
	int n;
	int cap;
} swi_curl_strings;

static void strings_free(swi_curl_strings *st)
{
	int i;
	for (i = 0; i < st->n; i++) {
		PL_free(st->v[i]);
	}
	free(st->v);
	st->v = NULL;
	st->n = st->cap = 0;
}

/* converts text (atom, string, code/char list) to a C string owned by st.
 * returns 0 after raising an exception if t is not text or memory runs out */
static int get_text(swi_curl_strings *st, term_t t, char **out)
{
	char *s;

	if (st->n == st->cap) {
		int newcap = st->cap ? st->cap * 2 : 16;
		char **nv = (char **)realloc(st->v, newcap * sizeof(char *));
		if (!nv) {
			return PL_resource_error("memory");
		}
		st->v = nv;
		st->cap = newcap;
	}
	if (!PL_get_chars(t, &s, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_MALLOC)) {
		return PL_type_error("text", t);
	}
	st->v[st->n++] = s;
	*out = s;
	return 1;
}

static int get_seconds(term_t t, long *out)
{
	if (!PL_get_long(t, out)) {
		return PL_type_error("integer", t);
	}
	return 1;
}

foreign_t swi_curl_get(term_t p_url, term_t p_opts, term_t p_status,
                        term_t p_headers, term_t p_body)
{
	pl_curl_request req;
	pl_curl_response resp;
	pl_curl_kv params[64];
	pl_curl_kv headers[64];
	int n_params = 0, n_headers = 0;
	term_t lst = PL_copy_term_ref(p_opts);
	term_t head = PL_new_term_ref();
	term_t a1 = PL_new_term_ref();
	term_t a2 = PL_new_term_ref();
	swi_curl_strings st = { NULL, 0, 0 };
	char *url;

	memset(&req, 0, sizeof(req));
	req.follow_redirect = 1;
	req.ssl_verify = 1;

	if (!get_text(&st, p_url, &url)) {
		goto error;
	}
	req.url = url;

	while (PL_get_list(lst, head, lst)) {
		atom_t name;
		size_t arity;
		const char *fname;
		char *s1, *s2;

		if (!PL_get_name_arity(head, &name, &arity)) {
			continue;
		}
		fname = PL_atom_chars(name);
		if (arity >= 1) {
			_PL_get_arg(1, head, a1);
		}
		if (arity >= 2) {
			_PL_get_arg(2, head, a2);
		}

		if (arity == 2 && strcmp(fname, "param") == 0) {
			if (n_params >= 64) {
				PL_resource_error("curl_params");
				goto error;
			}
			if (!get_text(&st, a1, &s1) || !get_text(&st, a2, &s2)) {
				goto error;
			}
			params[n_params].name = s1;
			params[n_params].value = s2;
			n_params++;
		} else if (arity == 2 && strcmp(fname, "header") == 0) {
			if (n_headers >= 64) {
				PL_resource_error("curl_headers");
				goto error;
			}
			if (!get_text(&st, a1, &s1) || !get_text(&st, a2, &s2)) {
				goto error;
			}
			headers[n_headers].name = s1;
			headers[n_headers].value = s2;
			n_headers++;
		} else if (arity == 2 && strcmp(fname, "basic_auth") == 0) {
			if (!get_text(&st, a1, &s1) || !get_text(&st, a2, &s2)) {
				goto error;
			}
			req.auth_mode = PL_CURL_AUTH_BASIC;
			req.auth_user = s1;
			req.auth_pass = s2;
		} else if (arity == 1 && strcmp(fname, "bearer_auth") == 0) {
			if (!get_text(&st, a1, &s1)) {
				goto error;
			}
			req.auth_mode = PL_CURL_AUTH_BEARER;
			req.auth_pass = s1;
		} else if (arity == 1 && strcmp(fname, "timeout") == 0) {
			if (!get_seconds(a1, &req.timeout_sec)) {
				goto error;
			}
		} else if (arity == 1 && strcmp(fname, "connect_timeout") == 0) {
			if (!get_seconds(a1, &req.connect_timeout_sec)) {
				goto error;
			}
		} else if (arity == 1 && strcmp(fname, "max_body") == 0) {
			if (!PL_get_long(a1, &req.max_body)) {
				PL_type_error("integer", a1);
				goto error;
			}
		} else if (arity == 1 && strcmp(fname, "follow_redirect") == 0) {
			req.follow_redirect = swi_curl_bool(a1);
		} else if (arity == 1 && strcmp(fname, "ssl_verify") == 0) {
			req.ssl_verify = swi_curl_bool(a1);
		} else if (arity == 1 && strcmp(fname, "user_agent") == 0) {
			if (!get_text(&st, a1, &s1)) {
				goto error;
			}
			req.user_agent = s1;
		}
	}
	if (!PL_get_nil(lst)) {
		PL_type_error("list", p_opts);
		goto error;
	}

	req.params = params;
	req.n_params = n_params;
	req.headers = headers;
	req.n_headers = n_headers;

	if (!pl_curl_get_perform(&req, &resp)) {
		char errmsg[512];
		snprintf(errmsg, sizeof(errmsg), "%s", resp.errbuf);
		strings_free(&st);
		PLException(errmsg, "pl_curl_get/5");
	}
	strings_free(&st);

	{
		term_t hlst = PL_copy_term_ref(p_headers);
		term_t hval = PL_new_term_ref();
		int i;
		int ok = 1;

		for (i = 0; i < resp.n_headers && ok; i++) {
			term_t k = PL_new_term_ref();
			term_t v = PL_new_term_ref();
			ok = ok && PL_unify_list(hlst, hval, hlst);
			ok = ok && PL_put_atom_chars(k, resp.headers[i].name);
			ok = ok && PL_put_atom_chars(v, resp.headers[i].value);
			ok = ok && PL_unify_term(hval, PL_FUNCTOR_CHARS, "-", 2,
			                          PL_TERM, k, PL_TERM, v);
		}
		ok = ok && PL_unify_nil(hlst);

		ok = ok && PL_unify_integer(p_status, resp.status_code);
		ok = ok && PL_unify_atom_chars(p_body, resp.body ? resp.body : "");

		pl_curl_response_free(&resp);

		if (!ok) {
			PL_fail;
		}
	}

	PL_succeed;

error:
	strings_free(&st);
	return FALSE;
}
