-- 型の結びつきと、抜け漏れの検査 1〜8、16〜22 のモデル。
-- 正本は skills/dev-shared/references/artifact-types.md の「識別子と結びつき」。
-- ここは写しで、通常の道の検査 1〜8、16〜22 と、それが支える結びつきだけを表す。
-- 表さないもの: 軽い道、ドメインモデル（検査 9、10）、画面（11〜13）、文面（14、15）、
--   変更の事実、確認事項、一次情報、ドメインイベント、識別子の書き方、文の中身、
--   廃止したテストケースと作業（検査は廃止していないものだけを見るので、モデルのケースと作業は
--   どれも廃止していないものとする）、「決定待ち」の作業。
-- 「今回の範囲」は、モデルの中のものすべてとする。
-- 結びつきの表の多さ（「1つ以上」など）は事実にせず、述語にして、検査を通れば成り立つかを主張で確かめる。
-- 2段目（2026-11-19）: 1段目で見つけた穴の候補を、持ち主の決定に沿って検査 1〜3、8 の直しと
--   16〜22 で塞いだ。H3 は塞がない（作業がほかの受入条件のケースを結んでもよい。19 で H1・H2 は成り立つ）。
--   レビュー後の決定（検査 4・17・19 の直し、廃止したケースと作業の扱い）は README の「2段目の決定」。

-- 要件と受入条件 ---------------------------------------------------------

sig Requirement {}
sig RetiredReq in Requirement {}          -- 廃止の印

sig AC {
  acReq: set Requirement,                 -- 受入条件 → 要件（表では1つ以上。検査に項目が無いので述語 ACHasReq）
  acRules: set Rule                       -- 受入条件 → 業務規則（0以上）
}
sig RetiredAC in AC {}                    -- 廃止の印
sig NegAC in AC {}                        -- 否定を含む受入条件
sig NoTestReasonAC in AC {}               -- テストで確かめない理由が書いてある

-- 結びつきの表: 受入条件 → 要件は 1つ以上。検査 16 が見る（1段目は項目が無かったので、主張 H12 で確かめる述語にした）。
pred ACHasReq { all a: AC | some a.acReq }

-- 出どころ（問題台帳の問題、回帰の基準の検証点など。種類は区別しない）
sig Origin {}

-- テストケース -------------------------------------------------------------

sig TC {
  tcAcs: set AC,                          -- テストケース → 受入条件
  tcOrigin: lone Origin,
  tcRules: set Rule                       -- テストケース → 業務規則（確かめる規則）
}
sig NegTC in TC {}                        -- 否定のケース
sig ViolTC in TC {}                       -- 規則を破るケース（ほかは満たすケース。印はケースごと）
sig NewTC in TC {}                        -- 今回新しく足すケース
sig PassedTC in TC {}                     -- 通った記録がある

-- 結びつきの表: テストケース → 受入条件は 1つ以上（無ければ出どころ）。検査 17 が見る（1段目は項目が無かったので、主張 H9 で確かめる述語にした）。
pred TCHasSource { all t: TC | some t.tcAcs or some t.tcOrigin }

-- 作業 --------------------------------------------------------------------

sig Task {
  taskAcs: set AC,                        -- 作業 → 受入条件
  taskOrigin: lone Origin,
  taskTests: set TC,                      -- 作業 → テストケース（足す・通すケース）
  deps: set Task                          -- 作業 → 作業（先に終わっている必要がある作業）
}
sig DoneTask in Task {}                   -- 終わったとする作業

-- 業務規則と設計の判断 ----------------------------------------------------

abstract sig Certainty {}
one sig Confirmed, Hypothesis, Undecided, Pending extends Certainty {}
abstract sig Means {}
one sig ByTest, ByOther extends Means {}

sig Rule {
  cert: one Certainty,                    -- 確かさ
  means: one Means                        -- 確かめる手段
}
sig RetiredRule in Rule {}
sig ApprovedPending in Rule {}            -- 保留に、了承の記録と期限がある
sig OtherWithReason in Rule {}            -- テストで確かめない規則に、手段と理由がある

sig DD { ddRules: set Rule }              -- 設計の判断 → 業務規則

