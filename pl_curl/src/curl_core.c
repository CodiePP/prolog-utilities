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

/* the actual libcurl work, shared between the GNU Prolog and SWI-Prolog
 * bridges. this file has no dependency on either Prolog C interface. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

#include "curl_core.h"

struct growbuf {
  char *data;
  size_t len;
  size_t cap;
  size_t max;      /* 0 = unlimited */
  int too_big;     /* set when an append would exceed max */
};

static int growbuf_append(struct growbuf *b, const char *ptr, size_t n)
{
  if (b->max && b->len + n > b->max) {
    b->too_big = 1;
    return 0;
  }
  if (b->len + n + 1 > b->cap) {
    size_t newcap = b->cap ? b->cap * 2 : 4096;
    char *nd;
    while (newcap < b->len + n + 1) {
      newcap *= 2;
    }
    nd = (char *)realloc(b->data, newcap);
    if (!nd) {
      return 0;
    }
    b->data = nd;
    b->cap = newcap;
  }
  memcpy(b->data + b->len, ptr, n);
  b->len += n;
  b->data[b->len] = '\0';
  return 1;
}

static size_t body_write_cb(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  size_t n = size * nmemb;
  if (!growbuf_append((struct growbuf *)userdata, ptr, n)) {
    return 0; /* signals error to libcurl */
  }
  return n;
}

struct header_acc {
  pl_curl_kv *headers;
  int n_headers;
  int cap;
};

static void header_acc_add(struct header_acc *acc, const char *name, size_t nlen,
                            const char *value, size_t vlen)
{
  pl_curl_kv *kv;
  if (acc->n_headers == acc->cap) {
    int newcap = acc->cap ? acc->cap * 2 : 8;
    pl_curl_kv *nk = (pl_curl_kv *)realloc(acc->headers, newcap * sizeof(pl_curl_kv));
    if (!nk) {
      return;
    }
    acc->headers = nk;
    acc->cap = newcap;
  }
  kv = &acc->headers[acc->n_headers];
  kv->name = (char *)malloc(nlen + 1);
  kv->value = (char *)malloc(vlen + 1);
  if (!kv->name || !kv->value) {
    free(kv->name);
    free(kv->value);
    return;
  }
  memcpy(kv->name, name, nlen);
  kv->name[nlen] = '\0';
  memcpy(kv->value, value, vlen);
  kv->value[vlen] = '\0';
  acc->n_headers++;
}

static size_t header_write_cb(char *ptr, size_t size, size_t nmemb, void *userdata)
{
  size_t n = size * nmemb;
  struct header_acc *acc = (struct header_acc *)userdata;
  const char *colon;
  const char *vstart;
  const char *vend;
  const char *lend = ptr + n;

  /* skip the status line ("HTTP/1.1 200 OK") and blank/continuation lines */
  if (n < 2 || (n == 2 && ptr[0] == '\r' && ptr[1] == '\n')) {
    return n;
  }
  if (strncmp(ptr, "HTTP/", 5) == 0) {
    return n;
  }

  colon = memchr(ptr, ':', n);
  if (!colon) {
    return n;
  }

  vstart = colon + 1;
  while (vstart < lend && (*vstart == ' ' || *vstart == '\t')) {
    vstart++;
  }
  vend = lend;
  while (vend > vstart && (vend[-1] == '\r' || vend[-1] == '\n')) {
    vend--;
  }

  header_acc_add(acc, ptr, (size_t)(colon - ptr), vstart, (size_t)(vend - vstart));
  return n;
}

static char *build_url_with_params(CURL *curl, const pl_curl_request *req)
{
  size_t base_len = strlen(req->url);
  struct growbuf url;
  int i;

  url.cap = base_len + 1;
  url.len = 0;
  url.max = 0;
  url.too_big = 0;
  url.data = (char *)malloc(url.cap);
  if (!url.data) {
    return NULL;
  }
  url.data[0] = '\0';
  growbuf_append(&url, req->url, base_len);

  for (i = 0; i < req->n_params; i++) {
    char *ekey = curl_easy_escape(curl, req->params[i].name, 0);
    char *eval = curl_easy_escape(curl, req->params[i].value, 0);
    char sep = (i == 0 && !strchr(req->url, '?')) ? '?' : '&';

    if (ekey && eval) {
      growbuf_append(&url, &sep, 1);
      growbuf_append(&url, ekey, strlen(ekey));
      growbuf_append(&url, "=", 1);
      growbuf_append(&url, eval, strlen(eval));
    }
    if (ekey) {
      curl_free(ekey);
    }
    if (eval) {
      curl_free(eval);
    }
  }

  return url.data;
}

