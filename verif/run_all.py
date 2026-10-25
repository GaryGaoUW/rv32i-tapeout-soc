from pathlib import Path
import subprocess
import re
from unittest import result

def run_all_tests():
    # Get the current directory
    bin_files = sorted(Path("verif/isa/bin").glob("*.bin"))
    total_tests = len(bin_files)
    pass_count = 0

    print("=" * 60)
    print(f"Starting RISC-V ISA Regression: {total_tests} tests found")
    print("=" * 60)

    for i, bin_file in enumerate(bin_files, start=1):
        if "fence_i" in bin_file.name:
            print(f"Skipping test for {bin_file.name} (fence_i not supported)...")
            continue

        print(f"Running test for {bin_file.name}...")
        result = subprocess.run(["./verif/lv0/obj_dir/Vsoc_top", str(bin_file)], capture_output=True, text=True)
        is_pass = (result.returncode == 0)

        match = re.search(r"cycle (\d+)", result.stdout)
        cycle_count = match.group(1) if match else "N/A"
        if is_pass:
            pass_count += 1
            status = "\033[1;32m[PASS]\033[0m"
        else:
            status = "\033[1;31m[FAIL]\033[0m"

        print(f"[{i:02d}/{total_tests}] {bin_file.stem:<20} {status} (cycle {cycle_count})")

    print("=" * 60)
    print(f"Summary: {pass_count}/{total_tests} tests passed ({(pass_count/total_tests)*100:.1f}%)")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()