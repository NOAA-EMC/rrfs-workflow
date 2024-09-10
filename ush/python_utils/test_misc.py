
from ush.python_utils.misc import *

class TestMisc:

    def test_uc(self):
        assert uppercase('s') == 'S'

    def test_lc(self):
        assert lowercase('S') == 's'

    def test_more(self):
        print("howdy!\n")
        print(find_pattern_in_str('.', 's'))
        assert not find_pattern_in_str('.', 's')