/* Keep-alive: every thread keeps one easy handle and reuses it for its
 * requests, so libcurl can reuse open connections (and its DNS and TLS
 * session caches). A handle is never used by two threads at once, which
 * libcurl requires; it is cleaned up when its thread ends. */
static pthread_key_t handle_key;
static pthread_once_t handle_once = PTHREAD_ONCE_INIT;
static int handle_key_ok = 0;

static void handle_free(void *h)
{
  curl_easy_cleanup((CURL *)h);
}

static void handle_key_init(void)
{
  handle_key_ok = pthread_key_create(&handle_key, handle_free) == 0;
}

/* this thread's handle (*cached = 1) or, if it cannot be kept, a new one
 * that the caller must clean up (*cached = 0) */
static CURL *thread_handle(int *cached)
{
  CURL *curl;

  *cached = 0;
  pthread_once(&handle_once, handle_key_init);
  if (handle_key_ok && (curl = (CURL *)pthread_getspecific(handle_key)) != NULL) {
    *cached = 1;
    return curl;
  }
  curl = curl_easy_init();
  if (curl && handle_key_ok && pthread_setspecific(handle_key, curl) == 0) {
    *cached = 1;
  }
  return curl;
}

/* after a request: a cached handle is reset (all options back to their
 * defaults, so no pointer to this request's data remains, but the
 * connections stay open); any other handle is cleaned up */
static void release_handle(CURL *curl, int cached)
{
  if (cached) {
    curl_easy_reset(curl);
  } else {
    curl_easy_cleanup(curl);
  }
}

void pl_curl_global_init(void)
{
  curl_global_init(CURL_GLOBAL_DEFAULT);
}

/* returns "<a><b><c>" in a newly allocated string, NULL if out of memory */
static char *concat3(const char *a, const char *b, const char *c)
{
  size_t la = strlen(a), lb = strlen(b), lc = strlen(c);
  char *r = (char *)malloc(la + lb + lc + 1);
  if (!r) {
    return NULL;
  }
  memcpy(r, a, la);
  memcpy(r + la, b, lb);
  memcpy(r + la + lb, c, lc);
  r[la + lb + lc] = '\0';
  return r;
}

/* CR or LF in a header would let the caller inject further headers */
static int has_crlf(const char *s)
{
  return s && strpbrk(s, "\r\n") != NULL;
}

/* appends "<a><b><c>" to *slist; returns 0 if out of memory */
static int slist_append3(struct curl_slist **slist, const char *a, const char *b, const char *c)
{
  struct curl_slist *nl;
  char *line = concat3(a, b, c);
  if (!line) {
    return 0;
  }
  nl = curl_slist_append(*slist, line);
  free(line);
  if (!nl) {
    return 0;
  }
  *slist = nl;
  return 1;
}

int pl_curl_get_perform(const pl_curl_request *req, pl_curl_response *resp)
{
  CURL *curl;
  CURLcode rc;
  struct curl_slist *slist = NULL;
  struct growbuf body = { NULL, 0, 0, 0, 0 };
  struct header_acc hacc = { NULL, 0, 0 };
  char *full_url = NULL;
  long timeout = req->timeout_sec > 0 ? req->timeout_sec : PL_CURL_DEFAULT_TIMEOUT;
  long connect_timeout = req->connect_timeout_sec > 0 ? req->connect_timeout_sec
                                                      : PL_CURL_DEFAULT_CONNECT_TIMEOUT;
  long max_body = req->max_body > 0 ? req->max_body : PL_CURL_DEFAULT_MAX_BODY;
  int cached;
  int i;

  memset(resp, 0, sizeof(*resp));

  /* the headers may be newer than the library loaded at run time */
  if (curl_version_info(CURLVERSION_NOW)->version_num < PL_CURL_MIN_VERSION_NUM) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "libcurl %s is too old, need >= %s",
             curl_version_info(CURLVERSION_NOW)->version, PL_CURL_MIN_VERSION);
    return 0;
  }

  for (i = 0; i < req->n_headers; i++) {
    if (has_crlf(req->headers[i].name) || has_crlf(req->headers[i].value) ||
        strchr(req->headers[i].name, ':')) {
      snprintf(resp->errbuf, sizeof(resp->errbuf), "invalid header name or value: %s",
               req->headers[i].name);
      return 0;
    }
  }
  if (has_crlf(req->auth_pass) || has_crlf(req->auth_user) || has_crlf(req->user_agent)) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "CR/LF not allowed in credentials or user agent");
    return 0;
  }

  curl = thread_handle(&cached);
  if (!curl) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "curl_easy_init failed");
    return 0;
  }

  full_url = build_url_with_params(curl, req);
  if (!full_url) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "out of memory building URL");
    release_handle(curl, cached);
    return 0;
  }

  body.max = (size_t)max_body;

  curl_easy_setopt(curl, CURLOPT_URL, full_url);
  curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
  curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, resp->errbuf);
  curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

  /* only plain HTTP(S), also when following redirects (no file://, ftp://, ...) */
