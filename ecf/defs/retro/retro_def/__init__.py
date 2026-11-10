"""Make a developer retro suite definition from the NCO one (make_rrfs_retro_def.py).

  config.py     the retro settings, sourced from retro/config.sh and the domain file
  deftree.py    the definition as lines, a node tree over them, and queued line edits
  expr.py       trigger and complete expressions: parse, rewrite, fold, write back
  skip.py       switch tasks off and repair the triggers that named them
  settings.py   suite variables, job commands and job sizes
  ordering.py   retro triggers that replace the clock
  simplify.py   the tasks a retro leaves out, and the cold starts that replace spin-up
  chains.py     the whole retro in one suite, a family per day and cold-start chain
"""
