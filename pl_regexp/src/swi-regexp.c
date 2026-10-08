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
#include <stdlib.h>
#include <string.h>

#include "SWI-Prolog.h"

#if PLVERSION < 80000
#error "needs SWI-Prolog >= 8.0"
#endif
#include <regex.h>

/* pl_regexp(+String, +Pattern, -Matches)
 *
 * Matches String against the POSIX extended regular expression Pattern.
 * On success, Matches is [Whole, Group1, ..., GroupN]: the matched part of
 * String followed by one element per parenthesised group ('' for a group
 * that did not take part in the match). Fails if there is no match; raises
 * error(Message, 'pl_regexp/3') if Pattern is invalid.
 * The GNU Prolog bridge (gp-regexp-c.c) implements the same contract.
 */
foreign_t swi_regexp(term_t str, term_t pattern, term_t res);

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
	PL_register_foreign("pl_regexp", 3, swi_regexp, 0);
}

/* "<prefix><regerror message>" into errbuf */
static void regexp_error(char *errbuf, size_t size, const char *prefix, int code, const regex_t *reg)
{
	size_t n = (size_t)snprintf(errbuf, size, "%s", prefix);
	if (n < size)
	{
		regerror(code, reg, errbuf + n, size - n);
	}
}

foreign_t swi_regexp(term_t p_str, term_t p_pattern, term_t p_res)
{
	char *str;
	char *pattern;
	int reg_res;
	size_t nmatch, i;
	regex_t reg_comp;
	regmatch_t *reg_matches;
	char errbuf[256];
	term_t val, lst;
	int ok = TRUE;

	if (PL_is_variable(p_str) || PL_is_variable(p_pattern))
	{
		return PL_instantiation_error(PL_is_variable(p_str) ? p_str : p_pattern);
	}

	/* BUF_STACK: str must stay valid while pattern is converted */
	if (!PL_get_chars(p_str, &str, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK))
	{
		return PL_type_error("text", p_str);
	}
	if (!PL_get_chars(p_pattern, &pattern, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_STACK))
	{
		return PL_type_error("text", p_pattern);
	}

	if ((reg_res = regcomp(&reg_comp, pattern, REG_EXTENDED)) != 0)
	{
		regexp_error(errbuf, sizeof(errbuf), "", reg_res, &reg_comp);
		PLException("syntax_error", errbuf, "pl_regexp/3");
	}

	nmatch = reg_comp.re_nsub + 1;	/* whole match + groups */
	reg_matches = (regmatch_t *)malloc(nmatch * sizeof(regmatch_t));
	if (!reg_matches)
	{
		regfree(&reg_comp);
		return PL_resource_error("memory");
	}

	if ((reg_res = regexec(&reg_comp, str, nmatch, reg_matches, 0)) != 0)
	{
		if (reg_res != REG_NOMATCH)
		{
			regexp_error(errbuf, sizeof(errbuf), "", reg_res, &reg_comp);
		}
		free(reg_matches);
		regfree(&reg_comp);
		if (reg_res != REG_NOMATCH)
		{
			PLException("regex_error", errbuf, "pl_regexp/3");
		}
		PL_fail;
	}

	/* make list of matches */
	val = PL_new_term_ref();
	lst = PL_copy_term_ref(p_res);
	for (i = 0; i < nmatch && ok; i++)
	{
		regoff_t so = reg_matches[i].rm_so;
		regoff_t eo = reg_matches[i].rm_eo;

		ok = PL_unify_list(lst, val, lst) &&
		     (so < 0 ? PL_unify_atom_chars(val, "")
		             : PL_unify_atom_nchars(val, (size_t)(eo - so), str + so));
	}

	free(reg_matches);
	regfree(&reg_comp);
	return ok && PL_unify_nil(lst);
}
