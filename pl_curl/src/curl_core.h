/*   Prolog Interface to libcurl (HTTP)
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

#ifndef PL_CURL_CORE_H
#define PL_CURL_CORE_H

#include <stddef.h>
#include <curl/curl.h>

/* 7.58.0: libcurl no longer forwards a custom Authorization header (bearer_auth)
 * when a redirect goes to another host. Older versions leak the token. */
#define PL_CURL_MIN_VERSION_NUM 0x073A00
#define PL_CURL_MIN_VERSION     "7.58.0"

#if LIBCURL_VERSION_NUM < PL_CURL_MIN_VERSION_NUM
#error "pl_curl needs libcurl >= 7.58.0"
#endif

/* limits applied unless the request overrides them */
#define PL_CURL_DEFAULT_TIMEOUT          300L                 /* seconds, whole transfer */
#define PL_CURL_DEFAULT_CONNECT_TIMEOUT  30L                  /* seconds */
#define PL_CURL_DEFAULT_MAX_BODY         (64L * 1024 * 1024)  /* bytes */
#define PL_CURL_MAX_REDIRS               10L

/* a simple name/value pair, used for both query parameters and headers */
typedef struct {
  char *name;
  char *value;
} pl_curl_kv;

enum pl_curl_auth {
  PL_CURL_AUTH_NONE = 0,
  PL_CURL_AUTH_BASIC = 1,
  PL_CURL_AUTH_BEARER = 2
};

typedef struct {
  const char *url;               /* base URL, without query string */

  pl_curl_kv *params;            /* query parameters, URL-encoded and appended to url */
  int n_params;

  pl_curl_kv *headers;           /* extra request headers */
  int n_headers;

  enum pl_curl_auth auth_mode;
  const char *auth_user;         /* basic: user name   / bearer: unused */
  const char *auth_pass;         /* basic: password     / bearer: token */

  long timeout_sec;              /* <= 0: PL_CURL_DEFAULT_TIMEOUT */
  long connect_timeout_sec;      /* <= 0: PL_CURL_DEFAULT_CONNECT_TIMEOUT */
  long max_body;                 /* max. response body size in bytes, <= 0: PL_CURL_DEFAULT_MAX_BODY */

  int follow_redirect;           /* 1 = follow (default), 0 = do not follow */
  int ssl_verify;                /* 1 = verify (default), 0 = disable verification */

  const char *user_agent;        /* NULL = libcurl default */
} pl_curl_request;

typedef struct {
  long status_code;

  pl_curl_kv *headers;           /* response headers, in order received */
  int n_headers;

  char *body;                    /* response body, NUL-terminated */
  size_t body_len;

  int ok;                        /* 1 on transport success (any HTTP status), 0 on error */
  char errbuf[CURL_ERROR_SIZE];  /* human readable error, valid when ok == 0 */
} pl_curl_response;

/* call once before any request is made (not thread-safe, matches curl_global_init) */
void pl_curl_global_init(void);

/* performs req and fills resp; returns 1 on transport success, 0 on error (see resp->errbuf) */
int pl_curl_get_perform(const pl_curl_request *req, pl_curl_response *resp);

/* releases memory owned by resp */
void pl_curl_response_free(pl_curl_response *resp);


/* WebSockets
 *
 * libcurl's WebSocket API (curl_ws_recv/curl_ws_send) left its experimental
 * state in 8.11.0; before that it was only present in builds that enabled it.
 * Both are checked at run time; with older headers the functions below exist
 * but always fail. */
#define PL_CURL_WS_MIN_VERSION_NUM   0x080B00
#define PL_CURL_WS_MIN_VERSION       "8.11.0"
#define PL_CURL_DEFAULT_MAX_MESSAGE  (16L * 1024 * 1024)  /* bytes */

typedef struct {
  const char *url;               /* ws:// or wss:// URL */

  pl_curl_kv *headers;           /* extra headers for the opening handshake */
  int n_headers;

  long connect_timeout_sec;      /* connect and handshake, <= 0: PL_CURL_DEFAULT_CONNECT_TIMEOUT */
  long max_message;              /* max. size of a received message, <= 0: PL_CURL_DEFAULT_MAX_MESSAGE */
  int ssl_verify;                /* 1 = verify (default), 0 = disable verification */
  const char *user_agent;        /* NULL = libcurl default */
} pl_curl_ws_request;

/* an open connection; owned by the caller until pl_curl_ws_free */
typedef struct pl_curl_ws pl_curl_ws;

enum pl_curl_ws_kind {
  PL_CURL_WS_TEXT = 0,
  PL_CURL_WS_BINARY = 1,
  PL_CURL_WS_CLOSE = 2,          /* the server closed the connection */
  PL_CURL_WS_TIMEOUT = 3         /* no complete message within the timeout */
};

typedef struct {
  enum pl_curl_ws_kind kind;
  char *data;                    /* text/binary payload or close reason, NUL-terminated */
  size_t len;
  int close_code;                /* PL_CURL_WS_CLOSE: status code, 1005 if none was sent */
} pl_curl_ws_msg;

/* connects and performs the opening handshake; returns NULL on error (see errbuf,
 * CURL_ERROR_SIZE bytes) */
pl_curl_ws *pl_curl_ws_open(const pl_curl_ws_request *req, char *errbuf);

/* sends data as one text (binary = 0) or binary (binary = 1) message;
 * returns 1 on success, 0 on error (see errbuf) */
int pl_curl_ws_send(pl_curl_ws *ws, const char *data, size_t len, int binary, char *errbuf);

/* waits up to timeout_ms for the next complete message (fragments are
 * joined; pings are answered by libcurl). A message still incomplete when
 * the time is up is kept for the next call. Returns 1 and fills msg (free it
 * with pl_curl_ws_msg_free), or 0 on error (see errbuf); after an error or a
 * close message the connection is unusable. */
int pl_curl_ws_recv(pl_curl_ws *ws, long timeout_ms, pl_curl_ws_msg *msg, char *errbuf);

void pl_curl_ws_msg_free(pl_curl_ws_msg *msg);

/* 1 while the connection can be used for pl_curl_ws_send / pl_curl_ws_recv */
int pl_curl_ws_usable(const pl_curl_ws *ws);

/* sends a close frame (best effort, unless the connection already failed or
 * was closed by the server) and releases everything */
void pl_curl_ws_free(pl_curl_ws *ws);

#endif /* PL_CURL_CORE_H */
