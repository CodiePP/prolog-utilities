/*-------------------------------------------------------------------------*/
/* Prolog Toolbox                                                          */
/*                                                                         */
/* Part  : Math                                                            */
/* File  : vector.pl                                                       */
/* Descr.: Vector arithmetic                                               */
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

info_vector :- write('Prolog Toolbox, Vector Arithmetic'),nl,
               info_vrand_2,
               info_vzero_2,
               info_vnorm_2,
               info_vval_2,
               info_vsum_2,
               info_vadd_3,
               info_vsub_3,
               info_vmul_3,
               info_vdiv_3,
               info_vdist_3,
               info_vscal_3,
               info_vprod_3,
               info_vmix_4.


% creates vector with N-dimensions all components are set to zero

                       %                           %
info_vzero_2 :- write('vzero(N,V)                  vector containing N dimensions, all zero'),nl.

vzero(N,V) :-
        '$vzero1'(N,[],V).

'$vzero1'(0,Temp,Temp) :- !. % stop criterion
'$vzero1'(N,Temp,V) :-
        append(Temp,[0],Temp2),
        N2 is N-1,
        '$vzero1'(N2,Temp2,V).


% create vector with N-dimensions all components are set to zero

                       %                           %
info_vrand_2 :- write('vrand(N,V)                  vector containing N random numbers'),nl.

vrand(N,V) :-
        '$vrand1'(N,[],V).

'$vrand1'(0,Temp,Temp) :- !. % stop criterion
'$vrand1'(N,Temp,V) :-
        random(-65536.0,65536.0,R),
        Q is R / 65536.0,
        append(Temp,[Q],Temp2),
        '$vrand1'(N-1,Temp2,V).




% Normalization of V: V/|V|

                       %                           %
info_vnorm_2 :- write('vnorm(V,Vnorm)              Vnorm = V / |V|'),nl.


vnorm(Vin,Vout) :- 
        vlen(Vin,L),
        vdiv(Vin,L,Vout).


% Value of V1  |V1|

                      %                           %
info_vval_2 :- write('vval(V,Value)               Value = |V|'),nl.

vlen(V,L) :-
        '$vlen1'(V,0,L).
'$vlen1'([],Sum,SqrtSum) :- 
        SqrtSum is sqrt(Sum), !.
'$vlen1'([A|V],Sum,L) :-
        Sum2 is Sum+(A*A),
        '$vlen1'(V,Sum2,L).
        
vval(V,L) :- vlen(V,L).


% sum of all components of a vector V

                      %                           %
info_vsum_2 :- write('vsum(V,Value)               Value = Sigma(V)'),nl.

vsum(V,L) :-
        '$vsum1'(V,0.0,L).
'$vsum1'([],Sum,Sum).
'$vsum1'([A|V],Sum,L) :-
        Sum2 is Sum+A,
        '$vsum1'(V,Sum2,L).
        

% Addition V1 + V2

                      %                           %
info_vadd_3 :- write('vadd(V1,V2,Vres)            Vres = V1 + V2'),nl.

vadd([],[],[]) :- !.
vadd([A|V1],[B|V2],[C|Vres]) :-
        vadd(V1,V2,Vres),
        C is A+B.


% Difference V1 - V2

                      %                           %
info_vsub_3 :- write('vsub(V1,V2,Vres)            Vres = V2 - V1'),nl.

vsub([],[],[]) :- !.
vsub([A|V1],[B|V2],[C|Vres]) :-
        vsub(V1,V2,Vres),
        C is B-A.


% Distance |V2 - V1|

                       %                           %
info_vdist_3 :- write('vdist(V1,V2,Distance)       Distance = |V1 - V2|'),nl.

vdist(V1,V2,D) :-
        vsub(V1,V2,V3),
        vlen(V3,D).


% Scalar Product V1 * V2

                       %                           %
info_vscal_3 :- write('vscal(V1,V2,Product)        Product = V1 * V2'),nl.

vscal([],[],[]) :- !.
vscal([A|V1],[B|V2],[C|Vres]) :-
        vscal(V1,V2,Vres),
        C is A*B.


% Vector Multiplication k * V1

                      %                           %
info_vmul_3 :- write('vmul(Konst,V,Vres)          Vres = Konst * V'),nl.

vmul(_,[],[]) :- !.
vmul(K,[A|V],[B|Vres]) :-
        vmul(K,V,Vres),
        B is A*K.


% Vector Division V1 / k

                      %                           %
info_vdiv_3 :- write('vdiv(Konst,V,Vres)          Vres = V / Konst'),nl.

vdiv(_,[],[]) :- !.
vdiv(K,[A|V],[B|Vres]) :-
        K =\= 0,
        vdiv(K,V,Vres),
        B is A/K.


% Vector Product  V1 x V2

                       %                           %
info_vprod_3 :- write('vprod(V1,V2,Vres)           Vres = V1 x V2'),nl.

vprod([X1,Y1,Z1],[X2,Y2,Z2],[Xm,Ym,Zm]) :- det([[Y1,Y2],[Z1,Z2]], Xm),
                                           det([[Z1,Z2],[X1,X2]], Ym),
                                           det([[X1,X2],[Y1,Y2]], Zm).


% Mixed Vector Product V1 * V2 * V3 = (V1 x V2) * V3

                      %                           %
info_vmix_4 :- write('vmix(V1,V2,V3,Res)          Res = (V1 x V2) * V3'),nl.

vmix([X1,Y1,Z1],[X2,Y2,Z2],[X3,Y3,Z3],Res) :-
                        vprod([X1,Y1,Z1],[X2,Y2,Z2],Tt),
                        vscal(Tt,[X3,Y3,Z3],Res).

