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


/* error(system_error(Message), context(pl_temporary_file/3, _)) */
static int system_error(const char *msg)
{
	term_t ex = PL_new_term_ref();

	if (!PL_unify_term(ex,
	                   PL_FUNCTOR_CHARS, "error", 2,
	                     PL_FUNCTOR_CHARS, "system_error", 1,
	                       PL_CHARS, msg,
	                     PL_FUNCTOR_CHARS, "context", 2,
	                       PL_FUNCTOR_CHARS, "/", 2,
	                         PL_CHARS, "pl_temporary_file",
	                         PL_INT, 3,
	                       PL_VARIABLE)) {
		return FALSE;
	}
	return PL_raise_exception(ex);
}

/* an atom argument: instantiation_error if unbound, type_error otherwise */
static int get_atom_arg(term_t t, size_t *len, char **s)
{
	if (PL_is_variable(t))
	{
		return PL_instantiation_error(t);
	}
	if (!PL_get_atom_nchars(t, len, s))
	{
		return PL_type_error("atom", t);
	}
	return TRUE;
}

/* pl_temporary_file(+Dir, +Prefix, -File): creates a new empty file
 * Dir/<Prefix>XXXXXX (mode 0600) and unifies File with its path.
 * Errors are raised as exceptions (nothing is printed):
 *   existence_error(directory, Dir)                Dir is not a directory
 *   domain_error(temporary_file_prefix, Prefix)    Prefix contains '/'
 *   representation_error(max_path_length)          path too long
 *   permission_error(create, file, Dir)            no write permission
 *   system_error(Message)                          other mkstemp failures */
foreign_t swi_temporary_file(term_t dir, term_t pfx, term_t fname)
{
	char    path[PATH_MAX];
	char    prefix[6];
	char    msg[PATH_MAX + 128];
	char	*s;
	size_t	dlen,plen;
	struct stat st;
	int	fd;

	if (! PL_is_variable(fname))
	{
		return PL_uninstantiation_error(fname);
	}
	if (!get_atom_arg(pfx, &plen, &s))
	{
		return FALSE;
	}
	if (plen > 5)
	{
		plen = 5;
	}
	memcpy(prefix,s,plen);
	prefix[plen]='\0';
	if (strlen(prefix) != plen || strchr(prefix,'/'))
	{
		return PL_domain_error("temporary_file_prefix", pfx);
	}

	if (!get_atom_arg(dir, &dlen, &s))
	{
		return FALSE;
	}
	if (dlen == 0 || strlen(s) != dlen || stat(s, &st) != 0 || !S_ISDIR(st.st_mode))
	{
		return PL_existence_error("directory", dir);
	}

	/* <dir>/<prefix>XXXXXX; mkstemp creates the file exclusively (O_EXCL,
	 * mode 0600), so it can neither follow a planted symlink nor open a file
	 * created by someone else in a shared directory such as /tmp */
	if (snprintf(path, sizeof(path), "%s%s%sXXXXXX", s,
	             s[dlen-1] == '/' ? "" : "/", prefix) >= (int)sizeof(path))
	{
		return PL_representation_error("max_path_length");
	}

	fd = mkstemp(path);
	if (fd < 0)
	{
		if (errno == EACCES || errno == EPERM || errno == EROFS)
		{
			return PL_permission_error("create", "file", dir);
		}
		snprintf(msg, sizeof(msg), "cannot create a temporary file in %s: %s", s, strerror(errno));
		return system_error(msg);
	}
	close(fd);
	return PL_unify_atom_chars(fname, path);	// unify and succeed
}
