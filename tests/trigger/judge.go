package trigger

import (
	"fmt"
	"slices"
	"strings"
)

// Route は、合格した回の経路。
type Route string

const (
	RouteDirect    Route = "直接"     // 最初に accept のスキルを使った
	RouteViaRouter Route = "経由"     // 振り分け役を使ってから accept のスキルを使った
	RouteRouteOnly Route = "振り分けまで" // 振り分け役だけを使い、ほかのスキルを使わずに終わった
	RouteAbstain   Route = "不使用"    // accept の無い試験で、禁じたスキルを使わなかった
)

// Verdict は、1回の実行の判定。
type Verdict struct {
	Pass   bool
	Route  Route
	Reason string
}

// Judge は、使ったスキルの並びを、試験の定義と突き合わせる。
//
//   - 禁じた頭のスキルを一度でも使えば不合格。
//   - accept が無い試験は、禁じたスキルを使わなければ合格。
//   - 先頭に続く profiles のスキル（振り分け役）を読み飛ばし、その次のスキルが accept にあれば合格。
//   - 振り分け役だけを使い、ほかのスキルを使わずに終われば合格（手番の上限で振り分けまでしか進まない回）。
func Judge(c Case, skills []string) Verdict {
	for _, s := range skills {
		for _, p := range c.ForbidPrefixes {
			if strings.HasPrefix(s, p) {
				return Verdict{Pass: false, Reason: fmt.Sprintf("禁じたスキル %s を使った", s)}
			}
		}
	}
	if len(c.Accept) == 0 {
		return Verdict{Pass: true, Route: RouteAbstain, Reason: "禁じたスキルを使わなかった"}
	}
	if len(skills) == 0 {
		return Verdict{Pass: false, Reason: "スキルを使わなかった"}
	}
	i := 0
	for i < len(skills) && slices.Contains(c.Profiles, skills[i]) && !slices.Contains(c.Accept, skills[i]) {
		i++
	}
	switch {
	case i == len(skills):
		return Verdict{Pass: true, Route: RouteRouteOnly, Reason: skills[0] + " だけ（振り分けまで）"}
	case slices.Contains(c.Accept, skills[i]) && i == 0:
		return Verdict{Pass: true, Route: RouteDirect, Reason: "最初に " + skills[i]}
	case slices.Contains(c.Accept, skills[i]):
		return Verdict{Pass: true, Route: RouteViaRouter, Reason: strings.Join(skills[:i+1], " → ")}
	case i > 0:
		return Verdict{Pass: false, Reason: fmt.Sprintf("%s の後に %s", strings.Join(skills[:i], " → "), skills[i])}
	}
	return Verdict{Pass: false, Reason: "最初に " + skills[0]}
}
