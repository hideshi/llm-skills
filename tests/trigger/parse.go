package trigger

import (
	"bufio"
	"encoding/json"
	"io"
	"path/filepath"
	"regexp"
	"strings"
)

// ToolCall は、ログの中の道具の呼び出し一つ。
type ToolCall struct {
	ID    string
	Name  string
	Input map[string]any
	// Skill は、Name が Skill のときの、使ったスキルの名前（先頭の / は落とす）。
	Skill string
}

// ToolResult は、道具の呼び出しへの応答。
type ToolResult struct {
	IsError bool
	Text    string
}

// Session は、セッションの始まり（init の行）に書かれた、読み込まれたものの一覧。
type Session struct {
	Model      string
	Tools      []string
	Skills     []string
	MCPServers []string
	Plugins    []string
}

// Transcript は、1回の実行のログを読み取ったもの。
type Transcript struct {
	Init    *Session
	Calls   []ToolCall
	Results map[string]ToolResult
	// Hooks は、走ったフックの数（試験では 0 であるべき）。
	Hooks int
	// FirstText は、最初の応答の文の頭（スキルを使わなかった理由を読むため）。
	FirstText string
	// ResultSubtype と ResultIsError は、最後の result の行の種類と誤りの印。
	// ResultSubtype が空なら、result の行が無い。
	ResultSubtype string
	ResultIsError bool
}

// Skills は、使ったスキルの名前を順に返す。応答が誤りだった呼び出し（存在しない名前など）は数えない。
func (t *Transcript) Skills() []string {
	var out []string
	for _, c := range t.Calls {
		if c.Skill == "" {
			continue
		}
		if r, ok := t.Results[c.ID]; ok && r.IsError {
			continue
		}
		out = append(out, c.Skill)
	}
	return out
}

// skillFile は、スキルの置き場の SKILL.md などを指すパスから、スキルの名前を取り出す。
var skillFile = regexp.MustCompile(`(?:^|/)\.claude/skills/([^/]+)/`)

// ReadSkills は、Skill の道具を使わずに、スキルの置き場のファイルを読んだり探したりしたスキルの名前を返す。
// 「使った」には数えないが、判定の参考に記録する。
func (t *Transcript) ReadSkills() []string {
	seen := map[string]bool{}
	var out []string
	for _, c := range t.Calls {
		if c.Skill != "" {
			continue
		}
		for _, k := range []string{"file_path", "path", "pattern"} {
			v, _ := c.Input[k].(string)
			if m := skillFile.FindStringSubmatch(v); m != nil && !seen[m[1]] {
				seen[m[1]] = true
				out = append(out, m[1])
			}
		}
	}
	return out
}

type streamLine struct {
	Type       string          `json:"type"`
	Subtype    string          `json:"subtype"`
	IsError    bool            `json:"is_error"`
	Model      string          `json:"model"`
	Tools      []string        `json:"tools"`
	Skills     []string        `json:"skills"`
	MCPServers []namedEntry    `json:"mcp_servers"`
	Plugins    []namedEntry    `json:"plugins"`
	Message    json.RawMessage `json:"message"`
}

type namedEntry struct {
	Name string `json:"name"`
}

type messageBody struct {
	Content json.RawMessage `json:"content"`
}

type contentBlock struct {
	Type      string          `json:"type"`
	Text      string          `json:"text"`
	ID        string          `json:"id"`
	Name      string          `json:"name"`
	Input     map[string]any  `json:"input"`
	ToolUseID string          `json:"tool_use_id"`
	IsError   bool            `json:"is_error"`
	Content   json.RawMessage `json:"content"`
}

// ParseStreamJSON は、Claude Code の --output-format stream-json の出力を読む。
// 読めない行は飛ばす（ログの途中で切れた場合も、読めた所までを返す）。
func ParseStreamJSON(r io.Reader) (*Transcript, error) {
	t := &Transcript{Results: map[string]ToolResult{}}
	sc := bufio.NewScanner(r)
	sc.Buffer(make([]byte, 0, 1<<20), 64<<20)
	for sc.Scan() {
		var l streamLine
		if err := json.Unmarshal(sc.Bytes(), &l); err != nil {
			continue
		}
		switch l.Type {
		case "system":
			switch {
			case l.Subtype == "init":
				s := &Session{Model: l.Model, Tools: l.Tools, Skills: l.Skills}
				for _, m := range l.MCPServers {
					s.MCPServers = append(s.MCPServers, m.Name)
				}
				for _, p := range l.Plugins {
					s.Plugins = append(s.Plugins, p.Name)
				}
				t.Init = s
			case l.Subtype == "hook_started":
				t.Hooks++
			}
		case "result":
			t.ResultSubtype = l.Subtype
			t.ResultIsError = l.IsError
		case "assistant", "user":
			var m messageBody
			if err := json.Unmarshal(l.Message, &m); err != nil {
				continue
			}
			var blocks []contentBlock
			if err := json.Unmarshal(m.Content, &blocks); err != nil {
				continue
			}
			for _, b := range blocks {
				switch b.Type {
				case "tool_use":
					c := ToolCall{ID: b.ID, Name: b.Name, Input: b.Input}
					if b.Name == "Skill" {
						if s, ok := b.Input["skill"].(string); ok {
							c.Skill = strings.TrimPrefix(strings.TrimSpace(s), "/")
						}
					}
					t.Calls = append(t.Calls, c)
				case "text":
					if l.Type == "assistant" && t.FirstText == "" {
						t.FirstText = firstRunes(strings.TrimSpace(b.Text), 160)
					}
				case "tool_result":
					t.Results[b.ToolUseID] = ToolResult{IsError: b.IsError, Text: resultText(b.Content)}
				}
			}
		}
	}
	return t, sc.Err()
}

