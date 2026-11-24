import sys

def err_check(err):
    if err > 0:
        print(f"An error ocurred in {sys.argv[0]}")
        exit(err)

print("Blending code is executing.")
sys.exit(0)