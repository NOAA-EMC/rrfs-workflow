'''

This is an interactive script that generates a changelog entry for any changes
implemented to real time RRFS runs. It asks the user a variety of RRFS-specific
questions, interrogates the UFS SRW App and its 1st-level Externals (submodules)
to determine if they are consistent with the code on disk, and generates a log
file with relevant tracking information.

Note: It is important to continue to use this logging script, even for changes
that occur outside the clone, even though those changes will not be captured in
the git information for the log file.

The log file will be appended to those in /misc/whome/rtrr/RRFS/

Requirements:

    Python 3.6+

Conda Environment:

    module use /contrib/miniconda3/modulefiles
    module load miniconda3
    module load regional_workflow

Usage:

    python log_change.py -h

'''

#pylint: disable=invalid-name
import argparse
from collections import OrderedDict
from configparser import ConfigParser
import datetime as dt
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time

LOGFILE_LOC = '/misc/whome/rtrr/RRFS/'
DOMAINS = ['CONUS', 'AK', 'NA3km', 'NA13km', 'RTMA', 'all']

class cd:

    '''Context manager for changing the current working directory'''

    def __init__(self, newPath):
        self.newPath = os.path.expanduser(newPath)

    def __enter__(self):
        self.savedPath = os.getcwd() #pylint: disable=attribute-defined-outside-init
        os.chdir(self.newPath)

    def __exit__(self, etype, value, traceback):
        os.chdir(self.savedPath)

def get_repo_info():

    ''' Get the hashes that are currently checked out in each repository. Report
    on differences between hashes checked out and those in Externals.cfg, as
    well as differences that exist on disk. '''

    repo_info = OrderedDict()

    repos = load_externals()
    repos['ufs-srweather-app'] = {'local_path': './'}

    for repo, config in repos.items():
        if repo != 'externals_description':
            with cd(config.get('local_path', './')):
                summary, code_hash = get_summary()
                config_hash = config.get('hash')
                repo_info[repo] = {
                    'summary': summary,
                    'hash': code_hash,
                    'diffs': get_local_changes(),
                    'hash_diffs': "N/A" if config_hash is None else
                                  not code_hash.startswith(config_hash),
                    }

    return repo_info

def get_local_changes():
    ''' Get differences that are not in the repo. '''
    pipe = subprocess.Popen("git diff", shell=True, stdout=subprocess.PIPE)
    ret = pipe.communicate()[0].decode('utf-8')
    return ret if ret else None

def get_summary():
    ''' Return the results of a git summary, and the hash. '''
    pipe = subprocess.Popen("git show --summary --decorate", shell=True, stdout=subprocess.PIPE)
    summary = pipe.communicate()[0].decode('utf-8')
    return summary, summary.split()[1]

def get_user_info():

    ''' Return a dictionary of user-supplied information. '''

    print('Please provide the following information: ')

    user_questions = OrderedDict({
        'name':
            {'question': "Your name: \n"},
        'changes':
            {'question': "What changed? \n"},
        'components':
            {'question': "What components were affected? (jobs, scripts, " \
                "configuration layer, model configuration, etc.) \n"},
        'first_cycle':
            {'question': "First cycle in effect (YYYYMMDDHH): \n",
             'check': isdate,
            },
        'comparison':
            {'question': "Which runs should this be compared to? \n"},
        'domains':
            {'question': f"Domains affected ({DOMAINS}): \n",
             'check': isdomain,
            },
        'rebuild':
            {'question': "Did you rebuild? (Y/N)\n",
             'check': isbool,
            },
        'reconfigure':
            {'question': "Did you reconfigure? (Y/N)\n",
             'check': isbool,
            },
        'inrepo':
            {'question': "Are your changes in the repo? (Y/N)\n",
             'check': isbool,
            },
        })

    user_info = OrderedDict()
    for info, gather in user_questions.items():
        while not user_info.get(info):
            tmp = input(gather['question'])

            check = gather.get('check')
            if check:
                if not check(tmp):
                    tmp = None

            user_info[info] = tmp

    return user_info

def isbool(string):

    ''' Returns a bool after checking whether the input string meets the
    requirements for a yes/no answer. '''

    while True:
        if len(string) < 1:
            string = input('Please enter a Y/N response! \n')
        else:
            break
    return string.lower()[0] in ['y', 'n']

def isdate(string):

    ''' Returns a bool after checking whether the input string meets the
    requirements for a date string: YYYYMMDDHH. '''

    if len(string) != 10:
        print(f'Must enter cycle in YYYYMMDDHH format!')
        return False

    return True

