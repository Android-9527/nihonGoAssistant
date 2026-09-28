# -*- coding: utf-8 -*-
import io

f = io.open(r'D:\project\nihonAssitant\datapre\26to50data.md', encoding='utf-8')
ls = f.readlines()

def show(a, b, tag):
    print('=== %s (%d-%d) ===' % (tag, a, b))
    for i in range(a - 1, b):
        print('%5d|%s' % (i + 1, ls[i].rstrip()[:75]))

show(2696, 2712, '36课末/37课首')
show(2876, 2894, '37课末/38课首')
show(3074, 3090, '38课末/39课首')
show(3324, 3340, '39课末/40课首')
show(3775, 3791, '41课末/42课首')
show(3926, 3942, '42课末/43课首')
show(4295, 4311, '44课末/45课首')
show(4435, 4451, '45课末/46课首')
show(4855, 4873, '48课末/49课首')
