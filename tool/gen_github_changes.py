#!/bin/python
"""Generates a changes file for the GitHub CLI release creation. This is
necessary because the global CHANGELOG.md file contains the history of all
releases, but GitHub CLI needs a file with only the changes in the version
at hand.

Call with the following command line arguments:
- name of global changelog file
- name of target changelog file
- name of version that should be taken from the global and written to the target
"""

import sys


def run_conversion():
    if len(sys.argv) < 4:
        print('Call with parameters for the source and target files, as well as version.')
        return

    src = open(sys.argv[1], 'r').readlines()
    target_file = open(sys.argv[2], 'w')
    version = sys.argv[3]

    for line in src:
        if line.startswith('# ' + version):
            do_output = True
        elif line.startswith('# '):
            do_output = False
        if do_output:
            target_file.write(line)


if __name__ == "__main__":
    run_conversion()
