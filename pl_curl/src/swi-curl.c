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
#include "curl_core.h"

/* pl_curl_get(+URL, +Options, -Status, -Headers, -Body)
 * see gp-curl.pl / README.md for the meaning of Options.
 */

foreign_t swi_curl_get(term_t p_url, term_t p_opts, term_t p_status,
                        term_t p_headers, term_t p_body);

#define PLException(msg, who)                                                         \
	{                                                                                  \
		term_t except = PL_new_term_ref();                                            \
		PL_unify_term(except, PL_FUNCTOR_CHARS, "error", 2, PL_CHARS, msg, PL_CHARS, who); \
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
	char *url;

	if (!PL_get_chars(p_url, &url, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING)) {
		PLException("URL uninstantiated", "pl_curl_get/5");
	}

	memset(&req, 0, sizeof(req));
	req.follow_redirect = 1;
	req.ssl_verify = 1;
	req.url = url;

	while (PL_get_list(lst, head, lst)) {
		atom_t name;
		size_t arity;
		term_t a1 = PL_new_term_ref();
		term_t a2 = PL_new_term_ref();
		const char *fname;
		char *s1, *s2;
		int iv;

		if (!PL_get_name_arity(head, &name, &arity)) {
			continue;
		}
		fname = PL_atom_chars(name);

		if (arity == 2 && strcmp(fname, "param") == 0 && n_params < 64) {
			PL_get_arg(1, head, a1);
			PL_get_arg(2, head, a2);
			PL_get_chars(a1, &s1, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			PL_get_chars(a2, &s2, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			params[n_params].name = s1;
			params[n_params].value = s2;
			n_params++;
		} else if (arity == 2 && strcmp(fname, "header") == 0 && n_headers < 64) {
			PL_get_arg(1, head, a1);
			PL_get_arg(2, head, a2);
			PL_get_chars(a1, &s1, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			PL_get_chars(a2, &s2, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			headers[n_headers].name = s1;
			headers[n_headers].value = s2;
			n_headers++;
		} else if (arity == 2 && strcmp(fname, "basic_auth") == 0) {
			PL_get_arg(1, head, a1);
			PL_get_arg(2, head, a2);
			PL_get_chars(a1, &s1, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			PL_get_chars(a2, &s2, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			req.auth_mode = PL_CURL_AUTH_BASIC;
			req.auth_user = s1;
			req.auth_pass = s2;
		} else if (arity == 1 && strcmp(fname, "bearer_auth") == 0) {
			PL_get_arg(1, head, a1);
			PL_get_chars(a1, &s1, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			req.auth_mode = PL_CURL_AUTH_BEARER;
			req.auth_pass = s1;
		} else if (arity == 1 && strcmp(fname, "timeout") == 0) {
			PL_get_arg(1, head, a1);
			PL_get_integer(a1, &iv);
			req.timeout_sec = (long)iv;
		} else if (arity == 1 && strcmp(fname, "connect_timeout") == 0) {
			PL_get_arg(1, head, a1);
			PL_get_integer(a1, &iv);
			req.connect_timeout_sec = (long)iv;
		} else if (arity == 1 && strcmp(fname, "follow_redirect") == 0) {
			PL_get_arg(1, head, a1);
			req.follow_redirect = swi_curl_bool(a1);
		} else if (arity == 1 && strcmp(fname, "ssl_verify") == 0) {
			PL_get_arg(1, head, a1);
			req.ssl_verify = swi_curl_bool(a1);
		} else if (arity == 1 && strcmp(fname, "user_agent") == 0) {
			PL_get_arg(1, head, a1);
			PL_get_chars(a1, &s1, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
			req.user_agent = s1;
		}
	}

	req.params = params;
	req.n_params = n_params;
	req.headers = headers;
	req.n_headers = n_headers;

	if (!pl_curl_get_perform(&req, &resp)) {
		char errmsg[512];
		snprintf(errmsg, sizeof(errmsg), "%s", resp.errbuf);
		PLException(errmsg, "pl_curl_get/5");
	}

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
}
