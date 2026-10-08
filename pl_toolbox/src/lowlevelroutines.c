/*   Prolog Toolbox
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
#include <ctype.h>
#include <errno.h>
#include <limits.h>
#include <unistd.h>
#include <sys/stat.h>

#include "SWI-Prolog.h"

#if PLVERSION < 80000
#error "needs SWI-Prolog >= 8.0"
#endif


foreign_t swi_temporary_file(term_t dir, term_t pfx, term_t fname);


/* Implementation */

install_t install()
{
	//printf("PL_Toolbox V1.0   (C) Alexander Diemand\n");
	PL_register_foreign("pl_temporary_file", 3, swi_temporary_file, 0);
}


foreign_t swi_temporary_file(term_t dir, term_t pfx, term_t fname)
{
	char    path[PATH_MAX];
	char    prefix[6];
	char	*s;
	size_t	dlen,plen;
	struct stat st;
	int	fd;

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

	if (!PL_get_atom_nchars(pfx, &plen, &s))
	{
		PL_fail;
	}
	if (plen > 5)
	{
		plen = 5;
	}
	memcpy(prefix,s,plen);
	prefix[plen]='\0';
	if (strlen(prefix) != plen || strchr(prefix,'/'))
	{
		printf("  Error: prefix must not contain '/' or NUL.\n");
		PL_fail;
	}

	if (!PL_get_atom_nchars(dir, &dlen, &s))
	{
		PL_fail;
	}
	if (dlen == 0 || strlen(s) != dlen)
	{
		printf("  Error: invalid directory path.\n");
		PL_fail;
	}
	if (stat(s, &st) != 0 || !S_ISDIR(st.st_mode))
	{
		printf("  Error: %s is not a directory.\n", s);
		PL_fail;
	}

	/* <dir>/<prefix>XXXXXX; mkstemp creates the file exclusively (O_EXCL,
	 * mode 0600), so it can neither follow a planted symlink nor open a file
	 * created by someone else in a shared directory such as /tmp */
	if (snprintf(path, sizeof(path), "%s%s%sXXXXXX", s,
	             s[dlen-1] == '/' ? "" : "/", prefix) >= (int)sizeof(path))
	{
		printf("  Error: directory path too long.\n");
		PL_fail;
	}

	fd = mkstemp(path);
	if (fd < 0)
	{
		printf("  Error: cannot create temporary file in %s: %s\n", s, strerror(errno));
		PL_fail;
	}
	close(fd);
	return PL_unify_atom_chars(fname, path);	// unify and succeed
}
