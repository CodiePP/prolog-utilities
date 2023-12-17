/*-------------------------------------------------------------------------*/
/* Prolog CGI handling                                                     */
/*                                                                         */
/* Part  : CGI Handling                                                    */
/* File  : top-cgi.pl                                                      */
/* Descr.: top REPL entry point                                            */
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

/*
 *   build a new top level:
 *
 *   gplc -o top --new-top-level src/top-cgi.pl libplcgi-${ARCH}.a
 */

 '$info_cgi' :- info_cgi.

 module(cgi, '$info_cgi', [
     init_cgi/0,
     generate_html_output/1,
     generate_html_output/2
     ]).
 