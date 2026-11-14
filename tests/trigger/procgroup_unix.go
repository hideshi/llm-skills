//go:build unix

package trigger

import (
	"os/exec"
	"syscall"
)

// setProcessGroup は、CLI を新しいプロセスの組で起動し、取り消しのときは組ごと止める。
// CLI が起こした子（フック、MCP のサーバーなど）を時間切れの後に残さないため。
func setProcessGroup(cmd *exec.Cmd) {
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	cmd.Cancel = func() error {
		if cmd.Process == nil {
			return nil
		}
		return syscall.Kill(-cmd.Process.Pid, syscall.SIGKILL)
	}
}