-- 有効な規則: 廃止されておらず、確かさが確定か、了承と期限のある保留
fun validRules: set Rule {
  { r: Rule - RetiredRule | r.cert = Confirmed or (r.cert = Pending and r in ApprovedPending) }
}
fun satTCs[r: Rule]: set TC { tcRules.r - ViolTC }
fun violTCs[r: Rule]: set TC { tcRules.r & ViolTC }

-- 抜け漏れの検査 1〜8、16〜22（文のとおりに写す） ---------------------------

fun liveAC: set AC { AC - RetiredAC }
fun liveReq: set Requirement { Requirement - RetiredReq }

-- 1. 廃止していない要件のすべてに、廃止していない受入条件が1つ以上ある。
pred C1 { all q: liveReq | some (acReq.q & liveAC) }

-- 2. 廃止していない受入条件のすべてに、テストケースが1つ以上ある。無ければ、テストで確かめない理由が
--    書いてある。否定を含む受入条件には、否定のケースがある（テストで確かめない理由があるものは除く）。
pred C2 {
  all a: liveAC | some tcAcs.a or a in NoTestReasonAC
  all a: (NegAC & liveAC) - NoTestReasonAC | some (tcAcs.a & NegTC)
}

-- 3. 廃止していない受入条件のすべてが、どれかの作業に結ばれている。
pred C3 { all a: liveAC | some taskAcs.a }

-- 4. すべての作業に、廃止していない受入条件か出どころがある。
pred C4 { all k: Task | some (k.taskAcs & liveAC) or some k.taskOrigin }

-- 5. 新しく足すテストケースは、どれかの作業に結ばれている。
pred C5 { all t: NewTC | some taskTests.t }

-- 6. 終わったとする作業は、結んだテストケースが通った記録を持つ。
pred C6 { all k: DoneTask | k.taskTests in PassedTC }

-- 7. 今回の範囲で有効な業務規則のうち、確かめる手段がテストのものには、満たすケースと破るケースが
--    それぞれ1つ以上ある。テストで確かめない規則には、手段と理由がある。（第2文も有効な規則に限る読み）
pred C7 {
  all r: validRules |
    (r.means = ByTest implies (some satTCs[r] and some violTCs[r]))
    and (r.means = ByOther implies r in OtherWithReason)
}

-- 8. 廃止していない受入条件と、設計の判断が指す業務規則は、存在し、廃止されておらず、確かさが
--    仮説・未確定でない（保留は、了承の記録と期限があるときだけ）。「存在し」は表せない（指す先は必ず Rule）。
pred C8 { (liveAC.acRules + DD.ddRules) in validRules }

-- 16. すべての受入条件が、どれかの要件に属する。廃止していない受入条件は、廃止していない要件に属する。
pred C16 { ACHasReq and all a: liveAC | some (a.acReq & liveReq) }

-- 17. すべてのテストケースに、廃止していない受入条件か出どころがある。
pred C17 { all t: TC | some (t.tcAcs & liveAC) or some t.tcOrigin }

-- 18. テストケースが確かめる業務規則は、8 と同じく有効である。
pred C18 { TC.tcRules in validRules }

-- 19. 廃止しておらず、テストで確かめない理由の無い受入条件は、結んだ作業がすべて終わったとするとき、
--     結ばれたテストケースのどれもが通った記録を持つ（否定を含むものは、否定のケースも含む）。
--     「結んだ作業がすべて」は、結んだ作業が1つ以上あるときとする（無ければ検査 3 が指摘する）。
pred C19 {
  all a: liveAC - NoTestReasonAC |
    (some taskAcs.a and taskAcs.a in DoneTask) implies tcAcs.a in PassedTC
}

-- 20. 作業をすべて終えたとするときは、7 で満たすケースと破るケースを求めた業務規則について、
--     満たすケースと破るケースがそれぞれ1つ以上、通った記録を持つ。
pred C20 {
  (some Task and Task = DoneTask) implies all r: validRules |
    r.means = ByTest implies (some (satTCs[r] & PassedTC) and some (violTCs[r] & PassedTC))
}

-- 21. 終わったとする作業の、先に終わっている必要がある作業は、終わっている。
pred C21 { DoneTask.deps in DoneTask }

-- 22. 作業の依存に輪が無い（自分自身への依存を含む）。
pred C22 { no k: Task | k in k.^deps }

pred AllChecks {
  C1 and C2 and C3 and C4 and C5 and C6 and C7 and C8
  C16 and C17 and C18 and C19 and C20 and C21 and C22
}