#if LIBCURL_VERSION_NUM >= 0x075500
  curl_easy_setopt(curl, CURLOPT_PROTOCOLS_STR, "http,https");
  curl_easy_setopt(curl, CURLOPT_REDIR_PROTOCOLS_STR, "http,https");
#else
  curl_easy_setopt(curl, CURLOPT_PROTOCOLS, (long)(CURLPROTO_HTTP | CURLPROTO_HTTPS));
  curl_easy_setopt(curl, CURLOPT_REDIR_PROTOCOLS, (long)(CURLPROTO_HTTP | CURLPROTO_HTTPS));
#endif

  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, body_write_cb);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
  curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_write_cb);
  curl_easy_setopt(curl, CURLOPT_HEADERDATA, &hacc);
  /* rejects early if the server announces a larger body; body_write_cb
   * enforces the limit when it does not */
  curl_easy_setopt(curl, CURLOPT_MAXFILESIZE_LARGE, (curl_off_t)max_body);

  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, req->follow_redirect ? 1L : 0L);
  curl_easy_setopt(curl, CURLOPT_MAXREDIRS, PL_CURL_MAX_REDIRS);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, req->ssl_verify ? 1L : 0L);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, req->ssl_verify ? 2L : 0L);

  curl_easy_setopt(curl, CURLOPT_TIMEOUT, timeout);
  curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, connect_timeout);
  if (req->user_agent) {
    curl_easy_setopt(curl, CURLOPT_USERAGENT, req->user_agent);
  }

  for (i = 0; i < req->n_headers; i++) {
    if (!slist_append3(&slist, req->headers[i].name, ": ", req->headers[i].value)) {
      goto out_of_memory;
    }
  }

  switch (req->auth_mode) {
    case PL_CURL_AUTH_BASIC:
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
      curl_easy_setopt(curl, CURLOPT_USERNAME, req->auth_user ? req->auth_user : "");
      curl_easy_setopt(curl, CURLOPT_PASSWORD, req->auth_pass ? req->auth_pass : "");
      break;
    case PL_CURL_AUTH_BEARER:
      if (!slist_append3(&slist, "Authorization: Bearer ", req->auth_pass ? req->auth_pass : "", "")) {
        goto out_of_memory;
      }
      break;
    case PL_CURL_AUTH_NONE:
    default:
      break;
  }

  if (slist) {
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);
  }

  rc = curl_easy_perform(curl);

  if (rc != CURLE_OK) {
    if (body.too_big || rc == CURLE_FILESIZE_EXCEEDED) {
      snprintf(resp->errbuf, sizeof(resp->errbuf),
               "response body exceeds the limit of %ld bytes", max_body);
    } else if (resp->errbuf[0] == '\0') {
      snprintf(resp->errbuf, sizeof(resp->errbuf), "%s", curl_easy_strerror(rc));
    }
    resp->ok = 0;
  } else {
    long status = 0;
    curl_easy_getinfo(curl, CURLINFO_RESPONSE_CODE, &status);
    resp->status_code = status;
    resp->body = body.data;
    resp->body_len = body.len;
    resp->headers = hacc.headers;
    resp->n_headers = hacc.n_headers;
    resp->ok = 1;
    body.data = NULL; /* ownership transferred to resp */
    hacc.headers = NULL;
    hacc.n_headers = 0;
  }

done:
  release_handle(curl, cached);   /* before freeing what its options point to */
  if (slist) {
    curl_slist_free_all(slist);
  }
  free(full_url);
  free(body.data);
  for (i = 0; i < hacc.n_headers; i++) {
    free(hacc.headers[i].name);
    free(hacc.headers[i].value);
  }
  free(hacc.headers);

  return resp->ok;

out_of_memory:
  snprintf(resp->errbuf, sizeof(resp->errbuf), "out of memory building request headers");
  resp->ok = 0;
  goto done;
}

void pl_curl_response_free(pl_curl_response *resp)
{
  int i;
  for (i = 0; i < resp->n_headers; i++) {
    free(resp->headers[i].name);
    free(resp->headers[i].value);
  }
  free(resp->headers);
  free(resp->body);
  resp->headers = NULL;
  resp->n_headers = 0;
  resp->body = NULL;
  resp->body_len = 0;
}
