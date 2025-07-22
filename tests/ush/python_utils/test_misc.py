
from ush.python_utils.misc import *

class TestMisc:
    """Test the misc.py functions."""            

    def test_uc(self):
        """Test the uppercase() function."""        
        assert uppercase('s') == 'S'

    def test_lc(self):
        """Test the lowercase() function."""        
        assert lowercase('S') == 's'

    def test_find_pattern_in_str(self):
        """Test the find_pattern_in_str() function."""        
        assert not find_pattern_in_str('.', 's')

    def test_find_pattern_in_file(self):
        """Test the find_pattern_in_file() function."""        
        f = open("test_misc.txt", "w")  
        f.write("Hello World from " + f.name) 
        f.close()
        assert not find_pattern_in_file('H', "test_misc.txt")