-- 決まりが矛盾していないか（全部を満たす、空でない例が作れるか） -----------

run NonEmpty {
  AllChecks
  some Requirement and some NegAC and some DoneTask and some NewTC
  some r: validRules | r.means = ByTest
  some r: validRules | r.cert = Pending
  some DD.ddRules
} for 5

-- 検査が保証していること（成り立つはず。検査を1つ外すと破れることを崩した写しで確かめる） ---

-- G1（検査 1〜3）どの要件も、テストか理由を持ち作業に結ばれた受入条件まで辿れる。
assert ReqTraceable {
  AllChecks implies all q: liveReq |
    some a: acReq.q & liveAC | (some tcAcs.a or a in NoTestReasonAC) and some taskAcs.a
}
check ReqTraceable for 5

-- G2（検査 4）どの作業も、受入条件か出どころまで辿れる。
assert TaskTraceable { AllChecks implies all k: Task | some k.taskAcs + k.taskOrigin }
check TaskTraceable for 5

-- G3（1段目は検査 2、5、6。2段目は検査 3、19 が支える）ケースが全部新しく、作業が全部終われば、テストで確かめる受入条件に通ったケースがある。
assert AllNewDoneMeansACTested {
  (AllChecks and TC = NewTC and Task = DoneTask) implies
    all a: liveAC - NoTestReasonAC | some (tcAcs.a & PassedTC)
}
check AllNewDoneMeansACTested for 5

-- G4（検査 7）有効でテストで確かめる規則には、満たすケースと破るケースがある。
--     有効でテストで確かめない規則には、手段と理由がある。
assert ValidTestRulesHaveBothCases {
  AllChecks implies all r: validRules |
    (r.means = ByTest implies (some satTCs[r] and some violTCs[r])) and
    (r.means = ByOther implies r in OtherWithReason)
}
check ValidTestRulesHaveBothCases for 5

-- G5（検査 8）受入条件と設計の判断が指す規則に、廃止したもの、仮説・未確定のもの、了承の無い保留が無い。
assert PointedRulesUsable {
  AllChecks implies no (liveAC.acRules + DD.ddRules) &
    (RetiredRule + cert.(Hypothesis + Undecided) + (cert.Pending - ApprovedPending))
}
check PointedRulesUsable for 5

-- 1段目の穴の候補（2段目の検査で成り立つはず。H3 だけは塞がず、反例が残る） ---
-- 受入条件は、廃止していないものを見る（持ち主の決定: 廃止したものには求めない）。

-- H1. 作業が全部終われば、テストで確かめる受入条件には、通ったケースがある。
assert AllDoneMeansACTested {
  (AllChecks and Task = DoneTask) implies
    all a: liveAC - NoTestReasonAC | some (tcAcs.a & PassedTC)
}
check AllDoneMeansACTested for 5

-- H2. ケースが全部新しくても、受入条件に結んだ作業が全部終われば、その受入条件に通ったケースがある。
assert ACTasksDoneMeansTested {
  (AllChecks and TC = NewTC) implies
    all a: liveAC - NoTestReasonAC | (taskAcs.a in DoneTask) implies some (tcAcs.a & PassedTC)
}
check ACTasksDoneMeansTested for 5

-- H3. 作業が結ぶケースは、受入条件に結ばれていれば、その作業の受入条件のケースである。
assert TaskTestsMatchACs {
  AllChecks implies all k: Task, t: k.taskTests | some t.tcAcs implies some (t.tcAcs & k.taskAcs)
}
check TaskTestsMatchACs for 5

-- H4. 作業が全部終われば、否定を含む受入条件の否定のケースが通っている。
assert NegACNegTestPassed {
  (AllChecks and Task = DoneTask) implies all a: (NegAC & liveAC) - NoTestReasonAC | some (tcAcs.a & NegTC & PassedTC)
}
check NegACNegTestPassed for 5

-- H5. 作業が全部終われば、有効でテストで確かめる規則の、満たすケースと破るケースが通っている。
assert RuleCasesPassedWhenDone {
  (AllChecks and some Task and Task = DoneTask) implies all r: validRules |
    r.means = ByTest implies (some (satTCs[r] & PassedTC) and some (violTCs[r] & PassedTC))
}
check RuleCasesPassedWhenDone for 5

