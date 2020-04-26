/*   Prolog Interface to standard POSIX regexp
 *   Copyright (C) 1999-2020  Alexander Diemand
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

#include "SWI-Prolog.h"
#include <regex.h>

/* Prototypes */

/* returns TRUE when matched */
/* res is a list of the subexpressions that matched or an empty list */
foreign_t swi_regexp(term_t str, term_t pattern, term_t res);

#define PLException(msg, who)                                                              \
	{                                                                                      \
		term_t except = PL_new_term_ref();                                                 \
		PL_unify_term(except, PL_FUNCTOR_CHARS, "error", 2, PL_CHARS, msg, PL_CHARS, who); \
		return PL_raise_exception(except);                                                 \
	}

install_t install()
{
	PL_register_foreign("pl_regexp", 3, swi_regexp, 0);
}

foreign_t swi_regexp(term_t p_str, term_t p_pattern, term_t p_res)
{

	if (!PL_is_variable(p_res))
	{
		PL_fail;
	}
	if (PL_is_variable(p_str) || PL_is_variable(p_pattern))
	{
		PLException("input uninstantiated", "pl_regexp/3");
		PL_fail;
	}

	char *str;
	char *pattern;
	int sub_exp, reg_res;
	regex_t *reg_comp;
	regmatch_t *reg_matches;
	char errbuf[256];

	PL_get_chars(p_str, &str, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);
	PL_get_chars(p_pattern, &pattern, CVT_ATOM | CVT_STRING | CVT_LIST | BUF_RING);

	reg_comp = (regex_t *)malloc(sizeof(regex_t));
	if ((reg_res = regcomp(reg_comp, pattern, REG_EXTENDED)) != 0)
	{
		strcpy(errbuf, "Compilation of regex failed.    ");
		regerror(reg_res, reg_comp, errbuf + 30, 256 - 30);
		PLException(errbuf, "pl_regexp/3");
		PL_fail;
	}

	sub_exp = reg_comp->re_nsub;
	if (sub_exp > 0)
	{
		reg_matches = (regmatch_t *)malloc((sub_exp + 1) * sizeof(regmatch_t));
	}
	else
	{
		reg_matches = NULL;
	}

	if ((reg_res = regexec(reg_comp, str,
						   sub_exp > 0 ? sub_exp + 1 : 0, /* pass +1 if at least 1 */
						   reg_matches, 0)) != 0)
	{
		regfree(reg_comp);
		if (reg_matches)
		{
			free(reg_matches);
		}
		if (reg_res != REG_NOMATCH)
		{
			strcpy(errbuf, "Execution of regex terminated with error.    ");
			regerror(reg_res, reg_comp, errbuf + 43, 256 - 43);
			PLException(errbuf, "pl_regexp/3");
			PL_fail;
		}
		PL_fail;
	}

	term_t val = PL_new_term_ref();
	term_t lst = PL_copy_term_ref(p_res);

	char *buffer = (char *)malloc((strlen(str) + 1) * sizeof(char));
	int i;
	/* make list of matches */
	if (sub_exp > 0)
	{
		for (i = 0; i <= sub_exp; i++)
		{
			PL_unify_list(lst, val, lst);

			strncpy(buffer,
					str + reg_matches[i].rm_so,
					reg_matches[i].rm_eo - reg_matches[i].rm_so);
			buffer[reg_matches[i].rm_eo - reg_matches[i].rm_so] = '\0';
			PL_unify_atom_chars(val, buffer);
		}
	}
	if (reg_matches)
	{
		free(reg_matches);
	}
	if (buffer)
	{
		free(buffer);
	}

	regfree(reg_comp);
	return PL_unify_nil(lst);
}
