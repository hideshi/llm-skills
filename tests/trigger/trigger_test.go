package trigger

import (
	"bufio"
	"context"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"slices"
	"strings"
	"testing"
	"time"
)

// repoRoot は、このパッケージ（tests/trigger）から見たリポジトリの根。
func repoRoot(t *testing.T) string {
	t.Helper()
	wd, err := os.Getwd()
	if err != nil {
		t.Fatal(err)
	}
	return filepath.Clean(filepath.Join(wd, "..", ".."))
}

func loadDef(t *testing.T) *Definition {
	t.Helper()
	d, err := LoadDefinition("cases.json")
	if err != nil {
		t.Fatal(err)
	}
	return d
}

func dirExists(p string) bool {
	st, err := os.Stat(p)
	return err == nil && st.IsDir()
}

// ---- 定義 ----

func TestDefinitionIsValid(t *testing.T) {
	root := repoRoot(t)
	exists := func(name string) bool {
		_, err := os.Stat(filepath.Join(root, "skills", name, "SKILL.md"))
		return err == nil
	}
	for _, err := range loadDef(t).Validate(exists, dirExists) {
		t.Error(err)
	}
}

func TestValidateCatchesMistakes(t *testing.T) {
	d := &Definition{Suites: []Suite{{Name: "s", Doc: "d.md", Overlay: "no-such-dir", Cases: []Case{
		{ID: "A", Prompt: "x", Accept: []string{"missing"}},
		{ID: "A", Prompt: " ", ForbidPrefixes: []string{"dev-"}},
		{ID: "b", Prompt: "x"},
		{ID: "C", Prompt: "x", Accept: []string{"dev-x"}, ForbidPrefixes: []string{"dev-"}},
		{ID: "D", Prompt: "x", Profiles: []string{"p"}, ForbidPrefixes: []string{"z-"}},
		{ID: "E", Prompt: "x", Accept: []string{"p"}, Profiles: []string{"p"}},
		{ID: "F", Prompt: "x", ForbidPrefixes: []string{" "}},
		{ID: "G", Prompt: "/dev-x して", Accept: []string{"q"}},
	}}}}
	errs := d.Validate(func(n string) bool { return n != "missing" }, dirExists)
	var msgs []string
	for _, e := range errs {
		msgs = append(msgs, e.Error())
	}
	joined := strings.Join(msgs, "\n")
	for _, want := range []string{
		"スキル \"missing\" が無い", "ID が s と重なる", "依頼文が空", "ID の形が違う",
		"accept も forbidPrefixes も無い", "禁じた頭", "accept が無いのに profiles がある",
		"accept と profiles の両方にある", "空の頭", "/ で始まる", "overlay \"no-such-dir\" が無い",
	} {
		if !strings.Contains(joined, want) {
			t.Errorf("%q を検出していない:\n%s", want, joined)
		}
	}
}

func TestSelectJobs(t *testing.T) {
	d := &Definition{Suites: []Suite{
		{Name: "a", Cases: []Case{{ID: "A1"}, {ID: "A2"}}},
		{Name: "b", Cases: []Case{{ID: "B1"}}},
	}}
	jobs, err := d.SelectJobs(nil, nil, []string{"m1", "m2"}, 3)
	if err != nil || len(jobs) != 3*2*3 {
		t.Fatalf("全部: %d 件, err %v", len(jobs), err)
	}
	jobs, err = d.SelectJobs([]string{"a"}, []string{"A2"}, []string{"m1"}, 2)
	if err != nil || len(jobs) != 2 || jobs[0].Case.ID != "A2" || jobs[1].Attempt != 2 {
		t.Fatalf("絞り込み: %+v, err %v", jobs, err)
	}
	for name, args := range map[string][]any{
		"知らないまとまり": {[]string{"x"}, nil, []string{"m"}, 1},
		"知らない ID":  {nil, []string{"A1", "T22"}, []string{"m"}, 1},
		"当たる試験が無い": {[]string{"b"}, []string{"A1"}, []string{"m"}, 1},
		"モデルが無い":   {nil, nil, []string(nil), 1},
		"回数が0":     {nil, nil, []string{"m"}, 0},
	} {
		_, err := d.SelectJobs(toStrings(args[0]), toStrings(args[1]), toStrings(args[2]), args[3].(int))
		if err == nil {
			t.Errorf("%s: 誤りにならない", name)
		}
	}
}

