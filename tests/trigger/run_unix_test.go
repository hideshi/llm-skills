//go:build unix

package trigger

import (
	"context"
	"os"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"syscall"
	"testing"
	"time"
)

// fakeCLI は、決まった動きをする偽の CLI を作る。引数と環境変数を書き出し、子のプロセスを1つ起こし、
// sleep だけ待ってから log を標準出力に出す。
func fakeCLI(t *testing.T, log string, sleep time.Duration) (bin, argsFile, envFile, pidFile string) {
	t.Helper()
	dir := t.TempDir()
	argsFile = filepath.Join(dir, "args")
	envFile = filepath.Join(dir, "env")
	pidFile = filepath.Join(dir, "child.pid")
	logFile := filepath.Join(dir, "log.jsonl")
	if err := os.WriteFile(logFile, []byte(log), 0o644); err != nil {
		t.Fatal(err)
	}
	script := "#!/bin/sh\n" +
		"printf '%s\\n' \"$@\" > " + argsFile + "\n" +
		"env > " + envFile + "\n" +
		"sleep 300 & echo $! > " + pidFile + "\n" +
		"sleep " + strconv.Itoa(int(sleep.Seconds())) + "\n" +
		"cat " + logFile + "\n"
	bin = filepath.Join(dir, "fake-claude")
	if err := os.WriteFile(bin, []byte(script), 0o755); err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { killPidFile(pidFile) })
	return
}

func processAlive(pid int) bool {
	return syscall.Kill(pid, 0) == nil
}

func killPidFile(p string) {
	b, err := os.ReadFile(p)
	if err != nil {
		return
	}
	if pid, err := strconv.Atoi(strings.TrimSpace(string(b))); err == nil {
		syscall.Kill(pid, syscall.SIGKILL)
	}
}

func TestRunAndEvaluateWithFakeCLI(t *testing.T) {
	ws := newTestWorkspace(t)
	t.Setenv("CLAUDECODE", "1")
	t.Setenv("GIT_DIR", "/nowhere/.git")
	log := strings.Replace(readLog(t, "isolated.jsonl"), `"skills":["dev-review-brief","dev-test-first","code-review"]`,
		`"skills":`+jsonList(append(slices.Clone(ws.Skills), "code-review")), 1)
	bin, argsFile, envFile, _ := fakeCLI(t, log, 0)
	logPath := filepath.Join(t.TempDir(), "out", "x.jsonl")
	r := Runner{Bin: bin, MaxTurns: 3, Timeout: time.Minute}
	if err := r.Run(context.Background(), ws, "sonnet", "依頼", logPath); err != nil {
		t.Fatal(err)
	}
	args, _ := os.ReadFile(argsFile)
	if got := strings.Split(strings.TrimSpace(string(args)), "\n"); !slices.Equal(got, CLIArgs("sonnet", "依頼", 3)) {
		t.Errorf("CLI に渡した引数 = %q", got)
	}
	env, _ := os.ReadFile(envFile)
	for _, bad := range []string{"CLAUDECODE=", "GIT_DIR="} {
		if strings.Contains(string(env), bad) {
			t.Errorf("%s を CLI に渡した", bad)
		}
	}
	if os.Getenv("HOME") != "" && !strings.Contains(string(env), "HOME=") {
		t.Errorf("HOME（認証に要る）まで消えている")
	}
	o := Outcome{LogPath: logPath}
	Evaluate(&o, Case{Accept: []string{"dev-review-brief"}}, ws)
	if o.Err != nil {
		t.Fatalf("Evaluate: %v", o.Err)
	}
	if !o.Verdict.Pass || o.ActualModel != "claude-sonnet-5-5" || !slices.Equal(o.OtherSkills, []string{"code-review"}) ||
		!slices.Equal(o.ReadSkills, []string{"dev-test-first"}) || len(o.Outside) != 4 {
		t.Errorf("Outcome = %+v", o)
	}
	if !o.Excluded() {
		t.Errorf("外を読んだ回が除外されていない")
	}
}

func TestRunTimeoutKillsChildren(t *testing.T) {
	ws := newTestWorkspace(t)
	bin, _, _, pidFile := fakeCLI(t, "", 30*time.Second)
	r := Runner{Bin: bin, MaxTurns: 3, Timeout: 2 * time.Second}
	start := time.Now()
	err := r.Run(context.Background(), ws, "m", "x", filepath.Join(t.TempDir(), "x.jsonl"))
	if err == nil || !strings.Contains(err.Error(), "時間切れ") {
		t.Fatalf("err = %v", err)
	}
	if time.Since(start) > 20*time.Second {
		t.Errorf("時間切れの後も待ち続けた: %s", time.Since(start))
	}
	b, err := os.ReadFile(pidFile)
	if err != nil {
		t.Fatal(err)
	}
	pid, _ := strconv.Atoi(strings.TrimSpace(string(b)))
	deadline := time.Now().Add(5 * time.Second)
	for processAlive(pid) && time.Now().Before(deadline) {
		time.Sleep(100 * time.Millisecond)
	}
	if processAlive(pid) {
		t.Errorf("CLI の子のプロセス %d が残っている", pid)
	}
}
