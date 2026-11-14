package trigger

import (
	"context"
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"slices"
	"sort"
	"strings"
	"time"
)

// AllowedTools は、試験されるセッションに渡す道具。読むことと、スキルを使うことだけを許す。
// 書き込み、シェル、外部への通信、下位の担当、予約や遠隔の実行などは渡さない。
var AllowedTools = []string{"Glob", "Grep", "Read", "Skill"}

// CLIArgs は、prompt を流すときの CLI の引数。利用者の設定（言語の指定、フック、利用者単位のスキル、
// プラグイン）と MCP を読み込まず、セッションの記録も残さない。
func CLIArgs(model, prompt string, maxTurns int) []string {
	return []string{
		"-p", prompt,
		"--model", model,
		"--output-format", "stream-json", "--verbose",
		"--max-turns", fmt.Sprint(maxTurns),
		"--tools", strings.Join(AllowedTools, ","),
		"--setting-sources", "project",
		"--strict-mcp-config",
		"--no-session-persistence",
	}
}

// envAllowExact と envAllowPrefix は、試験されるセッションに渡す環境変数。
// 認証、プロキシ、言語と端末に要るものだけを渡し、呼び出し元のセッションの変数（CLAUDECODE など）や
// GIT_* は渡さない。
var envAllowExact = []string{
	"PATH", "HOME", "USER", "LOGNAME", "SHELL", "LANG", "TERM", "TMPDIR", "TZ",
	"HTTP_PROXY", "HTTPS_PROXY", "NO_PROXY", "http_proxy", "https_proxy", "no_proxy",
	"SSL_CERT_FILE", "SSL_CERT_DIR", "NODE_EXTRA_CA_CERTS",
	"CLAUDE_CONFIG_DIR", "CLAUDE_CODE_OAUTH_TOKEN", "CLAUDE_CODE_USE_BEDROCK", "CLAUDE_CODE_USE_VERTEX",
}

var envAllowPrefix = []string{"LC_", "XDG_", "ANTHROPIC_", "AWS_", "CLOUD_ML_", "VERTEX_", "GOOGLE_"}

// CleanEnv は、environ から試験されるセッションに渡す変数だけを残す。
func CleanEnv(environ []string) []string {
	var out []string
	for _, kv := range environ {
		name, _, _ := strings.Cut(kv, "=")
		ok := slices.Contains(envAllowExact, name)
		for _, p := range envAllowPrefix {
			if strings.HasPrefix(name, p) {
				ok = true
			}
		}
		if ok {
			out = append(out, kv)
		}
	}
	return out
}

// Runner は、Claude Code の CLI を1回ずつ新しいセッションで起動する。
type Runner struct {
	Bin      string
	MaxTurns int
	Timeout  time.Duration
}

// Run は、ws の中で prompt を1回流し、出力を logPath に書く。
// 手番の上限で終わると CLI は 0 以外で終わるが、それは想定どおりなので、終了コードは見ない
// （実行が想定どおりに終わったかは、ログの result の行で Evaluate が判定する）。
// 時間切れと起動の失敗だけを誤りにする。時間切れでは、CLI が起こした子のプロセスもまとめて止める。
func (r Runner) Run(ctx context.Context, ws *Workspace, model, prompt, logPath string) error {
	ctx, cancel := context.WithTimeout(ctx, r.Timeout)
	defer cancel()
	if err := os.MkdirAll(filepath.Dir(logPath), 0o755); err != nil {
		return err
	}
	out, err := os.Create(logPath)
	if err != nil {
		return err
	}
	defer out.Close()
	errf, err := os.Create(strings.TrimSuffix(logPath, ".jsonl") + ".err")
	if err != nil {
		return err
	}
	defer errf.Close()
	cmd := exec.CommandContext(ctx, r.Bin, CLIArgs(model, prompt, r.MaxTurns)...)
	cmd.Dir = ws.Repo
	cmd.Env = CleanEnv(os.Environ())
	cmd.Stdout = out
	cmd.Stderr = errf
	setProcessGroup(cmd)
	cmd.WaitDelay = 10 * time.Second
	err = cmd.Run()
	if ctx.Err() != nil {
		return fmt.Errorf("時間切れ（%s）", r.Timeout)
	}
	var exitErr *exec.ExitError
	if err != nil && !errors.As(err, &exitErr) {
		return err
	}
	return nil
}