// Completed は、実行が想定どおりに終わったか（正常に終わったか、手番の上限で止まったか）。
// 認証切れや利用の上限などで誤りとして終わった回、result の行が無い回は false。
// 手番の上限で止まった回は is_error が付くが、試験ではそれが想定どおりなので true とする。
func (t *Transcript) Completed() bool {
	switch t.ResultSubtype {
	case "error_max_turns":
		return true
	case "success":
		return !t.ResultIsError
	}
	return false
}

func resultText(raw json.RawMessage) string {
	var s string
	if json.Unmarshal(raw, &s) == nil {
		return s
	}
	var parts []struct {
		Type string `json:"type"`
		Text string `json:"text"`
	}
	if json.Unmarshal(raw, &parts) == nil {
		var b strings.Builder
		for _, p := range parts {
			b.WriteString(p.Text)
		}
		return b.String()
	}
	return string(raw)
}

func firstRunes(s string, n int) string {
	r := []rune(strings.ReplaceAll(s, "\n", " "))
	if len(r) > n {
		r = r[:n]
	}
	return string(r)
}

// OutsideRef は、試験用リポジトリの外を指した道具の呼び出し。
type OutsideRef struct {
	Tool string `json:"tool"`
	Path string `json:"path"`
	// Denied は、その呼び出しが拒否されたか失敗した（中身を読んでいない）こと。
	Denied bool `json:"denied"`
}

// pathKeys は、道具の入力のうち、パスを表す項目。
var pathKeys = []string{"file_path", "path", "notebook_path"}

var absToken = regexp.MustCompile(`(?:^|[\s"'=:(])([/~][^\s"'|;&)]*)`)

// allowedOutside は、外を指していても試験の条件を崩さないパス。
var allowedOutside = []string{"/dev/null"}

// OutsideRefs は、リポジトリ root の外を指す呼び出しを返す。
// 見るのは、パスの項目、Glob のパターン、シェルのコマンドの中の絶対パス・「~」・「..」。
// Grep のパターンは正規表現なので見ない。道具を通らない読み込み（設定や指示のファイル）は、ここでは拾えない。
func (t *Transcript) OutsideRefs(root string) []OutsideRef {
	root = filepath.Clean(root)
	var out []OutsideRef
	for _, c := range t.Calls {
		var cands []string
		for _, k := range pathKeys {
			if v, ok := c.Input[k].(string); ok && v != "" {
				cands = append(cands, v)
			}
		}
		if c.Name == "Glob" {
			if v, ok := c.Input["pattern"].(string); ok {
				cands = append(cands, v)
			}
		}
		if v, ok := c.Input["command"].(string); ok {
			for _, m := range absToken.FindAllStringSubmatch(v, -1) {
				cands = append(cands, m[1])
			}
			for _, f := range strings.Fields(v) {
				if f == ".." || strings.HasPrefix(f, "../") || strings.Contains(f, "/../") {
					cands = append(cands, f)
				}
			}
		}
		for _, p := range cands {
			if !isOutside(root, p) {
				continue
			}
			res, ok := t.Results[c.ID]
			out = append(out, OutsideRef{Tool: c.Name, Path: p, Denied: ok && isDenied(res)})
		}
	}
	return out
}

func isOutside(root, p string) bool {
	for _, a := range allowedOutside {
		if p == a {
			return false
		}
	}
	if p == "~" || strings.HasPrefix(p, "~/") {
		return true
	}
	var abs string
	if filepath.IsAbs(p) {
		abs = filepath.Clean(p)
	} else {
		abs = filepath.Join(root, p)
	}
	rel, err := filepath.Rel(root, abs)
	if err != nil {
		return true
	}
	return rel == ".." || strings.HasPrefix(rel, "../")
}

// isDenied は、応答が拒否か失敗だったか。主に is_error を見る。
// is_error が無い形のために、応答の先頭が拒否や道具の誤りの決まった文のときも拒否とする
// （読めた中身の途中に同じ文字列があっても、拒否とはみなさない）。
func isDenied(r ToolResult) bool {
	if r.IsError {
		return true
	}
	t := strings.TrimSpace(r.Text)
	return strings.HasPrefix(t, "Claude requested permissions") ||
		strings.HasPrefix(t, "<tool_use_error>")
}
