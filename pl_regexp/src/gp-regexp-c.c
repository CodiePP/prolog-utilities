/*   Prolog Interface to standard POSIX regexp
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
#include <string.h>

#include <stdlib.h>
#include "gprolog.h"

#if !defined(__GPROLOG_VERSION__) || __GPROLOG_VERSION__ < 10400
#error "needs GNU Prolog >= 1.4.0"
#endif
#include <regex.h>

/* pl_regexp(+String, +Pattern, -Matches)
 *
 * Same contract as the SWI-Prolog bridge (swi-regexp.c): String and Pattern
 * are atoms or code lists; on success Matches
 * is [Whole, Group1, ..., GroupN] ('' for a group that did not take part in
 * the match); fails if there is no match; throws
 * error(Message, 'pl_regexp/3') if Pattern is invalid.
 */

/* "<prefix><regerror message>" into errbuf */
static void regexp_error(char *errbuf, size_t size, const char *prefix, int code, const regex_t *reg)
{
  size_t n = (size_t)snprintf(errbuf, size, "%s", prefix);
  if (n < size) {
    regerror(code, reg, errbuf + n, size - n);
  }
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

/* the text of an atom or code list; *owned is set if the result was
 * allocated and must be freed. Throws a type error for anything else. */
static char *regexp_text(PlTerm t, char **owned)
{
  int len;

  *owned = NULL;
  if (Pl_Builtin_Atom(t)) {
    return Pl_Atom_Name(Pl_Rd_Atom_Check(t));
  }
  len = Pl_List_Length(t);
  if (len < 0) {
    return Pl_Rd_Codes_Check(t);   /* throws instantiation/type error */
  }
  *owned = (char *)malloc((size_t)len + 1);
  if (!*owned) {
    return NULL;
  }
  Pl_Rd_Codes_Str_Check(t, *owned);
  return *owned;
}

PlBool pl_regexp(PlTerm p_str, PlTerm p_pattern, PlTerm p_res)
{
  char *str, *pattern, *str_owned, *pattern_owned;
  int reg_res;
  size_t nmatch, i;
  regex_t reg_comp;
  regmatch_t *reg_matches;
  PlTerm *vals;
  char *buffer;
  PlBool ret;
  char errbuf[256];

  str = regexp_text(p_str, &str_owned);
  if (!str) {
    return PL_FALSE;
  }
  pattern = regexp_text(p_pattern, &pattern_owned);
  if (!pattern) {
    free(str_owned);
    return PL_FALSE;
  }

  reg_res = regcomp(&reg_comp, pattern, REG_EXTENDED);
  free(pattern_owned);
  if (reg_res != 0) {
    free(str_owned);
    regexp_error(errbuf, sizeof(errbuf), "", reg_res, &reg_comp);
    return gp_throw_error("syntax_error", errbuf, "pl_regexp", 3);
  }

  nmatch = reg_comp.re_nsub + 1;   /* whole match + groups */
  reg_matches = (regmatch_t *)malloc(nmatch * sizeof(regmatch_t));
  if (!reg_matches) {
    free(str_owned);
    regfree(&reg_comp);
    return PL_FALSE;
  }

  if ((reg_res = regexec(&reg_comp, str, nmatch, reg_matches, 0)) != 0) {
    free(str_owned);
    free(reg_matches);
    if (reg_res != REG_NOMATCH) {
      regexp_error(errbuf, sizeof(errbuf), "", reg_res, &reg_comp);
      regfree(&reg_comp);
      return gp_throw_error("regex_error", errbuf, "pl_regexp", 3);
    }
    regfree(&reg_comp);
    return PL_FALSE;
  }

  vals = (PlTerm *)malloc(nmatch * sizeof(PlTerm));
  buffer = (char *)malloc(strlen(str) + 1);
  if (!vals || !buffer) {
    free(str_owned);
    free(vals);
    free(buffer);
    free(reg_matches);
    regfree(&reg_comp);
    return PL_FALSE;
  }

  // make list of matches
  for (i = 0; i < nmatch; i++) {
    regoff_t so = reg_matches[i].rm_so;
    regoff_t eo = reg_matches[i].rm_eo;
    size_t len = so < 0 ? 0 : (size_t)(eo - so);

    if (len > 0) {
      memcpy(buffer, str + so, len);
    }
    buffer[len] = '\0';
    vals[i] = Pl_Mk_String(buffer);
  }

  ret = Pl_Un_Proper_List_Check((int)nmatch, vals, p_res);

  free(str_owned);
  free(vals);
  free(buffer);
  free(reg_matches);
  regfree(&reg_comp);
  return ret;
}
