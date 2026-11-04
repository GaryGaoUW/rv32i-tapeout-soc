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

        # Scoreboard: D-bus transactions vs. load/store instructions executed.
        # "extra" > 0 means the same instruction hit the bus more than once.
        sb = re.search(r"DBUS reads=(\d+) writes=(\d+) \| MEM loads=(\d+) stores=(\d+)", result.stdout)
        if sb:
            rd, wr, ld, st = map(int, sb.groups())
            extra = (rd - ld) + (wr - st)
            color = "\033[1;33m" if extra else ""
            reset = "\033[0m" if extra else ""
            sb_text = f"{color}rd {rd}/{ld}  wr {wr}/{st}  extra {extra:+d}{reset}"
        else:
            sb_text = "scoreboard N/A"

        print(f"[{i:02d}/{total_tests}] {bin_file.stem:<20} {status} (cycle {cycle_count:>5})  {sb_text}")

    print("=" * 60)
    print(f"Summary: {pass_count}/{total_tests} tests passed ({(pass_count/total_tests)*100:.1f}%)")
    print("=" * 60)

if __name__ == "__main__":
    run_all_tests()