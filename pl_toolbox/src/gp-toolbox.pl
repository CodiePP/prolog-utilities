/*-------------------------------------------------------------------------*/
/* Prolog Toolbox (GNU Prolog library)                                     */
/*                                                                         */
/* Part  : Toolbox main loader                                             */
/* File  : gp-toolbox.pl                                                   */
/* Descr.:                                                                 */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2023 Alexander Diemand                               */
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

:- include('math.pl').
:- include('string.pl').
:- include('stream.pl').
:- include('vector.pl').
:- include('json.pl').

pl_temporary_file(Dir,Prefix,Fpath) :- temporary_file(Dir,Prefix,Fpath).

info_toolbox :-
        info_math,
        info_string,
        info_stream,
        info_vector,
		info_json.

/*
module(toolbox, info_toolbox, [
	% math
		pi/1, e/1, det/2, rad2grad/2, grad2rad/2,
	% stream
		read_txtline/1, read_txtline/2,
		read_binline/1, read_binline/2,
		read_txtuntil/2, read_txtuntil/3,
		read_binuntil/2, read_binuntil/3,
		write_txtline/1, write_txtline/2,
		write_binline/1, write_binline/2,
		read_n_bytes/3, read_n_chars/3,
		read_int_BE/2, read_int_LE/2,
		read_short_BE/2, read_short_LE/2,
		read_double_LE/2,
	% string
		string2list/2, string2list/3,
		split/4,
		remove_leading/3, remove_trailing/3,
		sub_string/4,
		skip/3,
		align_left/3, align_right/3,
		lower_case/2, upper_case/2,
	% vector
		vrand/2, vzero/2, vnorm/2,
		vval/2, vsum/2, vadd/3, vsub/3, vmul/3, vdiv/3,
		vdist/3, vscal/3, vprod/3, vmix/4,
	% json
		from_json/2
	]).
*/