// Outcome は、1回の実行の結果。
type Outcome struct {
	Suite, CaseID, Model string
	Attempt              int
	LogPath              string
	// ActualModel は、セッションが報告したモデルの ID（別名でなく）。
	ActualModel string
	Skills      []string
	// ReadSkills は、Skill の道具を使わずに置き場のファイルを読んだスキル（使ったとは数えない）。
	ReadSkills []string
	// OtherSkills は、セッションに読み込まれたスキルのうち、試験用リポジトリに置いていないもの（CLI に組み込みのものなど）。
	OtherSkills []string
	Verdict     Verdict
	Outside     []OutsideRef
	FirstText   string
	Err         error
}

// Excluded は、集計から外す回か（実行や隔離の確認に失敗した、またはリポジトリの外の中身を読んだ）。
func (o Outcome) Excluded() bool {
	if o.Err != nil {
		return true
	}
	for _, r := range o.Outside {
		if !r.Denied {
			return true
		}
	}
	return false
}

// Evaluate は、ログを読み、隔離が守られたかを確かめてから、判定と外の参照を Outcome に入れる。
// 隔離の確認に失敗した回、実行が誤りで終わった回は、Err に理由を入れる（集計から外す）。
func Evaluate(o *Outcome, c Case, ws *Workspace) {
	f, err := os.Open(o.LogPath)
	if err != nil {
		o.Err = err
		return
	}
	defer f.Close()
	t, err := ParseStreamJSON(f)
	if err != nil {
		o.Err = err
		return
	}
	if err := checkIsolation(t, ws); err != nil {
		o.Err = err
		return
	}
	o.ActualModel = t.Init.Model
	for _, s := range t.Init.Skills {
		if !slices.Contains(ws.Skills, s) {
			o.OtherSkills = append(o.OtherSkills, s)
		}
	}
	o.Skills = t.Skills()
	o.ReadSkills = t.ReadSkills()
	o.Verdict = Judge(c, o.Skills)
	o.Outside = t.OutsideRefs(ws.Repo)
	o.FirstText = t.FirstText
}

// checkIsolation は、セッションが試験の条件どおりに起動し、終わったかを確かめる。
func checkIsolation(t *Transcript, ws *Workspace) error {
	if t.Init == nil {
		return errors.New("init の行が無い（CLI が起動していない可能性）")
	}
	if !t.Completed() {
		return fmt.Errorf("実行が誤りで終わった（result: %q, is_error: %v）。認証切れや利用の上限を確かめる", t.ResultSubtype, t.ResultIsError)
	}
	if t.Hooks > 0 {
		return fmt.Errorf("フックが %d 件走った（利用者の設定が読み込まれている）", t.Hooks)
	}
	if len(t.Init.MCPServers) > 0 {
		return fmt.Errorf("MCP のサーバーが読み込まれた: %v", t.Init.MCPServers)
	}
	tools := slices.Clone(t.Init.Tools)
	sort.Strings(tools)
	if !slices.Equal(tools, AllowedTools) {
		return fmt.Errorf("使える道具が %v（期待は %v）", tools, AllowedTools)
	}
	var missing []string
	for _, s := range ws.Skills {
		if !slices.Contains(t.Init.Skills, s) {
			missing = append(missing, s)
		}
	}
	if len(missing) > 0 {
		return fmt.Errorf("置いたスキルが読み込まれていない: %v", missing)
	}
	return nil
}

// Tally は、試験とモデルごとの集計。
type Tally struct {
	Suite, CaseID, Model string
	Pass, Counted, Excl  int
	Routes               map[Route]int
	Reasons              []string
}

// Rate は、集計に入れた回のうちの合格の割合。数えた回が無ければ 0。
func (t Tally) Rate() float64 {
	if t.Counted == 0 {
		return 0
	}
	return float64(t.Pass) / float64(t.Counted)
}

// Summarize は、結果を試験とモデルごとに集める。並びは定義の順。
func Summarize(def *Definition, outs []Outcome) []Tally {
	idx := map[string]*Tally{}
	var order []string
	for _, s := range def.Suites {
		for _, c := range s.Cases {
			for _, o := range outs {
				if o.Suite != s.Name || o.CaseID != c.ID {
					continue
				}
				k := s.Name + "/" + c.ID + "/" + o.Model
				t, ok := idx[k]
				if !ok {
					t = &Tally{Suite: s.Name, CaseID: c.ID, Model: o.Model, Routes: map[Route]int{}}
					idx[k] = t
					order = append(order, k)
				}
				if o.Excluded() {
					t.Excl++
					continue
				}
				t.Counted++
				if o.Verdict.Pass {
					t.Pass++
					t.Routes[o.Verdict.Route]++
				} else {
					t.Reasons = append(t.Reasons, o.Verdict.Reason)
				}
			}
		}
	}
	res := make([]Tally, 0, len(order))
	for _, k := range order {
		res = append(res, *idx[k])
	}
	return res
}