func toStrings(v any) []string {
	if v == nil {
		return nil
	}
	return v.([]string)
}

// docTableIDs は、文書の表のうち、1列目の見出しが ID の表に並ぶ ID を返す。
func docTableIDs(t *testing.T, path string) []string {
	t.Helper()
	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	idCell := regexp.MustCompile(`^\|\s*([A-Z][A-Z0-9]*)\s*\|`)
	var ids []string
	inIDTable := false
	sc := bufio.NewScanner(f)
	for sc.Scan() {
		line := sc.Text()
		switch {
		case strings.HasPrefix(line, "| ID |"):
			inIDTable = true
		case !strings.HasPrefix(line, "|"):
			inIDTable = false
		case inIDTable:
			if m := idCell.FindStringSubmatch(line); m != nil {
				ids = append(ids, m[1])
			}
		}
	}
	return ids
}

// TestDocsMatchDefinition は、文書の表と試験の定義の ID が一致することを確かめる。
// 定義が正本で、文書の表は ID を合わせた説明（依頼文や合格とするスキルの正確な定義は cases.json）。
func TestDocsMatchDefinition(t *testing.T) {
	root := repoRoot(t)
	for _, s := range loadDef(t).Suites {
		docIDs := docTableIDs(t, filepath.Join(root, s.Doc))
		var defIDs []string
		for _, c := range s.Cases {
			defIDs = append(defIDs, c.ID)
			if !slices.Contains(docIDs, c.ID) {
				t.Errorf("%s: %s が %s の表に無い", s.Name, c.ID, s.Doc)
			}
		}
		for _, id := range docIDs {
			if !slices.Contains(defIDs, id) && !slices.Contains(s.DocOnly, id) {
				t.Errorf("%s: %s の表の %s が定義に無い（別の手順なら docOnly に書く）", s.Name, s.Doc, id)
			}
		}
	}
}

// ---- ログの読み取り ----

