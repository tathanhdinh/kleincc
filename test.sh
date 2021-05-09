#!/bin/bash

cc="zig cc -Wno-unused-command-line-argument"
asm="nasm -felf64"

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.asm
	$asm tmp.asm -o tmp.o
	$cc tmp.o -o tmp
	./tmp
	actual="$?"

	if [ "$actual" = "$expected" ]; then
		echo "$input => $actual"
	else
		echo "$input => $expected expected, but got $actual"
		exit 1
	fi
}

assert 7 7
assert 45 45
assert 5   '3-4+7-1'
assert 41  ' 12 + 34 - 5 '
assert 11  ' 34 - 7-16 '
assert 35  '19 + 8 *2'
assert 220 '20 * (5 + 6)'
assert 4   '(3+5)/2'
assert 92 '2 *(5+ 6 * 8 - 7)'
assert 10 '- - +10'
assert 14 '10 -- +4'

assert 0 '0==1'
assert 1 '42==42'
assert 1 '0!=1'
assert 0 '42!=42'

assert 1 '0<1'
assert 0 '1<1'
assert 0 '2<1'
assert 1 '0<=1'
assert 1 '1<=1'
assert 0 '2<=1'

assert 1 '1>0'
assert 0 '1>1'
assert 0 '1>2'
assert 1 '1>=0'
assert 1 '1>=1'
assert 0 '1>=2'
assert 1 '30 < (24 + 9)'
assert 1 '37 == (18 + 20 - 1)'
assert 0 '90 <= (+73 - 22 - 50)'
assert 0 '42 == (-33 + 51 - 4)'
assert 0 '(19 + 27) > (+28 --18)'
assert 0 '(33- 44 +++55) > (70-90+130)'
assert 1 '((1+2+3+4) - (4+3+2+1)) == 0)'

echo ok