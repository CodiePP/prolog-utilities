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

/* the actual libcurl work, shared between the GNU Prolog and SWI-Prolog
 * bridges. this file has no dependency on either Prolog C interface. */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "curl_core.h"

struct growbuf {
  char *data;
  size_t len;
  size_t cap;
};

static int growbuf_append(struct growbuf *b, const char *ptr, size_t n)
{
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

void pl_curl_global_init(void)
{
  curl_global_init(CURL_GLOBAL_DEFAULT);
}

int pl_curl_get_perform(const pl_curl_request *req, pl_curl_response *resp)
{
  CURL *curl;
  CURLcode rc;
  struct curl_slist *slist = NULL;
  struct growbuf body = { NULL, 0, 0 };
  struct header_acc hacc = { NULL, 0, 0 };
  char *full_url = NULL;
  char authbuf[512];
  int i;

  memset(resp, 0, sizeof(*resp));

  curl = curl_easy_init();
  if (!curl) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "curl_easy_init failed");
    return 0;
  }

  full_url = build_url_with_params(curl, req);
  if (!full_url) {
    snprintf(resp->errbuf, sizeof(resp->errbuf), "out of memory building URL");
    curl_easy_cleanup(curl);
    return 0;
  }

  curl_easy_setopt(curl, CURLOPT_URL, full_url);
  curl_easy_setopt(curl, CURLOPT_HTTPGET, 1L);
  curl_easy_setopt(curl, CURLOPT_ERRORBUFFER, resp->errbuf);
  curl_easy_setopt(curl, CURLOPT_NOSIGNAL, 1L);

  curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, body_write_cb);
  curl_easy_setopt(curl, CURLOPT_WRITEDATA, &body);
  curl_easy_setopt(curl, CURLOPT_HEADERFUNCTION, header_write_cb);
  curl_easy_setopt(curl, CURLOPT_HEADERDATA, &hacc);

  curl_easy_setopt(curl, CURLOPT_FOLLOWLOCATION, req->follow_redirect ? 1L : 0L);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYPEER, req->ssl_verify ? 1L : 0L);
  curl_easy_setopt(curl, CURLOPT_SSL_VERIFYHOST, req->ssl_verify ? 2L : 0L);

  if (req->timeout_sec > 0) {
    curl_easy_setopt(curl, CURLOPT_TIMEOUT, req->timeout_sec);
  }
  if (req->connect_timeout_sec > 0) {
    curl_easy_setopt(curl, CURLOPT_CONNECTTIMEOUT, req->connect_timeout_sec);
  }
  if (req->user_agent) {
    curl_easy_setopt(curl, CURLOPT_USERAGENT, req->user_agent);
  }

  for (i = 0; i < req->n_headers; i++) {
    char linebuf[1024];
    snprintf(linebuf, sizeof(linebuf), "%s: %s", req->headers[i].name, req->headers[i].value);
    slist = curl_slist_append(slist, linebuf);
  }

  switch (req->auth_mode) {
    case PL_CURL_AUTH_BASIC:
      curl_easy_setopt(curl, CURLOPT_HTTPAUTH, (long)CURLAUTH_BASIC);
      snprintf(authbuf, sizeof(authbuf), "%s:%s",
               req->auth_user ? req->auth_user : "",
               req->auth_pass ? req->auth_pass : "");
      curl_easy_setopt(curl, CURLOPT_USERPWD, authbuf);
      break;
    case PL_CURL_AUTH_BEARER: {
      char linebuf[1024];
      snprintf(linebuf, sizeof(linebuf), "Authorization: Bearer %s",
               req->auth_pass ? req->auth_pass : "");
      slist = curl_slist_append(slist, linebuf);
      break;
    }
    case PL_CURL_AUTH_NONE:
    default:
      break;
  }

  if (slist) {
    curl_easy_setopt(curl, CURLOPT_HTTPHEADER, slist);
  }

  rc = curl_easy_perform(curl);

  if (rc != CURLE_OK) {
    if (resp->errbuf[0] == '\0') {
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

  if (slist) {
    curl_slist_free_all(slist);
  }
  curl_easy_cleanup(curl);
  free(full_url);
  free(body.data);
  for (i = 0; i < hacc.n_headers; i++) {
    free(hacc.headers[i].name);
    free(hacc.headers[i].value);
  }
  free(hacc.headers);

  return resp->ok;
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
