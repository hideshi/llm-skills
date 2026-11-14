//go:build !unix

package trigger

import "os/exec"

// setProcessGroup は、unix 以外では何もしない（時間切れのとき、CLI の子が残ることがある）。
func setProcessGroup(cmd *exec.Cmd) {}