// Gate は、必須のモデルの合格率が下限を下回った試験を、誤りの文にして返す。
func Gate(tallies []Tally, required []string, minRate float64) []string {
	var errs []string
	for _, tl := range tallies {
		if !slices.Contains(required, tl.Model) {
			continue
		}
		if tl.Counted == 0 {
			errs = append(errs, fmt.Sprintf("%s/%s %s: 集計に入れられる回が無い（除外 %d）", tl.Suite, tl.CaseID, tl.Model, tl.Excl))
			continue
		}
		if tl.Rate() < minRate {
			errs = append(errs, fmt.Sprintf("%s/%s %s: 合格 %d/%d が下限 %.2f を下回る（%s）",
				tl.Suite, tl.CaseID, tl.Model, tl.Pass, tl.Counted, minRate, strings.Join(uniq(tl.Reasons), "、")))
		}
	}
	return errs
}

// GateTotal は、必須のモデルごとに、全部の試験を合わせた合格率が下限を下回ったら、誤りの文にして返す。
// 1件ずつの下限（Gate）とは別に、群全体の取りこぼしの割合を見る。
func GateTotal(tallies []Tally, required []string, minTotal float64) []string {
	var errs []string
	for _, m := range required {
		pass, counted := 0, 0
		for _, tl := range tallies {
			if tl.Model == m {
				pass += tl.Pass
				counted += tl.Counted
			}
		}
		if counted == 0 {
			continue
		}
		if rate := float64(pass) / float64(counted); rate < minTotal {
			errs = append(errs, fmt.Sprintf("%s: 全体の合格 %d/%d（%.3f）が下限 %.2f を下回る", m, pass, counted, rate, minTotal))
		}
	}
	return errs
}

var routeOrder = []Route{RouteDirect, RouteViaRouter, RouteRouteOnly, RouteAbstain}

// Markdown は、集計を表にする。セルは「合格/数えた回」に、合格の経路の内訳と、不合格の理由を添える。
func Markdown(tallies []Tally) string {
	models := map[string]bool{}
	for _, t := range tallies {
		models[t.Model] = true
	}
	var ms []string
	for m := range models {
		ms = append(ms, m)
	}
	sort.Strings(ms)
	var b strings.Builder
	b.WriteString("| まとまり | ID |")
	for _, m := range ms {
		b.WriteString(" " + cellEscape(m) + " |")
	}
	b.WriteString("\n|---|---|")
	for range ms {
		b.WriteString("---|")
	}
	b.WriteString("\n")
	type key struct{ s, c string }
	rows := map[key]map[string]Tally{}
	var order []key
	for _, t := range tallies {
		k := key{t.Suite, t.CaseID}
		if rows[k] == nil {
			rows[k] = map[string]Tally{}
			order = append(order, k)
		}
		rows[k][t.Model] = t
	}
	for _, k := range order {
		fmt.Fprintf(&b, "| %s | %s |", cellEscape(k.s), cellEscape(k.c))
		for _, m := range ms {
			t, ok := rows[k][m]
			if !ok {
				b.WriteString(" — |")
				continue
			}
			cell := fmt.Sprintf("%d/%d", t.Pass, t.Counted)
			var parts []string
			for _, r := range routeOrder {
				if n := t.Routes[r]; n > 0 {
					parts = append(parts, fmt.Sprintf("%s%d", r, n))
				}
			}
			if len(parts) > 0 {
				cell += "（" + strings.Join(parts, "・") + "）"
			}
			if t.Excl > 0 {
				cell += fmt.Sprintf("［除外 %d］", t.Excl)
			}
			if len(t.Reasons) > 0 {
				cell += "：" + strings.Join(uniq(t.Reasons), "、")
			}
			b.WriteString(" " + cellEscape(cell) + " |")
		}
		b.WriteString("\n")
	}
	return b.String()
}

func cellEscape(s string) string {
	return strings.ReplaceAll(strings.ReplaceAll(s, "|", `\|`), "\n", " ")
}

func uniq(xs []string) []string {
	seen := map[string]bool{}
	var out []string
	for _, x := range xs {
		if !seen[x] {
			seen[x] = true
			out = append(out, x)
		}
	}
	return out
}
