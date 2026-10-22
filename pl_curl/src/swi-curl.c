/*   Prolog Interface to libcurl (HTTP) -- SWI-Prolog bridge
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

#include "SWI-Stream.h"
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
foreign_t swi_curl_ws_open(term_t p_url, term_t p_opts, term_t p_ws);
foreign_t swi_curl_ws_send(term_t p_ws, term_t p_data);
foreign_t swi_curl_ws_recv(term_t p_ws, term_t p_timeout, term_t p_msg);
foreign_t swi_curl_ws_close(term_t p_ws);

/* raises error(Formal(Message), context(Name/Arity, _)); who is "Name/Arity".
 * Trailing white space (libpq/regerror messages end with a newline) is removed. */
static int raise_error(const char *formal, const char *msg, const char *who)
{
	char name[64];
	char text[1024];
	const char *slash = strrchr(who, '/');
	size_t n = slash ? (size_t)(slash - who) : strlen(who);
	term_t ex = PL_new_term_ref();

	if (n >= sizeof(name)) {
		n = sizeof(name) - 1;
	}
	memcpy(name, who, n);
	name[n] = '\0';
	snprintf(text, sizeof(text), "%s", msg);
	for (n = strlen(text); n > 0 && (text[n-1] == '\n' || text[n-1] == '\r' || text[n-1] == ' '); n--) {
		text[n-1] = '\0';
	}
	msg = text;
	if (!PL_unify_term(ex,
	                   PL_FUNCTOR_CHARS, "error", 2,
	                     PL_FUNCTOR_CHARS, formal, 1,
	                       PL_CHARS, msg,
	                     PL_FUNCTOR_CHARS, "context", 2,
	                       PL_FUNCTOR_CHARS, "/", 2,
	                         PL_CHARS, name,
	                         PL_INT, slash ? atoi(slash + 1) : 0,
	                       PL_VARIABLE)) {
		return FALSE;
	}
	return PL_raise_exception(ex);
}

#define PLException(formal, msg, who) return raise_error(formal, msg, who)

