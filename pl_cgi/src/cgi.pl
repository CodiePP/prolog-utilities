/*-------------------------------------------------------------------------*/
/* Prolog CGI handling                                                     */
/*                                                                         */
/* Part  : CGI Handling                                                    */
/* File  : cgi.pl                                                          */
/* Descr.: Helps with reading and writing to/from CGI requests             */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2020 Alexander Diemand                               */
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

:- module(cgi, [
        init_cgi/0,
        generate_html_output/1,
        generate_html_output/2
    ]).

% needs read_txtuntil from toolbox
:- use_module(sbcl(toolbox), [read_txtuntil/2]).
:- use_module(sbcl(regexp)).

:- dynamic(cgi_env/2).        % where we store the environment
:- dynamic(cgi_in/2).         % keeps the content of the cgi variables
:- dynamic(cgi_cookies/2).    % keeps the content of the cookies

pl_regexp(A,B,C) :- regexp:pl_regexp(A,B,C).

:- include('common.pl').
