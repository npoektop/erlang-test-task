#!/bin/sh

echo "--- compiling source code"
erlc encoder.erl

echo "--- running encoder on input file"
erl -run encoder main -run init stop -noshell | sort > output.txt

echo "--- got output"

echo "--- checking difference between output of my encoder and expected output file from the site"
if diff output.txt sorted_expected_output.txt; then
    echo "--- cool. there is no difference. it works!"
fi
