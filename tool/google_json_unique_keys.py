"""
Script to identify all unique keys in a Google location history JSON export.
"""
import re;

r = re.compile('\w+');
unique_names = set();
for line in open('Locatiegeschiedenis.json', 'r').readlines():
    m = r.findall(line);
    if len(m) > 0:
        unique_names.add(m[0])

for name in sorted(unique_names):
    print('{} : {}'.format(name, len(name)))