func parseFile(t *testing.T, name string) *Transcript {
	t.Helper()
	f, err := os.Open(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	tr, err := ParseStreamJSON(f)
	if err != nil {
		t.Fatal(err)
	}
	return tr
}

func TestParseStreamJSON(t *testing.T) {
	tr := parseFile(t, "skill-then-read.jsonl")
	if got, want := tr.Skills(), []string{"dev-profile-review-cycle", "dev-review-brief"}; !slices.Equal(got, want) {
		t.Errorf("Skills = %v, want %v", got, want)
	}
	if len(tr.Calls) != 3 {
		t.Errorf("Calls = %d, want 3", len(tr.Calls))
	}
	if tr.ResultSubtype != "error_max_turns" || !tr.Completed() {
		t.Errorf("ResultSubtype = %q, Completed = %v", tr.ResultSubtype, tr.Completed())
	}
	if tr.FirstText != "依頼文を書く工程に進みます。" {
		t.Errorf("FirstText = %q", tr.FirstText)
	}
	if r := tr.Results["t2"]; r.Text != "Launching skill: dev-review-brief" {
		t.Errorf("配列の content を読めていない: %q", r.Text)
	}
	if refs := tr.OutsideRefs("/tmp/ws/repo"); len(refs) != 0 {
		t.Errorf("中だけを読んだのに外の参照がある: %+v", refs)
	}
}

func TestParseIsolatedSession(t *testing.T) {
	tr := parseFile(t, "isolated.jsonl")
	if tr.Init == nil || tr.Init.Model != "claude-sonnet-5-5" || len(tr.Init.Skills) != 3 || len(tr.Init.Plugins) != 1 {
		t.Fatalf("Init = %+v", tr.Init)
	}
	// 誤りで終わった Skill の呼び出しと、Skill 以外の道具の skill 入力は数えない。先頭の / は落とす。
	if got := tr.Skills(); !slices.Equal(got, []string{"dev-review-brief"}) {
		t.Errorf("Skills = %v", got)
	}
	if got := tr.ReadSkills(); !slices.Equal(got, []string{"dev-test-first"}) {
		t.Errorf("ReadSkills = %v", got)
	}
	if tr.FirstText != "依頼文を書きます。" {
		t.Errorf("FirstText = %q（利用者の文を拾っていないか）", tr.FirstText)
	}
	if !tr.Completed() {
		t.Errorf("手番の上限で終わった回は Completed であるべき")
	}
	got := map[string]bool{}
	for _, r := range tr.OutsideRefs("/tmp/ws/repo") {
		got[r.Path] = r.Denied
	}
	want := map[string]bool{
		"/etc/*.conf":           true,  // Glob の絶対パス。拒否された
		"~/.claude/CLAUDE.md":   false, // ホームを指す。読めた
		"/opt/harness/parse.go": false, // 中身の途中に拒否の文があっても、拒否ではない
		"/opt/nb.ipynb":         false, // 応答が無い呼び出しは、拒否とはみなさない
	}
	if len(got) != len(want) {
		t.Errorf("外の参照 = %v, want %v（Grep の正規表現は数えない）", got, want)
	}
	for p, d := range want {
		if g, ok := got[p]; !ok || g != d {
			t.Errorf("%s: got (%v, 拾った=%v), want Denied=%v", p, g, ok, d)
		}
	}
}

func TestCompleted(t *testing.T) {
	for _, tc := range []struct {
		sub   string
		isErr bool
		want  bool
	}{
		{"success", false, true},
		{"success", true, false}, // 認証切れ、利用の上限など
		{"error_max_turns", true, true},
		{"error_during_execution", true, false},
		{"", false, false}, // result の行が無い
	} {
		tr := &Transcript{ResultSubtype: tc.sub, ResultIsError: tc.isErr}
		if got := tr.Completed(); got != tc.want {
			t.Errorf("Completed(%q, %v) = %v", tc.sub, tc.isErr, got)
		}
	}
}

func TestOutsideRefsInCommands(t *testing.T) {
	tr := parseFile(t, "outside.jsonl")
	if tr.FirstText != "まずリポジトリを確認します。 録画を探します。" {
		t.Errorf("FirstText = %q", tr.FirstText)
	}
	got := map[string]bool{}
	for _, r := range tr.OutsideRefs("/tmp/ws/repo") {
		got[r.Path] = r.Denied
	}
	want := map[string]bool{
		"/tmp/ws":            true,  // 権限で拒否された
		"../secret-notes.md": false, // 中身を読んだ
		"..":                 true,  // シェルが止めてあり実行されていない
	}
	if len(got) != len(want) {
		t.Errorf("refs = %v, want %v", got, want)
	}
	for p, denied := range want {
		if d, ok := got[p]; !ok || d != denied {
			t.Errorf("%s: got (%v, 拾った=%v), want Denied=%v", p, d, ok, denied)
		}
	}
	more := &Transcript{Results: map[string]ToolResult{}, Calls: []ToolCall{
		{ID: "1", Name: "Bash", Input: map[string]any{"command": "cat /etc/passwd"}},
		{ID: "2", Name: "Bash", Input: map[string]any{"command": "ls a/../../x"}},
		{ID: "3", Name: "Bash", Input: map[string]any{"command": "cat ~/.ssh/config"}},
	}}
	paths := map[string]bool{}
	for _, r := range more.OutsideRefs("/tmp/ws/repo") {
		paths[r.Path] = true
	}
	for _, p := range []string{"/etc/passwd", "a/../../x", "~/.ssh/config"} {
		if !paths[p] {
			t.Errorf("コマンドの中の %s を拾っていない: %v", p, paths)
		}
	}
}

func TestIsOutside(t *testing.T) {
	root := "/tmp/ws/repo"
	cases := map[string]bool{
		"/tmp/ws/repo":        false,
		"/tmp/ws/repo/a/b.py": false,
		"price.py":            false,
		"main...feature-x":    false,
		"/dev/null":           false,
		"/tmp/ws":             true,
		"/tmp/ws/repo2/x":     true,
		"../x":                true,
		"a/../../x":           true,
		"/proc/meminfo":       true,
		"~":                   true,
		"~/.claude/CLAUDE.md": true,
	}
	for p, want := range cases {
		if got := isOutside(root, p); got != want {
			t.Errorf("isOutside(%q) = %v, want %v", p, got, want)
		}
	}
}

// ---- 判定と集計 ----

func TestJudge(t *testing.T) {
	review := Case{Accept: []string{"dev-review-brief"}, Profiles: []string{"dev-profile-review-cycle", "dev-profile-existing-system"}}
	never := Case{ForbidPrefixes: []string{"dev-"}}
	cf := Case{Accept: []string{"dev-current-behavior-survey"}, ForbidPrefixes: []string{"cloudflare-"}}
	tests := []struct {
		name   string
		c      Case
		skills []string
		pass   bool
		route  Route
	}{
		{"最初に期待の単位", review, []string{"dev-review-brief"}, true, RouteDirect},
		{"振り分けから期待の単位", review, []string{"dev-profile-review-cycle", "dev-review-brief"}, true, RouteViaRouter},
		{"振り分けを二つ経て期待の単位", review, []string{"dev-profile-existing-system", "dev-profile-review-cycle", "dev-review-brief"}, true, RouteViaRouter},
		{"同じ振り分けを二度", review, []string{"dev-profile-review-cycle", "dev-profile-review-cycle", "dev-review-brief"}, true, RouteViaRouter},
		{"振り分けだけで終わる", review, []string{"dev-profile-review-cycle"}, true, RouteRouteOnly},
		{"振り分けから別の単位", review, []string{"dev-profile-review-cycle", "dev-review-conduct"}, false, ""},
		{"スキルを使わない", review, nil, false, ""},
		{"別のスキルが先", review, []string{"code-review", "dev-review-brief"}, false, ""},
		{"禁じた群を使わない", never, []string{"security-review"}, true, RouteAbstain},
		{"何も使わない", never, nil, true, RouteAbstain},
		{"禁じた群を使う", never, []string{"dev-profile-new-feature"}, false, ""},
		{"期待の後に禁じた群", cf, []string{"dev-current-behavior-survey", "cloudflare-product-survey"}, false, ""},
		{"期待どおりで禁じた群なし", cf, []string{"dev-current-behavior-survey"}, true, RouteDirect},
	}
	for _, tc := range tests {
		got := Judge(tc.c, tc.skills)
		if got.Pass != tc.pass || got.Route != tc.route {
			t.Errorf("%s: Judge = %+v, want pass=%v route=%q", tc.name, got, tc.pass, tc.route)
		}
	}
}

func TestSummarizeAndGate(t *testing.T) {
	def := &Definition{Suites: []Suite{{Name: "s", Cases: []Case{{ID: "A"}, {ID: "B"}}}}}
	pass := func(r Route) Verdict { return Verdict{Pass: true, Route: r} }
	outs := []Outcome{
		{Suite: "s", CaseID: "A", Model: "m", Verdict: pass(RouteDirect)},
		{Suite: "s", CaseID: "A", Model: "m", Verdict: Verdict{Pass: false, Reason: "スキルを使わなかった"}},
		{Suite: "s", CaseID: "A", Model: "m", Verdict: pass(RouteRouteOnly), Outside: []OutsideRef{{Path: "/x", Denied: false}}},
		{Suite: "s", CaseID: "A", Model: "m", Verdict: pass(RouteRouteOnly), Outside: []OutsideRef{{Path: "/y", Denied: true}}},
		{Suite: "s", CaseID: "A", Model: "m", Verdict: pass(RouteDirect), Err: os.ErrDeadlineExceeded},
		{Suite: "s", CaseID: "A", Model: "n", Verdict: Verdict{Pass: false, Reason: "最初に a|b"}},
		{Suite: "s", CaseID: "B", Model: "m", Err: os.ErrNotExist},
	}
	ts := Summarize(def, outs)
	if len(ts) != 3 {
		t.Fatalf("tallies = %+v", ts)
	}
	a := ts[0]
	if a.Model != "m" || a.Pass != 2 || a.Counted != 3 || a.Excl != 2 || a.Routes[RouteDirect] != 1 || a.Routes[RouteRouteOnly] != 1 {
		t.Errorf("A/m = %+v, want pass 2 / counted 3 / excluded 2", a)
	}
	if r := a.Rate(); r < 0.66 || r > 0.67 {
		t.Errorf("Rate = %v", r)
	}
	if ts[1].Model != "n" || ts[1].Pass != 0 || ts[1].Counted != 1 {
		t.Errorf("A/n = %+v（モデルを分けて集計していない）", ts[1])
	}
	md := Markdown(ts)
	for _, want := range []string{"2/3（直接1・振り分けまで1）［除外 2］：スキルを使わなかった", `最初に a\|b`, "| s | B | 0/0［除外 1］ | — |"} {
		if !strings.Contains(md, want) {
			t.Errorf("Markdown に %q が無い:\n%s", want, md)
		}
	}
	errs := strings.Join(Gate(ts, []string{"m"}, 0.66), "\n")
	if !strings.Contains(errs, "s/B m: 集計に入れられる回が無い") || strings.Contains(errs, "s/A m") {
		t.Errorf("Gate(0.66) = %s", errs)
	}
	errs = strings.Join(Gate(ts, []string{"m"}, 0.9), "\n")
	if !strings.Contains(errs, "s/A m: 合格 2/3 が下限 0.90 を下回る") {
		t.Errorf("Gate(0.9) = %s", errs)
	}
	if errs := Gate(ts, []string{"other"}, 0.9); len(errs) != 0 {
		t.Errorf("必須でないモデルを判定した: %v", errs)
	}
}

// ---- 隔離 ----

func TestCleanEnv(t *testing.T) {
	in := []string{"PATH=/bin", "HOME=/h", "LANG=ja_JP.UTF-8", "LC_ALL=C", "XDG_RUNTIME_DIR=/run",
		"ANTHROPIC_API_KEY=k", "CLAUDE_CODE_USE_VERTEX=1",
		"CLAUDECODE=1", "CLAUDE_CODE_SESSION_ID=s", "CLAUDE_EFFORT=high", "CLAUDE_CODE_MESSAGING_SOCKET=/s",
		"GIT_DIR=/r/.git", "SECRET_TOKEN=x"}
	got := CleanEnv(in)
	want := []string{"PATH=/bin", "HOME=/h", "LANG=ja_JP.UTF-8", "LC_ALL=C", "XDG_RUNTIME_DIR=/run",
		"ANTHROPIC_API_KEY=k", "CLAUDE_CODE_USE_VERTEX=1"}
	if !slices.Equal(got, want) {
		t.Errorf("CleanEnv = %v, want %v", got, want)
	}
}

func TestCLIArgs(t *testing.T) {
	args := strings.Join(CLIArgs("sonnet", "依頼", 3), " ")
	for _, want := range []string{"-p 依頼", "--model sonnet", "--max-turns 3", "--tools Glob,Grep,Read,Skill",
		"--setting-sources project", "--strict-mcp-config", "--no-session-persistence", "--output-format stream-json"} {
		if !strings.Contains(args, want) {
			t.Errorf("引数に %q が無い: %s", want, args)
		}
	}
}

func newTestWorkspace(t *testing.T) *Workspace {
	t.Helper()
	ws, err := NewWorkspace(filepath.Join(repoRoot(t), "skills"), filepath.Join("fixtures", "base"))
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(func() { ws.Remove() })
	return ws
}

func gitOut(t *testing.T, dir string, args ...string) string {
	t.Helper()
	cmd := exec.Command("git", args...)
	cmd.Dir = dir
	cmd.Env = gitEnv()
	b, err := cmd.Output()
	if err != nil {
		t.Fatalf("git %v: %v", args, err)
	}
	return strings.TrimSpace(string(b))
}

// TestWorkspaceResolvesLinkedTempDir は、一時フォルダがリンクを含むとき（macOS の /var など）、
// 試験用リポジトリのパスを実体にそろえることを確かめる。CLI は実体のパスで作業するため、
// そろえないと、リポジトリの中の読み取りがすべて外の参照に数えられる。
func TestWorkspaceResolvesLinkedTempDir(t *testing.T) {
	realTmp := t.TempDir()
	link := filepath.Join(t.TempDir(), "linked-tmp")
	if err := os.Symlink(realTmp, link); err != nil {
		t.Skip("リンクを作れない:", err)
	}
	t.Setenv("TMPDIR", link)
	ws := newTestWorkspace(t)
	want, _ := filepath.EvalSymlinks(realTmp)
	if !strings.HasPrefix(ws.Repo, want+string(filepath.Separator)) {
		t.Errorf("Repo = %s、実体の %s の下であるべき", ws.Repo, want)
	}
	tr := &Transcript{Results: map[string]ToolResult{}, Calls: []ToolCall{
		{ID: "1", Name: "Read", Input: map[string]any{"file_path": filepath.Join(ws.Repo, "price.py")}},
	}}
	if refs := tr.OutsideRefs(ws.Repo); len(refs) != 0 {
		t.Errorf("中の読み取りを外と数えた: %+v", refs)
	}
}

func TestWorkspace(t *testing.T) {
	// 利用者の環境に GIT_DIR が設定されていても、ほかのリポジトリを触らない。
	other := t.TempDir()
	if out, err := exec.Command("git", "init", "-q", other).CombinedOutput(); err != nil {
		t.Fatalf("%v: %s", err, out)
	}
	t.Setenv("GIT_DIR", filepath.Join(other, ".git"))

	ws := newTestWorkspace(t)
	if ws.Dir != filepath.Dir(ws.Repo) {
		t.Fatalf("Dir と Repo の関係が違う: %s %s", ws.Dir, ws.Repo)
	}
	if real, _ := filepath.EvalSymlinks(ws.Dir); real != ws.Dir {
		t.Errorf("Dir が実体のパスでない: %s → %s", ws.Dir, real)
	}
	if _, err := os.Stat(filepath.Join(other, ".git", "refs", "heads", "main")); err == nil {
		t.Errorf("GIT_DIR の指すリポジトリにコミットした")
	}
	// スキルは実体で、置き場だけに置く。
	st, err := os.Lstat(filepath.Join(ws.Repo, SkillDir, "dev-review-brief", "SKILL.md"))
	if err != nil || st.Mode()&os.ModeSymlink != 0 {
		t.Fatalf("スキルが実体で置かれていない: %v %v", st, err)
	}
	if _, err := os.Stat(filepath.Join(ws.Repo, "dev-review-brief")); err == nil {
		t.Errorf("スキルが置き場の外にもある")
	}
	if !slices.Contains(ws.Skills, "dev-review-brief") || slices.Contains(ws.Skills, "dev-shared") {
		t.Errorf("Skills = %v（SKILL.md のあるものだけを数える）", ws.Skills)
	}
	// 親フォルダには試験用リポジトリしか無い。
	entries, _ := os.ReadDir(ws.Dir)
	if len(entries) != 1 || entries[0].Name() != "repo" {
		t.Errorf("親フォルダに余計なものがある: %v", entries)
	}
	// 最初の状態はコミット済みで、作業ツリーはきれい。枝は main。
	if s := gitOut(t, ws.Repo, "status", "--porcelain"); s != "" {
		t.Errorf("作業ツリーがきれいでない: %s", s)
	}
	if b := gitOut(t, ws.Repo, "rev-parse", "--abbrev-ref", "HEAD"); b != "main" {
		t.Errorf("枝 = %s", b)
	}
	// 上書きの後に戻すと、最初の状態になる。未追跡のフォルダと無視されるファイルも消える。
	if err := ws.Reset(filepath.Join("fixtures", "change")); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(ws.Repo, "price.py")); !strings.Contains(string(b), "ValueError") {
		t.Errorf("上書きが入っていない")
	}
	os.MkdirAll(filepath.Join(ws.Repo, "stray", "deep"), 0o755)
	os.WriteFile(filepath.Join(ws.Repo, "stray", "deep", "x.txt"), []byte("x"), 0o644)
	os.WriteFile(filepath.Join(ws.Repo, ".gitignore"), []byte("ignored.txt\n"), 0o644)
	os.WriteFile(filepath.Join(ws.Repo, "ignored.txt"), []byte("x"), 0o644)
	if err := ws.Reset(""); err != nil {
		t.Fatal(err)
	}
	if b, _ := os.ReadFile(filepath.Join(ws.Repo, "price.py")); strings.Contains(string(b), "ValueError") {
		t.Errorf("最初の状態に戻っていない")
	}
	for _, p := range []string{"stray", "ignored.txt", ".gitignore"} {
		if _, err := os.Stat(filepath.Join(ws.Repo, p)); !os.IsNotExist(err) {
			t.Errorf("前の回の %s が残っている", p)
		}
	}
}

