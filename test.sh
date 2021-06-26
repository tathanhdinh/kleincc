#!/bin/bash

cc="zig cc -Wno-unused-command-line-argument"
asm="nasm -felf64"
link="ld.lld --discard-all --strip-all --pie --entry start"

# cat <<EOF |
clang -xc -c -o tmp2.o - << EOF
int ret3() { return 3; }
int ret5() { return 5; }
int ret19() { return 19; }
int add(int x, int y) { return x+y; }
int sub(int x, int y) { return x-y; }
int mul(int x, int y) { return x*y; }

int add6(int a, int b, int c, int d, int e, int f) {
  return a+b+c+d+e+f;
}
EOF

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.asm
	$asm tmp.asm -o tmp.o
	# $cc tmp.o -o tmp
	$link tmp.o tmp2.o -o tmp
	./tmp
	actual="$?"

	if [ "$actual" = "$expected" ]; then
		echo "$input => $actual"
	else
		echo "$input => $expected expected, but got $actual"
		exit 1
	fi
}

assert 7 'int main() { return 7; }'
assert 45 'int main() { return 45; }'
assert 5 'int main() { return 3-4+7-1;  }'
assert 41 'int main () { return  12 + 34 - 5 ; }'
assert 11 'int main ()  {return 34 - 7-16;}'
assert 35  ' int main() {return  19 + 8 *2;}'
assert 220 '  int main () {return 20 * (5 + 6);}'
assert 4   'int main () {return (3  +5)/2;}'
assert 92 'int  main() {  return 2 *(5+ 6 * 8 - 7);}'
assert 10 '  int   main () {return - - +10;}'
assert 14 'int  main() { return 10 -- +4;}'

assert 0 'int  main()  {   return   0==1;}'
assert 1 ' int main() {return 42==42;}'
assert 1 'int main() {return 0!=1;}'
assert 0 'int  main() {return 42!=42;}'

assert 1 'int  main() {  return 0<1;}'
assert 0 'int main() {return 1<1;}'
assert 0 '  int main() { return 2<1;}'
assert 1 'int   main() { return 0<=1;}'
assert 1 ' int main() {return 1<=1;}'
assert 0 'int main()   {  return 2<=1;}'

assert 1 'int main() { return 1>0;}'
assert 0 'int main() { return 1>1;}'
assert 0 'int main() {   return 1>2;}'
assert 1 ' int  main() {  return 1>=0;}'
assert 1 ' int   main() { return 1>=1;}'
assert 0 'int   main()  {return 1>=2;}'

assert 1 'int main() {return 30 < (24 + 9);}'
assert 1 'int   main() {return 37 == (18 + 20 - 1);}'
assert 0 'int main() {return 90 <= (+73 - 22 - 50);}'
assert 0 '  int main() {return 42 == (-33 + 51 - 4) ;}'
assert 0 'int   main() {return (19 + 27) > (+28 --18); }'
assert 0 'int main() {return (33- 44 +++55) > (70-90+130); }'
assert 1 ' int main() {return ((1+2+3+4) - (4+3+2+1)) == 0;}'
assert 1 ' int main() {return ++3- 4 + 5 > 1 + 1 -+2 ;}'
assert 1 'int main() {return 29- (4 + 2) + (5 -- 3) > 1 + 1 -+2;}'
assert 1 'int main() {return 29++- (2 - 7 + 9) -   (12 -- 3) > 1 + 1 -+2  ;}'

assert 1 'int  main() {return 1; 2; 3;}'
assert 2 ' int  main() {return 11 - 9; 25; +6-7; 1+3+8-5;}'

assert 20 'int main() {return 20; 3; 9 + 12;}'
assert 7 'int main() {12 -+5; return 3 + 4;}'

assert 3 'int main() { int  a= 3; return a;}'
assert 22 'int main() { int a = 31; int b = 9; return a- b;}'

assert 17 'int main() { int foo =  4 + 13; return foo;}'
assert 20 'int main() {int bar33 = 4; int  bar = 16; return bar+bar33;}'
assert 11 'int main() { int  foo = 24; int bar = 13; return foo- bar;}'

