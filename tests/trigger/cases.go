// Package trigger は、一言の依頼からどのスキルが起動するかを確かめる試験の、定義・ログの読み取り・判定・実行を持つ。
package trigger

import (
	"encoding/json"
	"fmt"
	"os"
	"regexp"
	"slices"
	"strings"
)

// Job は、1回の実行。
type Job struct {
	Suite   Suite
	Case    Case
	Model   string
	Attempt int
}

// SelectJobs は、流すまとまり・ID・モデル・回数から、実行の一覧を作る。
// suites と ids が空なら全部。定義に無いまとまりや ID を指定したら誤りにする（打ち間違いを黙って無視しない）。
func (d *Definition) SelectJobs(suites, ids, models []string, runs int) ([]Job, error) {
	if len(models) == 0 {
		return nil, fmt.Errorf("流すモデルが無い")
	}
	if runs < 1 {
		return nil, fmt.Errorf("回数は1以上")
	}
	knownSuite := map[string]bool{}
	knownID := map[string]bool{}
	for _, s := range d.Suites {
		knownSuite[s.Name] = true
		for _, c := range s.Cases {
			knownID[c.ID] = true
		}
	}
	for _, s := range suites {
		if !knownSuite[s] {
			return nil, fmt.Errorf("まとまり %q が定義に無い", s)
		}
	}
	for _, id := range ids {
		if !knownID[id] {
			return nil, fmt.Errorf("ID %q が定義に無い", id)
		}
	}
	var jobs []Job
	for _, s := range d.Suites {
		if len(suites) > 0 && !slices.Contains(suites, s.Name) {
			continue
		}
		for _, c := range s.Cases {
			if len(ids) > 0 && !slices.Contains(ids, c.ID) {
				continue
			}
			for _, m := range models {
				for a := 1; a <= runs; a++ {
					jobs = append(jobs, Job{s, c, m, a})
				}
			}
		}
	}
	if len(jobs) == 0 {
		return nil, fmt.Errorf("指定したまとまりと ID に当たる試験が無い")
	}
	return jobs, nil
}

// Case は、一言の依頼と、合格とするスキルの組。
type Case struct {
	ID     string `json:"id"`
	Prompt string `json:"prompt"`
	// Accept は、最初に使えば合格とするスキル。
	Accept []string `json:"accept,omitempty"`
	// Profiles は、振り分けのために先に使ってよいスキル（プロファイル）。
	// 先に使ったときは、次に使ったスキルが Accept にあるか、ほかのスキルを使わずに終われば合格。
	Profiles []string `json:"profiles,omitempty"`
	// ForbidPrefixes は、一度でも使えば不合格とするスキルの名前の頭。
	ForbidPrefixes []string `json:"forbidPrefixes,omitempty"`
	Note           string   `json:"note,omitempty"`
}

// Suite は、同じ材料と同じ記録の文書を使う試験のまとまり。
type Suite struct {
	Name string `json:"name"`
	// Doc は、試験の表と実施の記録を置く文書（リポジトリの根からの相対パス）。
	Doc string `json:"doc"`
	// Overlay は、各回の前に試験用リポジトリへ上書きする材料（このパッケージからの相対パス）。
	// 未コミットの変更（「この変更」）を作るのに使う。空なら上書きしない。
	Overlay string `json:"overlay,omitempty"`
	// DocOnly は、文書の表にはあるが、この試験では流さない ID（別の手順で試すもの）。
	DocOnly []string `json:"docOnly,omitempty"`
	Cases   []Case   `json:"cases"`
}

// Definition は、試験の定義の全体。
type Definition struct {
	Suites []Suite `json:"suites"`
}

// LoadDefinition は、試験の定義を読み込む。
func LoadDefinition(path string) (*Definition, error) {
	b, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	var d Definition
	dec := json.NewDecoder(strings.NewReader(string(b)))
	dec.DisallowUnknownFields()
	if err := dec.Decode(&d); err != nil {
		return nil, fmt.Errorf("%s: %w", path, err)
	}
	return &d, nil
}

var idPattern = regexp.MustCompile(`^[A-Z][A-Z0-9]*$`)

// Validate は、定義の書き方の誤りを返す。skillExists はスキルの名前が実在するかを、
// dirExists は overlay のフォルダ（このパッケージからの相対パス）があるかを答える。
func (d *Definition) Validate(skillExists, dirExists func(string) bool) []error {
	var errs []error
	seen := map[string]string{}
	for _, s := range d.Suites {
		if s.Name == "" || s.Doc == "" {
			errs = append(errs, fmt.Errorf("まとまりに name か doc が無い: %+v", s.Name))
		}
		if len(s.Cases) == 0 {
			errs = append(errs, fmt.Errorf("%s: 試験が一つも無い", s.Name))
		}
		if s.Overlay != "" && !dirExists(s.Overlay) {
			errs = append(errs, fmt.Errorf("%s: overlay %q が無い", s.Name, s.Overlay))
		}
		for _, c := range s.Cases {
			where := s.Name + "/" + c.ID
			if !idPattern.MatchString(c.ID) {
				errs = append(errs, fmt.Errorf("%s: ID の形が違う", where))
			}
			if prev, ok := seen[c.ID]; ok {
				errs = append(errs, fmt.Errorf("%s: ID が %s と重なる", where, prev))
			}
			seen[c.ID] = s.Name
			if strings.TrimSpace(c.Prompt) == "" {
				errs = append(errs, fmt.Errorf("%s: 依頼文が空", where))
			}
			if len(c.Accept) == 0 && len(c.ForbidPrefixes) == 0 {
				errs = append(errs, fmt.Errorf("%s: accept も forbidPrefixes も無い", where))
			}
			if strings.HasPrefix(strings.TrimSpace(c.Prompt), "/") {
				errs = append(errs, fmt.Errorf("%s: 依頼文が / で始まる（スラッシュコマンドとして扱われる）", where))
			}
			if len(c.Accept) == 0 && len(c.Profiles) > 0 {
				errs = append(errs, fmt.Errorf("%s: accept が無いのに profiles がある", where))
			}
			for _, p := range c.Profiles {
				if slices.Contains(c.Accept, p) {
					errs = append(errs, fmt.Errorf("%s: %q が accept と profiles の両方にある", where, p))
				}
			}
			for _, p := range c.ForbidPrefixes {
				if strings.TrimSpace(p) == "" {
					errs = append(errs, fmt.Errorf("%s: forbidPrefixes に空の頭がある（すべてのスキルに当たる）", where))
				}
			}
			for _, name := range append(append([]string{}, c.Accept...), c.Profiles...) {
				if !skillExists(name) {
					errs = append(errs, fmt.Errorf("%s: スキル %q が無い", where, name))
				}
				for _, p := range c.ForbidPrefixes {
					if strings.HasPrefix(name, p) {
						errs = append(errs, fmt.Errorf("%s: %q が禁じた頭 %q に当たる", where, name, p))
					}
				}
			}
		}
	}
	return errs
}