def isdomain(string):

    ''' Returns a bool after checking whether the input string meets the
    requirements for a domain, or list of domains '''

    string_list = [i.strip("[]\"', ") for i in string.split(',')]
    domains = [d.lower() for d in DOMAINS]
    for s in string_list:
        if s.lower() not in domains:
            print(f'{s} is not a valid domain')
            return False
    return True

def load_externals(ext_path="Externals.cfg"):

    ''' Use configparser to load the Externals.cfg info. Return the dict'''

    config = ConfigParser()
    config.read(ext_path)
    return {i: {i[0]: i[1] for i in config.items(i)} for i in config.sections()}

def log_message():

    ''' Recording a log message for printing or writing to file '''

    # Save the original standard out location
    original = sys.stdout

    # Interact with user
    user_info = get_user_info()
    repos = get_repo_info()

    # Print the results of the user input to a temporary file
    tmp_file = tempfile.NamedTemporaryFile(mode='w', delete=False, dir='.')
    print(f'Saving to a temp file: {tmp_file.name}')

    # Print once to file, and once to screen
    for fn in [tmp_file, original]:
        sys.stdout = fn

        print('*'*80)
        print(f'Logging a change at {dt.datetime.now().strftime("%c")}: ')
        print('*'*80)

        print_dict(user_info)
        print_dict(repos, sep='*')

    return tmp_file

def logit(logfile, tmpfile):

    ''' Cat the temporary file (filename) at the beginning of the main log file.
    '''

    lock_file = f'{logfile}._lock'
    while True:
        if not os.path.exists(lock_file):

            # Open the lock file
            fd = open(lock_file, 'w')

            try:
                # Create a logfile backup just in case. Make it a hidden file.
                # Won't remove this one in the script in case something goes
                # wrong.
                path, fname = os.path.dirname(logfile), os.path.basename(logfile)
                shutil.copy(logfile, os.path.join(path, f".{fname}._bk"))

                # Write the contents of the logfile to the tempfile for reverse
                # cronological order.
                with open(logfile, 'r') as log:
                    for line in log:
                        tmpfile.write(line)
                tmpfile.close()

                # Rename tempfile to logfile
                shutil.move(tmpfile.name, logfile)

                # Set open read permissions
                os.chmod(logfile,
                         stat.S_IWUSR | stat.S_IRUSR | stat.S_IRGRP | stat.S_IROTH,
                         )
            except:
                print('Something went wrong writing the logfile')
                raise
            finally:
                # Close and remove the lock file
                fd.close()
                if os.path.exists(lock_file):
                    os.remove(lock_file)

            break

        # Wait before trying to obtain the lock on the file
        time.sleep(5)

#pylint: disable=inconsistent-return-statements
def print_dict(d, depth=0, sep=None):

    ''' Recurse through dict entries to print them '''

    if not isinstance(d, dict):
        return d

    for key, value in d.items():
        if isinstance(value, dict):
            sep_len = 80 - len(key) - 2
            emphasis = sep * sep_len if sep is not None else ''
            print(f'{key}: {emphasis}')
            print_dict(value, depth+2)
        else:
            print(f'{" "*depth}{key}: {value}')
#pylint: enable=inconsistent-return-statements

def parse_args():

    ''' Parse the command line arguments (cla) '''

    parser = argparse.ArgumentParser(description='Change log generator')

    # Positional argument
    parser.add_argument(
        'dev_name',
        choices=[f'RRFS_dev{n}' for n in range(1, 5)],
        help='The type of graphics to create.',
        )
    return parser.parse_args()

def main(cla):

    ''' Interact with user to get necessary information. '''

    happy = False
    while not happy:

        message_file = log_message()
        while True:
            print('~~~~~~~~ END OF MESSAGE ~~~~~~~~')
            answer = input("Are you happy with the log message? (Y/N) ")

            if not answer:
                print(f'Please enter a Y/N response. ')
            elif answer.lower()[0] == 'y':
                logfile = os.path.join(LOGFILE_LOC, f'{cla.dev_name}.log')
                print(f'Adding your log message to {logfile}')
                logit(logfile, message_file)
                message_file.close()
                happy = True
                break
            elif answer.lower()[0] == 'n':

                kill = input("Type retry to enter new info: ")

                if not kill:
                    message_file.close()
                    sys.exit()
                elif kill.lower()[0] == "r":
                    print()
                    print('~'*80)
                    print(f'Clearing input and starting new log')
                    print('~'*80)
                    print()
                    break
                else:
                    message_file.close()
                    sys.exit()

            else:
                print(f'Please enter a Y/N response. ')

if __name__ == '__main__':

    CLA = parse_args()
    main(CLA)
