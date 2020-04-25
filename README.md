
Prolog utilities
================


[pl_toolbox](pl_toolbox)
----------

```
 ?- toolbox:info_math.
Prolog Toolbox, Mathematical Functors
pi(X)                       X is 3.14169....
e(X)                        X is 2.71828....
det([[X1,X2][Y1,Y2]],D)     D is the determinant
rad2grad(R,G)               G=R/180*PI
grad2rad(G,R)               R=G*180/PI
```

```
 ?- toolbox:info_vector.
Prolog Toolbox, Vector Arithmetic
vrand(N,V)                  vector containing N random numbers
vzero(N,V)                  vector containing N dimensions, all zero
vnorm(V,Vnorm)              Vnorm = V / |V|
vval(V,Value)               Value = |V|
vsum(V,Value)               Value = Sigma(V)
vadd(V1,V2,Vres)            Vres = V1 + V2
vsub(V1,V2,Vres)            Vres = V2 - V1
vmul(Konst,V,Vres)          Vres = Konst * V
vdiv(Konst,V,Vres)          Vres = V / Konst
vdist(V1,V2,Distance)       Distance = |V1 - V2|
vscal(V1,V2,Product)        Product = V1 * V2
vprod(V1,V2,Vres)           Vres = V1 x V2
vmix(V1,V2,V3,Res)          Res = (V1 x V2) * V3
```

```
 ?- toolbox:info_string.
Prolog Toolbox, String handling
removesublist(ListIn,SubL,ListOut) Removes all occurencies of SubL in ListIn
sub_string(Str,From,To,Res)        extracts substring From position To from Str
list2string(List,String)           makes a string from a list separated by " "
list2string(List,Sep,String)       makes a string from a list separated by Sep
string2list(String,Lres)           makes a list of tokens from string by " "
string2list(String,Sep,Lres)       makes a list of tokens from string by Sep
split(Str,Char,Res1,Res2)          splits at first Char into Res1 and rest to Res2
remove_leading(Str,Char,Res)       removes leading Chars from Str, always true
remove_trailing(Str,Char,Res)      removes trailing Chars from Str, always true
skip(Str,Num,Res)                  skips Num chars in Str and returns as Res
align_left(Str,Width,Res)          aligns Str to the left, appends spaces
align_right(Str,Width,Res)         aligns Str to the right, fills with spaces
lower_case(Str,LowerS)             changes Str to lowercase
upper_case(Str,UpperS)             changes Str to uppercase
```

```
 ?- toolbox:info_stream.
Prolog Toolbox, Stream handling
read_txtline(String)             reads a line from the current text Stream into String
read_txtline(Stream,String)      reads a line from a text Stream into String
read_binline(Stream,String)      reads a line from a binary Stream into String
read_txtuntil(Sep,String)        reads a line from the current text Stream into String until Sep occurs
read_txtuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs
read_binuntil(Stream,Sep,String) reads a line from a text Stream into String until Sep occurs
write_txtline(String)            writes a string to the current text stream.
write_txtline(Stream,String)     writes a string to the text stream.
write_binline(Stream,String)     writes a string to the binary stream.
read_n_bytes(Stream,N,Res)       reads up to N bytes from the binary Stream.
read_n_chars(Stream,N,Res)       reads up to N chars from the text Stream.
read_int_[BE|LE](Stream,Int)     reads a 32 bit integer from the binary Stream.
read_short_[BE|LE](Stream,Int)   reads a 16 bit integer from the binary Stream.
read_double_[BE|LE](Stream,Res)  reads a double in ieee extended format from the binary Stream.
```

[pl_regexp](pl_regexp)
---------


[pl_cgi](pl_cgi)
------


[pl_postgresql](pl_postgresql/)
-------------




Licensed under [GPL v3](LICENSE)

Copyright (c) 1999-2020 Alexander Diemand