assert 3 'int  main() {if (0) return 2; return 3;}'
assert 3 ' int main() {if (1-1) return 2; return 3;}'
assert 2 'int  main() {if (1) return 2; return 3;}'
assert 2 'int    main() {if (2-1) return 2; return 3;}'
assert 11 'int   main() { if (3+4 *9) return 5+6; else return 32;}'
assert 12 'int   main() { 22+ -11; if (5-5) return 6; else return 7+9-4;}'

assert 10 'int main() { int i=0; while(i<10) i=i+1; return i;}'
assert 19 'int   main() { int i = 1; while (i + 1 < 10+9) i = 1 + i; return i+1;}'

assert 3 'int  main() {for (;;) return 3; return 5;}'
assert 55 'int  main() {int i=0; int j=0; for (i=0; i<=10; i=i+1) j=i+j; return j;}'
assert 82 'int   main() {int i = 11; int j = i-9; for(; j < 10; j=j+9) i = i + 71; return i ;}'

assert 3 'int main() {{1; {2;}} return 3;}'
assert 55 ' int main() {int i=0; int  j=0; while(i<=10) {j=i+j; i=i+1;} return j;}'
assert 0 'int main() {int  a=0; int b=1; while (a+b > 0) {a = a - 1;} return 0;}'

assert 3 'int main() {return ret3();}'
assert 5 'int  main() {return ret5();}'
assert 90 'int main() {int i = 089; i = i + 1; return i; return ret19();}'
assert 8 'int  main() {return add(3, 5);}'
assert 2 ' int main() {return sub(5, 3);}'
assert 27 ' int main() {return mul(3+4+5-1-2, 2+1);}'
assert 21 'int  main() {return add6(1,2,3,4,5,6);}'

assert 32 '  int main() { return ret32(); } int ret32() { return 32; }'
assert 7 ' int main() { return add2(3,4); } int add2(int x, int y) { return x+y; }'
assert 1 ' int  main() { return sub2(4,3); } int sub2(int x, int y) { return x-y; }'
assert 55 '  int main() { return fib(9); } int fib(int x) { if (x<=1) return 1; return fib(x-1) + fib(x-2); }'

assert 3 'int  main() { int x=3; return *&x; }'
assert 3 'int main() { int x=3; int *y=&x; int **z=&y; return **z; }'
assert 5 'int main() { int x=3; int y=5; return *(&x+1); }'
assert 3 'int main() { int x=3; int y=5; return *(&y-1); }'
assert 5 'int main() { int x=3; int *y=&x; *y=5; return x; }'
assert 7 'int main() { int x=3; int  y=5; *(&x+1)=7; return y; }'
assert 7 'int main() { int  x=3; int y=5; *(&y-1)=7; return x; }'
assert 2 'int main() { int x=3; return (&x+2)-&x; }'

assert 3 'int main() { int x[2]; int *y=&x; *y=3; return *x; }'
assert 3 'int main() { int x[3]; *x=3; *(x+1)=4; *(x+2)=5; return *x; }'
assert 4 'int main() { int x[3]; *x=3; *(x+1)=4; *(x+2)=5; return *(x+1); }'
assert 5 'int main() { int x[3]; *x=3; *(x+1)=4; *(x+2)=5; return *(x+2); }'

assert 0 'int main() { int x[2][3]; int *y=x; *y=0; return **x; }'
assert 1 'int main() { int x[2][3]; int *y=x; *(y+1)=1; return *(*x+1); }'
assert 2 'int main() { int x[2][3]; int *y=x; *(y+2)=2; return *(*x+2); }'
assert 3 'int main() { int x[2][3]; int *y=x; *(y+3)=3; return **(x+1); }'
assert 4 'int main() { int x[2][3]; int *y=x; *(y+4)=4; return *(*(x+1)+1); }'
assert 5 'int main() { int x[2][3]; int *y=x; *(y+5)=5; return *(*(x+1)+2); }'
assert 6 'int main() { int x[2][3]; int *y=x; *(y+6)=6; return **(x+2); }'

echo ok
