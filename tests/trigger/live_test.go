package trigger

import (
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"
)

// 本物のモデルを呼ぶ試験。TRIGGER_LIVE=1 のときだけ流す。費用と時間がかかるので、
// description や振り分けの表を変えたとき、スキルを足したときに、手元で流す。
//
//	TRIGGER_LIVE=1 go test -run TestTriggerLive -timeout 0 -v
//
// 環境変数:
//
//	TRIGGER_MODELS    流すモデル（既定 sonnet,haiku）
//	TRIGGER_REQUIRED  合格率で失敗にするモデル（既定 sonnet）。TRIGGER_MODELS に含まれていること
//	TRIGGER_RUNS      1件あたりの回数（既定 3）
//	TRIGGER_MIN_RATE  合格とみなす合格率の下限（既定 0.66）
//	TRIGGER_SUITES    流すまとまり（既定は全部）
//	TRIGGER_CASES     流す ID（既定は全部）
//	TRIGGER_PARALLEL  同時に流す数。試験用リポジトリをこの数だけ作る（既定 2）
//	TRIGGER_OUT       結果の置き場。この下に流した日時のフォルダを作る（既定は一時フォルダ。消さない）
//	TRIGGER_TIMEOUT   1回の時間の上限（既定 5m）
//	TRIGGER_KEEP=1    試験用リポジトリを消さずに残す
//	CLAUDE_BIN        Claude Code の CLI（既定 claude）

func envList(name, def string) []string {
	v := os.Getenv(name)
	if v == "" {
		v = def
	}
	var out []string
	for _, s := range strings.Split(v, ",") {
		if s = strings.TrimSpace(s); s != "" {
			out = append(out, s)
		}
	}
	return out
}

