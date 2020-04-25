/*   Prolog Toolbox
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
#include <ctype.h>

#include <SWI-Prolog.h>


foreign_t swi_temporary_file(term_t dir, term_t pfx, term_t fname);


/* Implementation */

install_t install()
{
	//printf("PL_Toolbox V1.0   (C) Alexander Diemand\n");
	PL_register_foreign("pl_temporary_file", 3, swi_temporary_file, 0);
}


foreign_t swi_temporary_file(term_t dir, term_t pfx, term_t fname)
{
	char    sdir[256];
	char    prefix[6];
	char	*s;
	int	dlen,plen;
	char    *realname;

	if (! PL_is_variable(fname))
	{
		printf("  Error: fname should be a variable.\n");
		PL_fail;
	}
	if (! PL_is_atom(dir))
	{
		printf("  Error: dir path should be an atom.\n");
		PL_fail;
	}
	if (! PL_is_atom(pfx))
	{
		printf("  Error: prefix should be an atom.\n");
		PL_fail;
	}

	PL_get_atom_nchars(dir, &dlen, &s);
	if (dlen > 245)
	{
		printf("  Error: directory path too long.\n");
		PL_fail;
	}
	strncpy(sdir,s,dlen);
	sdir[dlen]='\0';
	PL_get_atom_nchars(pfx, &plen, &s);
	strncpy(prefix,s,5);
	prefix[5]='\0';

	realname = tempnam(sdir,prefix);
	if (realname)
	{
		FILE *fstr = fopen(realname,"w");
		if (fstr)
		{
			fclose(fstr);
			int ret = PL_unify_atom_chars(fname, realname);	// unify and succeed
			free(realname);
			return ret;
		}
		printf("  Error: No temporary name generated.\n");
	}
	printf("  Error: unspecific.\n");
	PL_fail;
}

