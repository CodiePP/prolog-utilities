/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : Math                                                            */
/* File  : math.pl                                                         */
/* Descr.: Mathematical Functors                                           */
/* Author: Alexander Diemand                                               */
/*                                                                         */
/* Copyright (C) 1999-2019 Alexander Diemand                               */
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


info_math :- write('Prolog Toolbox, Mathematical Functors'),nl,
             info_math_const_1,
             info_det_2,
             info_rad2grad_2,
             info_grad2rad_2.

% Constants

                            %                           %
info_math_const_1 :- write('pi(X)                       X is 3.14169....'),nl,
                     write('e(X)                        X is 2.71828....'),nl.

pi(3.14159265358979323846).
e(2.7182818284590452354).


% determinant

                     %                           %
info_det_2 :- write('det([[X1,X2][Y1,Y2]],D)     D is the determinant'),nl.

det([[A1,A2],[B1,B2]],Det) :- Det is A1*B2-A2*B1.
% more will follow


% Converts radiants to degrees

                          %                           %
info_rad2grad_2 :- write('rad2grad(R,G)               G=R/180*PI'),nl.

rad2grad(R,G) :- ( var(R) -> 
                        grad2rad(G,R)
                   ;
                        pi(PI), G is R*180/PI
                 ).


% Converts degrees to radiants

                          %                           %
info_grad2rad_2 :- write('grad2rad(G,R)               R=G*180/PI'),nl.

grad2rad(G,R) :- ( var(G) -> 
                        rad2grad(R,G)
                   ;
                        pi(PI), R is G*PI/180
                 ).