func envInt(t *testing.T, name string, def int) int {
	v := os.Getenv(name)
	if v == "" {
		return def
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < 1 {
		t.Fatalf("%s=%q は1以上の整数で書く", name, v)
	}
	return n
}

func TestTriggerLive(t *testing.T) {
	if os.Getenv("TRIGGER_LIVE") != "1" {
		t.Skip("TRIGGER_LIVE=1 のときだけ流す（本物のモデルを呼ぶ）")
	}
	root := repoRoot(t)
	def := loadDef(t)

	models := envList("TRIGGER_MODELS", "sonnet,haiku")
	required := envList("TRIGGER_REQUIRED", "sonnet")
	for _, r := range required {
		if !slices.Contains(models, r) {
			t.Fatalf("合格率で判定するモデル %q が、流すモデル %v に無い（TRIGGER_REQUIRED を直す）", r, models)
		}
	}
	runs := envInt(t, "TRIGGER_RUNS", 3)
	parallel := envInt(t, "TRIGGER_PARALLEL", 2)
	minRate := 0.66
	if v := os.Getenv("TRIGGER_MIN_RATE"); v != "" {
		f, err := strconv.ParseFloat(v, 64)
		if err != nil || f < 0 || f > 1 {
			t.Fatalf("TRIGGER_MIN_RATE=%q は0から1の数で書く", v)
		}
		minRate = f
	}
	timeout := 5 * time.Minute
	if v := os.Getenv("TRIGGER_TIMEOUT"); v != "" {
		d, err := time.ParseDuration(v)
		if err != nil {
			t.Fatalf("TRIGGER_TIMEOUT=%q: %v", v, err)
		}
		timeout = d
	}
	bin := os.Getenv("CLAUDE_BIN")
	if bin == "" {
		bin = "claude"
	}
	if _, err := exec.LookPath(bin); err != nil {
		t.Fatalf("CLI %q が見つからない: %v", bin, err)
	}

	jobs, err := def.SelectJobs(envList("TRIGGER_SUITES", ""), envList("TRIGGER_CASES", ""), models, runs)
	if err != nil {
		t.Fatal(err)
	}

	base := os.Getenv("TRIGGER_OUT")
	if base == "" {
		base = os.TempDir()
	}
	outDir, err := filepath.Abs(filepath.Join(base, "skill-trigger-"+time.Now().Format("20060102-150405")))
	if err != nil {
		t.Fatal(err)
	}
	if err := os.MkdirAll(outDir, 0o755); err != nil {
		t.Fatal(err)
	}

	// go test の時間の上限より前に打ち切り、後始末（試験用リポジトリの削除）が走るようにする。
	ctx := context.Background()
	if dl, ok := t.Deadline(); ok {
		var cancel context.CancelFunc
		ctx, cancel = context.WithDeadline(ctx, dl.Add(-30*time.Second))
		defer cancel()
	}

	// 試験用リポジトリを先に全部作る（途中で失敗しても、作業者を待たせたままにしない）。
	var wss []*Workspace
	for w := 0; w < parallel; w++ {
		ws, err := NewWorkspace(filepath.Join(root, "skills"), filepath.Join("fixtures", "base"))
		if err != nil {
			t.Fatal(err)
		}
		if os.Getenv("TRIGGER_KEEP") == "1" {
			t.Logf("試験用リポジトリ: %s", ws.Repo)
		} else {
			t.Cleanup(func() { ws.Remove() })
		}
		wss = append(wss, ws)
	}
	t.Logf("%d 回を %d 並びで流す。結果: %s", len(jobs), parallel, outDir)

	runner := Runner{Bin: bin, MaxTurns: 3, Timeout: timeout}
	ch := make(chan Job)
	var mu sync.Mutex
	var outs []Outcome
	var wg sync.WaitGroup
	for _, ws := range wss {
		wg.Add(1)
		go func(ws *Workspace) {
			defer wg.Done()
			for j := range ch {
				o := Outcome{Suite: j.Suite.Name, CaseID: j.Case.ID, Model: j.Model, Attempt: j.Attempt,
					LogPath: filepath.Join(outDir, j.Model, fmt.Sprintf("%s-%s-%d.jsonl", j.Suite.Name, j.Case.ID, j.Attempt))}
				switch {
				case ctx.Err() != nil:
					o.Err = fmt.Errorf("go test の時間の上限が近いので流さなかった")
				default:
					if err := ws.Reset(j.Suite.Overlay); err != nil {
						o.Err = err
					} else if err := runner.Run(ctx, ws, j.Model, j.Case.Prompt, o.LogPath); err != nil {
						o.Err = err
					} else {
						Evaluate(&o, j.Case, ws)
					}
				}
				mu.Lock()
				outs = append(outs, o)
				mu.Unlock()
			}
		}(ws)
	}
	for _, j := range jobs {
		ch <- j
	}
	close(ch)
	wg.Wait()

	tallies := Summarize(def, outs)
	md := Markdown(tallies)
	if err := os.WriteFile(filepath.Join(outDir, "results.md"), []byte(md), 0o644); err != nil {
		t.Error(err)
	}
	if b, err := json.MarshalIndent(outcomesForJSON(outs), "", "  "); err == nil {
		if err := os.WriteFile(filepath.Join(outDir, "results.json"), b, 0o644); err != nil {
			t.Error(err)
		}
	}
	t.Logf("\n%s", md)

	for _, o := range outs {
		if o.Err != nil {
			t.Errorf("%s/%s %s #%d: 集計から外した: %v（ログ: %s）", o.Suite, o.CaseID, o.Model, o.Attempt, o.Err, o.LogPath)
		}
		for _, r := range o.Outside {
			if !r.Denied {
				t.Errorf("%s/%s %s #%d: リポジトリの外を読んだ（%s %s）。この回は集計から外した。ログ: %s",
					o.Suite, o.CaseID, o.Model, o.Attempt, r.Tool, r.Path, o.LogPath)
			}
		}
	}
	for _, e := range Gate(tallies, required, minRate) {
		t.Error(e)
	}
}

type outcomeJSON struct {
	Suite       string       `json:"suite"`
	CaseID      string       `json:"id"`
	Model       string       `json:"model"`
	ActualModel string       `json:"actualModel,omitempty"`
	Attempt     int          `json:"attempt"`
	Log         string       `json:"log"`
	Skills      []string     `json:"skills"`
	ReadSkills  []string     `json:"readSkills,omitempty"`
	OtherSkills []string     `json:"otherSkills,omitempty"`
	Pass        bool         `json:"pass"`
	Route       Route        `json:"route,omitempty"`
	Reason      string       `json:"reason"`
	Outside     []OutsideRef `json:"outside,omitempty"`
	FirstText   string       `json:"firstText,omitempty"`
	Error       string       `json:"error,omitempty"`
}

func outcomesForJSON(outs []Outcome) []outcomeJSON {
	res := make([]outcomeJSON, 0, len(outs))
	for _, o := range outs {
		j := outcomeJSON{
			Suite: o.Suite, CaseID: o.CaseID, Model: o.Model, ActualModel: o.ActualModel, Attempt: o.Attempt,
			Log: o.LogPath, Skills: o.Skills, ReadSkills: o.ReadSkills, OtherSkills: o.OtherSkills,
			Pass: o.Verdict.Pass, Route: o.Verdict.Route, Reason: o.Verdict.Reason,
			Outside: o.Outside, FirstText: o.FirstText,
		}
		if o.Err != nil {
			j.Error = o.Err.Error()
		}
		res = append(res, j)
	}
	return res
}
