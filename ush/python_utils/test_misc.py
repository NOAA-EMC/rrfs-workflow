
from ush.python_utils.misc import uppercase

class TestMisc:

    def test_uc(self):
        assert uppercase('s') == 'S'

    def test_lc(self):
        assert lowercase('S') == 's'
