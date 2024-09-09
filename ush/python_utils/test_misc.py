
import ush.python_utils.misc

class TestMisc:

    def test_uc(self):
        assert uppercase('s') == 'S'

    def test_lc(self):
        assert lowercase('S') == 's'
