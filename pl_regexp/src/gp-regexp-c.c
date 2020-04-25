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

#include "gprolog.h"
#include <regex.h>

/* Prototypes */

/* returns TRUE when matched */
/* res is a list of the subexpressions that matched or an empty list */
PlBool pl_regexp(char *str, char *pattern, PlTerm p_res)
{
  PlTerm vals[1];
  vals[0] = Pl_Mk_String(str);
  return Pl_Un_Proper_List_Check(1, vals, p_res);
}
/*
  int sub_exp, reg_res;
  regex_t *reg_comp;
  regmatch_t *reg_matches;
  char errbuf[256];

  reg_comp = (regex_t *)malloc(sizeof(regex_t));
  if ((reg_res = regcomp(reg_comp, pattern, REG_EXTENDED)) != 0)
  {
    strcpy(errbuf, "Compilation of regex failed.    ");
    regerror(reg_res, reg_comp, errbuf + 30, 256 - 30);
    regfree(reg_comp);
    PlTerm exc = Pl_Mk_String(errbuf);
    Pl_Throw(exc);
    return PL_FALSE;
  }

  sub_exp = reg_comp->re_nsub;
  if (sub_exp > 0) {
    reg_matches = (regmatch_t *)malloc((sub_exp + 1) * sizeof(regmatch_t));
  } else {
    reg_matches = NULL;
  }

  if ((reg_res = regexec(reg_comp, str,
                         sub_exp > 0 ? sub_exp + 1 : 0, // pass +1 if at least 1
                         reg_matches, 0)) != 0)
  {
    if (reg_matches) {
      free(reg_matches);
    }
    if (reg_res != REG_NOMATCH) {
      strcpy(errbuf, "Execution of regex terminated with error.    ");
      regerror(reg_res, reg_comp, errbuf + 43, 256 - 43);
      regfree(reg_comp);
      PlTerm exc = Pl_Mk_String(errbuf);
      Pl_Throw(exc);
      return PL_FALSE;
    } else {
      regfree(reg_comp);
    }
    return PL_FALSE;
  }

  PlTerm vals[sub_exp+1];
  char *buffer = (char *)malloc((strlen(str) + 1) * sizeof(char));
  int i;
  // make list of matches
  for (i = 0; i < sub_exp; i++) {
    strncpy(buffer,
            str + reg_matches[i].rm_so,
            reg_matches[i].rm_eo - reg_matches[i].rm_so);
    buffer[reg_matches[i].rm_eo - reg_matches[i].rm_so] = '\0';
    vals[i] = Pl_Mk_String(buffer);
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
  return Pl_Un_Proper_List_Check(sub_exp, vals, p_res);
  */
