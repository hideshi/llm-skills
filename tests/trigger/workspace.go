package trigger

import (
	"bytes"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// Workspace は、試験用の隔離したリポジトリ。親フォルダには、ほかに何も置かない。
type Workspace struct {
	// Dir は、一時的に作った親フォルダ（リンクを辿った実体のパス）。
	Dir string
	// Repo は、試験用リポジトリの根。
	Repo string
	// Skills は、置き場に置いたスキルの名前。
	Skills []string
}

// SkillDir は、試す道具がスキルを読む置き場（リポジトリの根からの相対パス）。
const SkillDir = ".claude/skills"

// NewWorkspace は、一時フォルダに試験用リポジトリを作る。
// skillsRoot の下のスキルを、リンクを辿った実体でコピーして SkillDir だけに置き、
// fixtureDir の中身を根に置いて、最初の状態をコミットする。
func NewWorkspace(skillsRoot, fixtureDir string) (*Workspace, error) {
	dir, err := os.MkdirTemp("", "skill-trigger-*")
	if err != nil {
		return nil, err
	}
	// macOS の /var → /private/var のように、一時フォルダがリンクを含むことがある。
	// CLI は実体のパスで作業するので、外の参照の判定と合わせるために実体のパスにする。
	real, err := filepath.EvalSymlinks(dir)
	if err != nil {
		os.RemoveAll(dir)
		return nil, err
	}
	w := &Workspace{Dir: real, Repo: filepath.Join(real, "repo")}
	if err := w.build(skillsRoot, fixtureDir); err != nil {
		os.RemoveAll(real)
		return nil, err
	}
	return w, nil
}

func (w *Workspace) build(skillsRoot, fixtureDir string) error {
	entries, err := os.ReadDir(skillsRoot)
	if err != nil {
		return err
	}
	for _, e := range entries {
		src := filepath.Join(skillsRoot, e.Name())
		st, err := os.Stat(src)
		if err != nil || !st.IsDir() {
			continue
		}
		if _, err := os.Stat(filepath.Join(src, "SKILL.md")); err != nil {
			continue // 共有の参照だけのフォルダ（SKILL.md が無いもの）も置くが、スキルとしては数えない
		}
		w.Skills = append(w.Skills, e.Name())
	}
	for _, e := range entries {
		src := filepath.Join(skillsRoot, e.Name())
		if st, err := os.Stat(src); err != nil || !st.IsDir() {
			continue
		}
		if err := copyTree(src, filepath.Join(w.Repo, SkillDir, e.Name())); err != nil {
			return err
		}
	}
	if err := copyTree(fixtureDir, w.Repo); err != nil {
		return err
	}
	for _, args := range [][]string{
		{"init", "-q", "-b", "main"},
		{"add", "-A"},
		{"commit", "-qm", "init"},
	} {
		if err := w.git(args...); err != nil {
			return err
		}
	}
	return nil
}

// Reset は、リポジトリを最初の状態に戻し（無視されるファイルも消す）、overlay があれば上書きする。
func (w *Workspace) Reset(overlay string) error {
	if err := w.git("reset", "-q", "--hard"); err != nil {
		return err
	}
	if err := w.git("clean", "-qfdx"); err != nil {
		return err
	}
	if overlay != "" {
		return copyTree(overlay, w.Repo)
	}
	return nil
}

// Remove は、一時フォルダを消す。
func (w *Workspace) Remove() error { return os.RemoveAll(w.Dir) }

// gitEnv は、利用者の git の環境（GIT_DIR などの変数、全体と system の設定）を持ち込まない環境を返す。
// git のフックの中から試験を流しても、本物のリポジトリを触らないようにする。
func gitEnv() []string {
	var env []string
	for _, kv := range os.Environ() {
		if strings.HasPrefix(kv, "GIT_") {
			continue
		}
		env = append(env, kv)
	}
	return append(env,
		"GIT_CONFIG_GLOBAL="+os.DevNull,
		"GIT_CONFIG_NOSYSTEM=1",
		"GIT_AUTHOR_NAME=trigger-test", "GIT_AUTHOR_EMAIL=trigger-test@example.invalid",
		"GIT_COMMITTER_NAME=trigger-test", "GIT_COMMITTER_EMAIL=trigger-test@example.invalid",
	)
}

func (w *Workspace) git(args ...string) error {
	full := append([]string{"-c", "commit.gpgsign=false", "-c", "core.hooksPath=" + os.DevNull}, args...)
	cmd := exec.Command("git", full...)
	cmd.Dir = w.Repo
	cmd.Env = gitEnv()
	var stderr bytes.Buffer
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("git %s: %w: %s", strings.Join(args, " "), err, stderr.String())
	}
	return nil
}

// copyTree は、src の中身を dst へコピーする。リンクは辿って実体をコピーする。
func copyTree(src, dst string) error {
	st, err := os.Stat(src)
	if err != nil {
		return err
	}
	if !st.IsDir() {
		return copyFile(src, dst, st.Mode())
	}
	if err := os.MkdirAll(dst, 0o755); err != nil {
		return err
	}
	entries, err := os.ReadDir(src)
	if err != nil {
		return err
	}
	for _, e := range entries {
		if err := copyTree(filepath.Join(src, e.Name()), filepath.Join(dst, e.Name())); err != nil {
			return err
		}
	}
	return nil
}

func copyFile(src, dst string, mode os.FileMode) error {
	if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
		return err
	}
	in, err := os.Open(src)
	if err != nil {
		return err
	}
	defer in.Close()
	out, err := os.OpenFile(dst, os.O_CREATE|os.O_TRUNC|os.O_WRONLY, mode.Perm())
	if err != nil {
		return err
	}
	if _, err := io.Copy(out, in); err != nil {
		out.Close()
		return err
	}
	return out.Close()
}