func readLog(t *testing.T, name string) string {
	t.Helper()
	b, err := os.ReadFile(filepath.Join("testdata", name))
	if err != nil {
		t.Fatal(err)
	}
	return string(b)
}

func jsonList(xs []string) string {
	return `["` + strings.Join(xs, `","`) + `"]`
}

func TestEvaluateRejectsBrokenIsolation(t *testing.T) {
	ws := newTestWorkspace(t)
	skills := jsonList(ws.Skills)
	good := `{"type":"system","subtype":"init","model":"m","tools":["Glob","Grep","Read","Skill"],"skills":` + skills + `,"mcp_servers":[]}`
	end := `{"type":"result","subtype":"success","is_error":false}`
	cases := map[string]struct {
		log  string
		want string
	}{
		"init の行が無い":  {end, "init の行が無い"},
		"認証切れ":        {good + "\n" + `{"type":"result","subtype":"success","is_error":true,"result":"Invalid API key"}`, "誤りで終わった"},
		"result が無い":  {good, "誤りで終わった"},
		"フックが走った":     {good + "\n" + `{"type":"system","subtype":"hook_started"}` + "\n" + end, "フック"},
		"MCP がある":     {strings.Replace(good, `"mcp_servers":[]`, `"mcp_servers":[{"name":"site"}]`, 1) + "\n" + end, "MCP"},
		"道具が多い":       {strings.Replace(good, `"Skill"]`, `"Skill","Bash"]`, 1) + "\n" + end, "使える道具"},
		"スキルが読み込まれない": {strings.Replace(good, skills, `["dev-review-brief"]`, 1) + "\n" + end, "読み込まれていない"},
	}
	for name, tc := range cases {
		p := filepath.Join(t.TempDir(), "x.jsonl")
		os.WriteFile(p, []byte(tc.log+"\n"), 0o644)
		o := Outcome{LogPath: p}
		Evaluate(&o, Case{ForbidPrefixes: []string{"dev-"}}, ws)
		if o.Err == nil || !strings.Contains(o.Err.Error(), tc.want) {
			t.Errorf("%s: Err = %v, want %q を含む", name, o.Err, tc.want)
		}
		if !o.Excluded() {
			t.Errorf("%s: 除外されていない（禁止だけの試験で合格に数えられる）", name)
		}
	}
	p := filepath.Join(t.TempDir(), "ok.jsonl")
	os.WriteFile(p, []byte(good+"\n"+end+"\n"), 0o644)
	o := Outcome{LogPath: p}
	Evaluate(&o, Case{ForbidPrefixes: []string{"dev-"}}, ws)
	if o.Err != nil || !o.Verdict.Pass {
		t.Errorf("条件どおりの回: %+v", o)
	}
}

func TestRunMissingCLI(t *testing.T) {
	ws := newTestWorkspace(t)
	r := Runner{Bin: filepath.Join(t.TempDir(), "no-such-claude"), MaxTurns: 3, Timeout: time.Minute}
	if err := r.Run(context.Background(), ws, "m", "x", filepath.Join(t.TempDir(), "x.jsonl")); err == nil {
		t.Errorf("CLI が無いのに誤りにならない")
	}
}
