#!/bin/bash

cc="zig cc -Wno-unused-command-line-argument"

assert() {
	expected="$1"
	input="$2"

	./out/kleincc "$input" > tmp.s
	$cc -o tmp tmp.s
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


echo ok