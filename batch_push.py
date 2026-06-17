import subprocess
import sys

def run_cmd(cmd):
    print("Running:", " ".join(cmd))
    res = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if res.returncode != 0:
        print("Error:", res.stderr)
        return False, res.stderr
    return True, res.stdout.strip()

def main():
    # Set postBuffer to maximum (2GB) first
    run_cmd(["git", "config", "http.postBuffer", "2147483648"])

    # Get all commits in main in reverse order (oldest first)
    success, output = run_cmd(["git", "rev-list", "--reverse", "main"])
    if not success:
        sys.exit(1)
    
    commits = output.splitlines()
    total = len(commits)
    print(f"Total commits to push: {total}")
    
    # Push in batches of 15,000 commits
    step = 15000
    for i in range(step, total, step):
        commit = commits[i - 1]
        print(f"\n--- Pushing batch up to commit {i}/{total} ({commit}) ---")
        ok, err = run_cmd(["git", "push", "origin", f"{commit}:refs/heads/main"])
        if not ok:
            print("Failed pushing batch, retrying once...")
            ok2, err2 = run_cmd(["git", "push", "origin", f"{commit}:refs/heads/main"])
            if not ok2:
                print("Failed again, aborting.")
                sys.exit(1)
    
    # Final push of the main branch itself
    print(f"\n--- Final push of main branch ---")
    ok, err = run_cmd(["git", "push", "-u", "origin", "main"])
    if not ok:
        sys.exit(1)
    print("Push completed successfully!")

if __name__ == "__main__":
    main()
