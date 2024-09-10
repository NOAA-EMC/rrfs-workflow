
from ush.python_utils.misc import *

class TestMisc:

    def test_uc(self):
        assert uppercase('s') == 'S'

    def test_lc(self):
        assert lowercase('S') == 's'

    def test_find_pattern_in_str(self):
        assert not find_pattern_in_str('.', 's')

    def test_find_pattern_in_fike(self):
        f = open("test_misc.txt", "w")  
        f.write("Hello World from " + f.name) 
        f.close()
        assert not find_pattern_in_file('H', "test_misc.txt")