-- H6. 廃止されていない要件には、廃止されていない受入条件がある。
assert LiveReqHasLiveAC {
  AllChecks implies all q: Requirement - RetiredReq | some (acReq.q - RetiredAC)
}
check LiveReqHasLiveAC for 5

-- H7. 廃止されていない受入条件は、廃止されていない要件に属する。
assert LiveACHasLiveReq {
  AllChecks implies all a: AC - RetiredAC | some (a.acReq - RetiredReq)
}
check LiveACHasLiveReq for 5

-- H8. テストケースが確かめる業務規則も、有効な規則である（検査 8 は受入条件と設計の判断だけを見る）。
assert TCRulesValid { AllChecks implies TC.tcRules in validRules }
check TCRulesValid for 5

-- H9. 検査を通れば、テストケースに受入条件か出どころがある（結びつきの表の決まり）。
assert TCHasSourceByChecks { AllChecks implies TCHasSource }
check TCHasSourceByChecks for 5

-- H12. 検査を通れば、受入条件はどれかの要件に属する（結びつきの表の決まり）。
assert ACHasReqByChecks { AllChecks implies ACHasReq }
check ACHasReqByChecks for 5

-- H10. 終わったとする作業の、先に終わっている必要がある作業も、終わっている。
assert DoneDepsDone { AllChecks implies all k: DoneTask | k.deps in DoneTask }
check DoneDepsDone for 5

-- H11. 作業の依存に輪が無い（自分自身を含む）。
assert NoDepCycle { AllChecks implies no k: Task | k in k.^deps }
check NoDepCycle for 5

-- 決まりが強すぎないか（廃止したものの扱い。例が無ければ、廃止したものにも求めている） ---

-- S1. 廃止した受入条件を、作業に結ばずに残せる。
run RetiredACWithoutTask { AllChecks and some a: RetiredAC | no taskAcs.a } for 5

-- S2. 廃止した受入条件を、テストケースも理由も無いまま残せる。
run RetiredACWithoutTestOrReason {
  AllChecks and some a: RetiredAC | no tcAcs.a and a not in NoTestReasonAC
} for 5

-- S3. 廃止した要件を、受入条件なしで残せる。
run RetiredReqWithoutAC { AllChecks and some q: RetiredReq | no acReq.q } for 5

-- S4. 廃止した受入条件が、廃止した規則を指したまま残せる。
run RetiredACPointsRetiredRule {
  AllChecks and some a: RetiredAC | some (a.acRules & RetiredRule)
} for 5

-- S5. 理由のある否定を含む受入条件を、否定のケースなしで残せる（検査 2 の第3文の読みの確かめ）。
run NegACWithReasonNoNegTC {
  AllChecks and some a: (NegAC & NoTestReasonAC) - RetiredAC | no (tcAcs.a & NegTC)
} for 5

-- 2段目のレビュー（P-458）を受けて足した確かめ ---------------------------------

-- H13. 作業が全部終われば、廃止していない、理由の無い受入条件のテストケースは、作業に結ばれていない
--      前からあるものも含めて、どれも通っている（検査 19 の「どれも」）。
assert AllACTestsPassedWhenDone {
  (AllChecks and Task = DoneTask) implies all a: liveAC - NoTestReasonAC | tcAcs.a in PassedTC
}
check AllACTestsPassedWhenDone for 5

-- S6. 受入条件を2つの作業に結び、片方だけ終わった時点では、テストがまだ通っていなくてよい
--     （共通の土台の作業を先に終えられる）。
run SharedACOneTaskDone {
  AllChecks and some a: liveAC - NoTestReasonAC |
    some (taskAcs.a & DoneTask) and some (taskAcs.a - DoneTask) and some (tcAcs.a - PassedTC)
} for 5

-- S7. 出どころが無く、廃止した受入条件だけに結ばれた作業を残せる（期待: 例なし。検査 4）。
run TaskOnlyRetiredAC {
  AllChecks and some k: Task | some k.taskAcs and k.taskAcs in RetiredAC and no k.taskOrigin
} for 5

-- S8. 出どころが無く、廃止した受入条件だけに結ばれたテストケースを残せる（期待: 例なし。検査 17）。
run TCOnlyRetiredAC {
  AllChecks and some t: TC | some t.tcAcs and t.tcAcs in RetiredAC and no t.tcOrigin
} for 5