install_t install()
{
	pl_curl_global_init();
	PL_register_foreign("pl_curl_get", 5, swi_curl_get, 0);
	PL_register_foreign("pl_curl_ws_open", 3, swi_curl_ws_open, 0);
	PL_register_foreign("pl_curl_ws_send", 2, swi_curl_ws_send, 0);
	PL_register_foreign("pl_curl_ws_recv", 3, swi_curl_ws_recv, 0);
	PL_register_foreign("pl_curl_ws_close", 1, swi_curl_ws_close, 0);
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

/* body_as(atom|string|codes): the Prolog type of the response body */
static int get_body_type(term_t t, int *type)
{
	char *s;

	if (!PL_get_atom_chars(t, &s)) {
		return PL_type_error("atom", t);
	}
	if (strcmp(s, "atom") == 0) {
		*type = PL_ATOM;
	} else if (strcmp(s, "string") == 0) {
		*type = PL_STRING;
	} else if (strcmp(s, "codes") == 0) {
		*type = PL_CODE_LIST;
	} else {
		return PL_domain_error("body_as", t);
	}
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
	int body_type = PL_ATOM;

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
		} else if (arity == 1 && strcmp(fname, "body_as") == 0) {
			if (!get_body_type(a1, &body_type)) {
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
		PLException("curl_error", errmsg, "pl_curl_get/5");
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
		/* explicit length: the body may contain NUL bytes. The bytes are
		 * taken as ISO Latin-1, i.e. each byte becomes one character */
		ok = ok && PL_unify_chars(p_body, body_type, resp.body_len,
		                          resp.body ? resp.body : "");

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



/* WebSockets
 *
 * A connection is handed to Prolog as a blob of type curl_websocket holding a
 * pointer to a swi_curl_ws. pl_curl_ws_close/1 closes the connection and sets
 * ws to NULL; the structure itself is freed when the blob is garbage
 * collected, which also closes a connection that was never closed. A handle
 * used after closing is detected instead of dereferencing freed memory.
 * A connection must not be used by two threads at the same time.
 */

typedef struct {
	pl_curl_ws *ws;		/* NULL once closed */
	int text_type;		/* PL_CODE_LIST, PL_STRING or PL_ATOM: see text_as/1 */
} swi_curl_ws;

static int release_curl_websocket(atom_t a)
{
	swi_curl_ws *h = *(swi_curl_ws **)PL_blob_data(a, NULL, NULL);

	pl_curl_ws_free(h->ws);
	free(h);
	return TRUE;
}

static int write_curl_websocket(IOSTREAM *s, atom_t a, int flags)
{
	swi_curl_ws *h = *(swi_curl_ws **)PL_blob_data(a, NULL, NULL);

	(void)flags;
	Sfprintf(s, "<curl_websocket>(%p%s)", (void *)h, h->ws ? "" : ",closed");
	return TRUE;
}

static PL_blob_t curl_websocket_blob =
{
	.magic   = PL_BLOB_MAGIC,
	.flags   = PL_BLOB_UNIQUE,
	.name    = "curl_websocket",
	.release = release_curl_websocket,
	.write   = write_curl_websocket,
};

/* the handle behind p_ws; raises type_error for anything that is not a
 * WebSocket and existence_error for a closed one */
static int get_open_websocket(term_t p_ws, swi_curl_ws **h)
{
	void *data;
	PL_blob_t *type;

	if (!PL_get_blob(p_ws, &data, NULL, &type) || type != &curl_websocket_blob) {
		return PL_type_error("curl_websocket", p_ws);
	}
	*h = *(swi_curl_ws **)data;
	if (!(*h)->ws) {
		return PL_existence_error("curl_websocket", p_ws);
	}
	return TRUE;
}

/* text_as(codes|string|atom): the Prolog type of a received text message */
static int get_text_type(term_t t, int *type)
{
	char *s;

	if (!PL_get_atom_chars(t, &s)) {
		return PL_type_error("atom", t);
	}
	if (strcmp(s, "codes") == 0) {
		*type = PL_CODE_LIST;
	} else if (strcmp(s, "string") == 0) {
		*type = PL_STRING;
	} else if (strcmp(s, "atom") == 0) {
		*type = PL_ATOM;
	} else {
		return PL_domain_error("text_as", t);
	}
	return 1;
}

foreign_t swi_curl_ws_open(term_t p_url, term_t p_opts, term_t p_ws)
{
	pl_curl_ws_request req;
	pl_curl_kv headers[64];
	int n_headers = 0;
	term_t lst = PL_copy_term_ref(p_opts);
	term_t head = PL_new_term_ref();
	term_t a1 = PL_new_term_ref();
	term_t a2 = PL_new_term_ref();
	swi_curl_strings st = { NULL, 0, 0 };
	char errbuf[CURL_ERROR_SIZE];
	char *url;
	int text_type = PL_CODE_LIST;
	pl_curl_ws *ws;
	swi_curl_ws *h;

	memset(&req, 0, sizeof(req));
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

		if (arity == 2 && strcmp(fname, "header") == 0) {
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
		} else if (arity == 1 && strcmp(fname, "connect_timeout") == 0) {
			if (!get_seconds(a1, &req.connect_timeout_sec)) {
				goto error;
			}
		} else if (arity == 1 && strcmp(fname, "max_message") == 0) {
			if (!PL_get_long(a1, &req.max_message)) {
				PL_type_error("integer", a1);
				goto error;
			}
		} else if (arity == 1 && strcmp(fname, "text_as") == 0) {
			if (!get_text_type(a1, &text_type)) {
				goto error;
			}
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
	req.headers = headers;
	req.n_headers = n_headers;

	ws = pl_curl_ws_open(&req, errbuf);
	strings_free(&st);
	if (!ws) {
		PLException("curl_error", errbuf, "pl_curl_ws_open/3");
	}
	h = (swi_curl_ws *)malloc(sizeof(*h));
	if (!h) {
		pl_curl_ws_free(ws);
		return PL_resource_error("memory");
	}
	h->ws = ws;
	h->text_type = text_type;
	/* if unification fails, garbage collection of the blob closes the connection */
	return PL_unify_blob(p_ws, &h, sizeof(h), &curl_websocket_blob);

error:
	strings_free(&st);
	return FALSE;
}

/* pl_curl_ws_send(+WS, +Data): Data is text (atom, string, code list), sent
 * UTF-8 encoded as a text message, or binary(Bytes) with a list of byte values */
foreign_t swi_curl_ws_send(term_t p_ws, term_t p_data)
{
	swi_curl_ws *h;
	char errbuf[CURL_ERROR_SIZE];
	char *s;
	size_t len;
	int binary = 0;

	if (!get_open_websocket(p_ws, &h)) {
		return FALSE;
	}
	if (PL_is_functor(p_data, PL_new_functor(PL_new_atom("binary"), 1))) {
		term_t bytes = PL_new_term_ref();
		_PL_get_arg(1, p_data, bytes);
		/* each byte value 0..255 becomes one byte */
		if (!PL_get_nchars(bytes, &len, &s, CVT_LIST | REP_ISO_LATIN_1 | CVT_EXCEPTION)) {
			return FALSE;
		}
		binary = 1;
	} else if (!PL_get_nchars(p_data, &len, &s,
	                          CVT_ATOM | CVT_STRING | CVT_LIST | REP_UTF8 | CVT_EXCEPTION)) {
		return FALSE;
	}
	if (!pl_curl_ws_send(h->ws, s, len, binary, errbuf)) {
		PLException("curl_error", errbuf, "pl_curl_ws_send/2");
	}
	PL_succeed;
}

/* pl_curl_ws_recv(+WS, +TimeoutMs, -Msg)
 *   Msg = text(Data) | binary(Bytes) | close(Code, Reason) | timeout
 * Waits in slices so that signals (e.g. Ctrl-C, thread_signal/2) are handled. */
foreign_t swi_curl_ws_recv(term_t p_ws, term_t p_timeout, term_t p_msg)
{
	swi_curl_ws *h;
	char errbuf[CURL_ERROR_SIZE];
	pl_curl_ws_msg msg;
	long timeout;
	int ok;

	if (!get_open_websocket(p_ws, &h)) {
		return FALSE;
	}
	if (!PL_get_long(p_timeout, &timeout)) {
		return PL_type_error("integer", p_timeout);
	}
	for (;;) {
		long slice = timeout > 200 ? 200 : timeout;
		if (!pl_curl_ws_recv(h->ws, slice, &msg, errbuf)) {
			PLException("curl_error", errbuf, "pl_curl_ws_recv/3");
		}
		if (msg.kind != PL_CURL_WS_TIMEOUT || timeout <= 200) {
			break;
		}
		timeout -= 200;
		if (PL_handle_signals() < 0) {
			return FALSE;
		}
	}

	switch (msg.kind) {
	case PL_CURL_WS_TEXT: {
		term_t data = PL_new_term_ref();
		/* text messages are UTF-8 */
		ok = PL_unify_chars(data, h->text_type | REP_UTF8, msg.len, msg.data)
		     && PL_unify_term(p_msg, PL_FUNCTOR_CHARS, "text", 1, PL_TERM, data);
		break;
	}
	case PL_CURL_WS_BINARY: {
		term_t data = PL_new_term_ref();
		ok = PL_unify_chars(data, PL_CODE_LIST | REP_ISO_LATIN_1, msg.len, msg.data)
		     && PL_unify_term(p_msg, PL_FUNCTOR_CHARS, "binary", 1, PL_TERM, data);
		break;
	}
	case PL_CURL_WS_CLOSE: {
		term_t reason = PL_new_term_ref();
		ok = PL_unify_chars(reason, PL_ATOM | REP_UTF8, msg.len, msg.data)
		     && PL_unify_term(p_msg, PL_FUNCTOR_CHARS, "close", 2,
		                      PL_INT, msg.close_code, PL_TERM, reason);
		break;
	}
	case PL_CURL_WS_TIMEOUT:
	default:
		ok = PL_unify_atom_chars(p_msg, "timeout");
		break;
	}
	pl_curl_ws_msg_free(&msg);
	return ok;
}

foreign_t swi_curl_ws_close(term_t p_ws)
{
	swi_curl_ws *h;

	if (!get_open_websocket(p_ws, &h)) {
		return FALSE;
	}
	pl_curl_ws_free(h->ws);
	h->ws = NULL;
	PL_succeed;
}
