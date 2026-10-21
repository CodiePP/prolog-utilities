/*-------------------------------------------------------------------------*/
/* Prolog Interface to PostgreSQL                                          */
/*                                                                         */
/* File  : top-pgsql.pl                                                    */
/* Descr.:                                                                 */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2026 Alexander Diemand                               */
/*                                                                         */
/*   This program is free software: you can redistribute it and/or modify  */
/*   it under the terms of the GNU General Public License as published by  */
/*   the Free Software Foundation, either version 3 of the License, or     */
/*   (at your option) any later version.                                   */
/*                                                                         */
/*   This program is distributed in the hope that it will be useful,       */
/*   but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         */
/*   GNU General Public License for more details.                          */
/*                                                                         */
/*   You should have received a copy of the GNU General Public License     */
/*   along with this program.  If not, see <http://www.gnu.org/licenses/>. */
/*-------------------------------------------------------------------------*/

/*
 *   build a new top level:
 *
 *   gplc -o top-pgsql src/top-pgsql.pl libplpgsql-$(uname -s).a -L -lpq
 */

'$info_pgsql' :- info_pgsql.

module(pgsql, '$info_pgsql', [
		pl_pgsql_connect/1,
		pl_pgsql_connect/6,
		pl_pgsql_disconnect/1,
		pl_pgsql_query/2,
		pl_pgsql_query/3,
		pl_pgsql_exec/3,
		pl_pgsql_query_all/3,
		pl_pgsql_query_all/4
	]).
