/*   Prolog Interface to libcurl (HTTP)
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

#ifndef PL_CURL_CORE_H
#define PL_CURL_CORE_H

#include <stddef.h>
#include <curl/curl.h>

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

  long timeout_sec;              /* 0 = libcurl default (no timeout) */
  long connect_timeout_sec;      /* 0 = libcurl default */

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

#endif /* PL_CURL_CORE_H */
