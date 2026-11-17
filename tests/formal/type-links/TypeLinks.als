-- 型の結びつきと、抜け漏れの検査 1〜8 のモデル（試行）。
-- 正本は skills/dev-shared/references/artifact-types.md の「識別子と結びつき」。
-- ここは写しで、通常の道の検査 1〜8 と、それが支える結びつきだけを表す。
-- 表さないもの: 軽い道、ドメインモデル（検査 9、10）、画面（11〜13）、文面（14、15）、
--   変更の事実、確認事項、一次情報、ドメインイベント、識別子の書き方、文の中身、
--   廃止したテストケースと作業、「決定待ち」の作業。
-- 「今回の範囲」は、モデルの中のものすべてとする。
-- 結びつきの表の多さ（「1つ以上」など）のうち、検査 1〜8 に項目の無いものは事実にせず、述語にして、
--   検査を通れば成り立つかを主張で確かめる。

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

-- 結びつきの表: 受入条件 → 要件は 1つ以上。検査 1〜8 に項目が無い（検査 1 は逆向き）ので述語。
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

-- 結びつきの表: テストケース → 受入条件は 1つ以上（無ければ出どころ）。検査 1〜8 に項目が無いので述語。
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

-- 抜け漏れの検査 1〜8（文のとおりに写す） -----------------------------------

-- 1. すべての要件に、受入条件が1つ以上ある。
pred C1 { all q: Requirement | some acReq.q }

-- 2. すべての受入条件に、テストケースが1つ以上ある。無ければ、テストで確かめない理由が書いてある。
--    否定を含む受入条件には、否定のケースがある。（理由の有無によらず否定のケースを求める読み）
pred C2 {
  all a: AC | some tcAcs.a or a in NoTestReasonAC
  all a: NegAC | some (tcAcs.a & NegTC)
}

-- 3. すべての受入条件が、どれかの作業に結ばれている。
pred C3 { all a: AC | some taskAcs.a }

-- 4. すべての作業に、受入条件か出どころがある。
pred C4 { all k: Task | some k.taskAcs or some k.taskOrigin }

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

-- 8. 受入条件と設計の判断が指す業務規則は、存在し、廃止されておらず、確かさが仮説・未確定でない
--    （保留は、了承の記録と期限があるときだけ）。「存在し」は表せない（指す先は必ず Rule）。
pred C8 { (AC.acRules + DD.ddRules) in validRules }

pred AllChecks { C1 and C2 and C3 and C4 and C5 and C6 and C7 and C8 }

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
  AllChecks implies all q: Requirement |
    some a: acReq.q | (some tcAcs.a or a in NoTestReasonAC) and some taskAcs.a
}
check ReqTraceable for 5

-- G2（検査 4）どの作業も、受入条件か出どころまで辿れる。
assert TaskTraceable { AllChecks implies all k: Task | some k.taskAcs + k.taskOrigin }
check TaskTraceable for 5

-- G3（検査 2、5、6）ケースが全部新しく、作業が全部終われば、テストで確かめる受入条件に通ったケースがある。
assert AllNewDoneMeansACTested {
  (AllChecks and TC = NewTC and Task = DoneTask) implies
    all a: AC - NoTestReasonAC | some (tcAcs.a & PassedTC)
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
  AllChecks implies no (AC.acRules + DD.ddRules) &
    (RetiredRule + cert.(Hypothesis + Undecided) + (cert.Pending - ApprovedPending))
}
check PointedRulesUsable for 5

-- 保証していないかもしれないこと（穴の候補） --------------------------------

-- H1. 作業が全部終われば、テストで確かめる受入条件には、通ったケースがある。
assert AllDoneMeansACTested {
  (AllChecks and Task = DoneTask) implies
    all a: AC - NoTestReasonAC | some (tcAcs.a & PassedTC)
}
check AllDoneMeansACTested for 5

-- H2. ケースが全部新しくても、受入条件に結んだ作業が全部終われば、その受入条件に通ったケースがある。
assert ACTasksDoneMeansTested {
  (AllChecks and TC = NewTC) implies
    all a: AC - NoTestReasonAC | (taskAcs.a in DoneTask) implies some (tcAcs.a & PassedTC)
}
check ACTasksDoneMeansTested for 5

-- H3. 作業が結ぶケースは、受入条件に結ばれていれば、その作業の受入条件のケースである。
assert TaskTestsMatchACs {
  AllChecks implies all k: Task, t: k.taskTests | some t.tcAcs implies some (t.tcAcs & k.taskAcs)
}
check TaskTestsMatchACs for 5

-- H4. 作業が全部終われば、否定を含む受入条件の否定のケースが通っている。
assert NegACNegTestPassed {
  (AllChecks and Task = DoneTask) implies all a: NegAC | some (tcAcs.a & NegTC & PassedTC)
}
check NegACNegTestPassed for 5

-- H5. 作業が全部終われば、有効でテストで確かめる規則の、満たすケースと破るケースが通っている。
assert RuleCasesPassedWhenDone {
  (AllChecks and Task = DoneTask) implies all r: validRules |
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
  AllChecks and some a: NegAC & NoTestReasonAC | no (tcAcs.a & NegTC)
} for 5
