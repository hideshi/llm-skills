---------------------- MODULE ProfileExistingSystem ----------------------
(***************************************************************************)
(* skills/dev-profile-existing-system の工程と、工程の間の決まりのモデル。   *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 依頼ごとの違いは r（初期状態で非決定に選ぶ）、経過は h に持つ。          *)
(* 手戻りは、それぞれ1回まで起きうるとする（依頼ごとに一種類まで）。        *)
(*                                                                         *)
(* Old = TRUE は、2026-11-13 の設計の群のレビューの前の版の流れ:          *)
(*  - 是正（fix）で設計が要ると分かったら、設計（design）へ直接進む        *)
(*    （要件が無い）。                                                      *)
(*  - 受入の証拠の後に、規模を判定し直す。                                  *)
(*  - 是正から作業に分ける（tasks）道が無い。                               *)
(***************************************************************************)
EXTENDS Naturals, TLC

CONSTANT Old

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"B"（判定 B）と "Done"（終わり）、"R"・"HR"（中断と再開）は工程ではない
Steps == {"intake", "sizing", "survey", "formal-check", "data-audit", "survey-ask",
          "baseline", "req", "primary-source", "domain-model", "req-ask", "design",
          "design-ok", "sizing-after-design", "fix", "test-design", "tasks", "implement",
          "baseline-update", "sizing-after-implement", "ops-artifacts", "ops-ok",
          "evidence", "review-round", "audit", "final-ok"}

\* 依頼ごとの違い。意味の無い組み合わせを作らないよう、関係する違いは一つの値にまとめる
\*   survey: 判定 A・C と、調べる段の寄り道（データの監査と人への確かめ）をするか
\*   kind:   機能の変更（設計が要らない／要る）、不具合（そのまま直せる／直す方針が設計を要る）
\*   formal: モデルの検査の依頼なし／今の実装を対象／設計を対象（反例なし／あり）
\*   spec:   モデルを直さない／直す（仮説なし／仮説あり／回答で規則が変わる）／
\*           工程 survey で抜き出した規則の候補（仮説）を根拠にする／要件の確認事項に未回答がある
\*   external: 一次情報の確かめなし／あり（確定だけ／推定の規則が出る）／設計の途中で要ると分かる
\*   rework: 手戻りなし／変更要求／承認し直し／監査の「条件付き」と「止める」／
\*           受入条件の書き直しの案を採る／差分の点検で設計の判断を見直す
\*   ops:    運用の成果物（ops-artifacts・ops-ok）が要らない／要る（そのまま承認／台帳の
\*           確認事項を req-ask で確かめる／手元で流して不具合が見つかる／業務の決定が要る／
\*           承認しない）。状態の数を抑えるため、モデルの検査なし、手戻りなしか変更要求の
\*           依頼にだけ掛ける
OpsKinds == {"none", "ok", "ledgerQ", "fix", "decision", "reject"}
Requests == {rr \in [survey: {"none", "a", "c", "aDetours", "cDetours"},
                     kind: {"feature", "featureDesign", "defect", "defectNeedsDesign"},
                     formal: {"none", "current", "design", "designCex"},
                     pending: BOOLEAN,
                     spec: {"none", "model", "modelHypo", "modelHypoChange", "extracted",
                            "reqQuestion"},
                     external: {"none", "ok", "hypo", "late"},
                     evidence: BOOLEAN, tasks: BOOLEAN, expectChange: BOOLEAN,
                     rework: {"none", "reject", "reapprove", "audit", "acRewrite",
                              "designDev"},
                     ops: OpsKinds] :
              rr.ops = "none" \/ (rr.formal = "none" /\ rr.rework \in {"none", "reject"})}

A               == r.survey \in {"a", "aDetours"}
AorC            == r.survey /= "none"
Detours         == r.survey \in {"aDetours", "cDetours"}
IsDefect(rr)    == rr.kind \in {"defect", "defectNeedsDesign"}
NeedDesign      == r.kind = "featureDesign"
FixNeedsDesign  == r.kind = "defectNeedsDesign"
FormalCurrent   == r.formal = "current"
FormalDesign    == r.formal \in {"design", "designCex"}
Cex             == r.formal = "designCex"
Hypo            == r.spec \in {"modelHypo", "modelHypoChange"}
Changes         == r.spec \in {"model", "modelHypo", "modelHypoChange"}
NeedExt         == r.external \in {"ok", "hypo"} \/ (r.external = "late" /\ h.designing)
Ops             == ~Old /\ r.ops /= "none"

Init ==
    /\ pc = "intake"
    /\ r \in Requests
    /\ h = [defect |-> FALSE, baseline |-> FALSE, formalDone |-> FALSE,
            formalDesignDone |-> FALSE, audited |-> FALSE, asked |-> FALSE,
            req |-> FALSE, extDone |-> FALSE, modelDone |-> FALSE, hypo |-> FALSE,
            hypoResolved |-> FALSE, changed |-> FALSE, designing |-> FALSE,
            pending |-> FALSE, cexHandled |-> FALSE, taskList |-> FALSE,
            sized |-> FALSE, evidenceFixed |-> FALSE, rejected |-> FALSE,
            reapproved |-> FALSE, switched |-> FALSE, auditConded |-> FALSE,
            auditStopped |-> FALSE, reqAsked |-> FALSE, acRewritten |-> FALSE,
            designRevised |-> FALSE,
            opsApproved |-> FALSE, fromOps |-> FALSE, ledgerAsked |-> FALSE,
            opsFixed |-> FALSE, opsDecided |-> FALSE, opsRejected |-> FALSE,
            interrupted |-> FALSE, savedPc |-> "none", resumed |-> FALSE,
            apChanged |-> FALSE, humanChecked |-> FALSE]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

DecideB(hh) == IF hh.defect THEN "fix" ELSE "req"

\* intake（受付。判定 A・B・C）
Intake == pc = "intake" /\ GoH("sizing", [h EXCEPT !.defect = IsDefect(r)])

\* sizing（規模を判定する）
Sizing == pc = "sizing" /\ Go(IF AorC THEN "survey" ELSE DecideB(h))

\* survey（今の動きを調べる。規則の抽出を含む）。寄り道（formal-check・data-audit・
\*    survey-ask）を済ませてから先へ。抜き出した規則の候補は仮説（h.hypo）
Survey == pc = "survey"
    /\ GoH(IF FormalCurrent /\ ~h.formalDone THEN "formal-check"
           ELSE IF Detours /\ ~h.audited THEN "data-audit"
           ELSE IF Detours /\ ~h.asked THEN "survey-ask"
           ELSE IF A THEN "baseline" ELSE DecideB(h),
           [h EXCEPT !.hypo = h.hypo \/ (r.spec = "extracted" /\ ~h.hypoResolved)])

\* formal-check（モデルで検査する。今の実装を対象なら survey へ、設計を対象なら design-ok へ戻る）
Formal == pc = "formal-check"
    /\ IF h.designing
         THEN GoH("design-ok", [h EXCEPT !.formalDesignDone = TRUE])
         ELSE GoH("survey", [h EXCEPT !.formalDone = TRUE])

\* data-audit（データの規則違反を監査する）
DataAudit == pc = "data-audit" /\ GoH("survey", [h EXCEPT !.audited = TRUE])

\* survey-ask（人に確かめる）
SurveyAsk == pc = "survey-ask" /\ GoH("survey", [h EXCEPT !.asked = TRUE])

\* baseline（回帰の基準を固める）
Baseline == pc = "baseline" /\ GoH(DecideB(h), [h EXCEPT !.baseline = TRUE])

\* req（要件を書く）。寄り道（primary-source・domain-model・req-ask）を済ませてから、
\*    要件を書き終えて先へ。根拠にする規則に仮説があれば（抜き出した候補、推定を含む）
\*    domain-model へ
Requirements == pc = "req"
    /\ IF NeedExt /\ ~h.extDone THEN Go("primary-source")
       ELSE IF (Changes /\ ~h.modelDone) \/ h.hypo THEN Go("domain-model")
       ELSE IF r.spec = "reqQuestion" /\ ~h.reqAsked THEN Go("req-ask")
       ELSE GoH(IF NeedDesign \/ h.switched THEN "design" ELSE "test-design",
                [h EXCEPT !.req = TRUE])

\* primary-source（一次情報を調べる）。推定した規則は仮説
Primary == pc = "primary-source"
    /\ GoH("req", [h EXCEPT !.extDone = TRUE,
                          !.hypo = h.hypo \/ (r.external = "hypo" /\ ~h.hypoResolved)])

\* domain-model（モデルを直す）。仮説が残れば req-ask へ
Model == pc = "domain-model"
    /\ LET hy == h.hypo \/ (Hypo /\ ~h.hypoResolved)
       IN GoH(IF hy THEN "req-ask" ELSE "req", [h EXCEPT !.modelDone = TRUE, !.hypo = hy])

\* req-ask（人に確かめる）。業務規則の回答は、どの結果でも domain-model で反映する
\*     （回答で規則が変われば、変えた規則がまた仮説として残る）。要件の回答は req へ
Confirm == pc = "req-ask"
    /\ IF h.fromOps
         THEN GoH("ops-artifacts", [h EXCEPT !.fromOps = FALSE])
       ELSE IF h.hypo
         THEN IF r.spec = "modelHypoChange" /\ ~h.changed
                THEN GoH("domain-model", [h EXCEPT !.changed = TRUE])
                ELSE GoH("domain-model", [h EXCEPT !.hypo = FALSE, !.hypoResolved = TRUE])
         ELSE GoH("req", [h EXCEPT !.reqAsked = TRUE])

\* design（設計する）。要件（完了条件の一覧）が無いと設計しない（前提条件）。
\*     設計で新しく外部に依存すると分かったら、req に戻って primary-source を通す
DesignToExt == pc = "design" /\ h.req /\ r.external = "late" /\ ~h.extDone
    /\ GoH("req", [h EXCEPT !.designing = TRUE])

Design == pc = "design" /\ h.req /\ ~(r.external = "late" /\ ~h.extDone)
    /\ GoH(IF FormalDesign /\ ~h.formalDesignDone THEN "formal-check" ELSE "design-ok",
           [h EXCEPT !.designing = TRUE, !.pending = r.pending])

\* design-ok（設計を承認する。人）。反例があれば扱いを決め、設計を直すなら design へ
Approve == pc = "design-ok"
    /\ IF Cex /\ h.formalDesignDone /\ ~h.cexHandled
         THEN GoH("design", [h EXCEPT !.pending = FALSE, !.cexHandled = TRUE])
         ELSE GoH("sizing-after-design", [h EXCEPT !.pending = FALSE])

\* sizing-after-design（規模を判定し直す）
SizingAfterDesign == pc = "sizing-after-design" /\ Go("test-design")

\* test-design（試験を設計する）。受入条件の書き直しの案を採れば req へ。
\*     作業に分ける条件に当たれば tasks
TestDesign == pc = "test-design"
    /\ IF r.rework = "acRewrite" /\ ~h.acRewritten
         THEN GoH("req", [h EXCEPT !.acRewritten = TRUE])
         ELSE Go(IF r.tasks THEN "tasks" ELSE "implement")

\* tasks（作業に分ける。是正から来たら fix へ、改修から来たら implement へ）
Breakdown == pc = "tasks"
    /\ GoH(IF h.defect THEN "fix" ELSE "implement", [h EXCEPT !.taskList = TRUE])

AfterChange == IF r.expectChange THEN "baseline-update"
               ELSE IF Old /\ r.evidence THEN "evidence" ELSE "sizing-after-implement"

\* implement（改修する）
\*     差分の点検で設計の判断を見直すと決まったら、design に戻って design-ok で承認し直す
Implement == pc = "implement"
    /\ IF r.rework = "designDev" /\ ~h.designRevised /\ h.designing
         THEN GoH("design", [h EXCEPT !.designRevised = TRUE])
         ELSE GoH(AfterChange, [h EXCEPT !.sized = FALSE, !.evidenceFixed = FALSE,
                                         !.opsApproved = FALSE])

\* fix（不具合を是正する）
\*   直す方針が設計を要る → 今の版: B を機能の変更に切り替えて req へ（旧: 設計 design へ直接）
FixToDesign == pc = "fix" /\ FixNeedsDesign /\ ~h.switched
    /\ GoH(IF Old THEN "design" ELSE "req",
           [h EXCEPT !.switched = TRUE, !.defect = IF Old THEN h.defect ELSE FALSE])

\*   作業に分ける条件に当たる → tasks で分けてから作業ごとに fix（旧: この道が無い）
FixSplit == pc = "fix" /\ ~(FixNeedsDesign /\ ~h.switched)
    /\ ~Old /\ r.tasks /\ ~h.taskList
    /\ Go("tasks")

FixCode == pc = "fix" /\ ~(FixNeedsDesign /\ ~h.switched)
    /\ (Old \/ ~r.tasks \/ h.taskList)
    /\ GoH(AfterChange, [h EXCEPT !.sized = FALSE, !.evidenceFixed = FALSE,
                                   !.opsApproved = FALSE])

\* baseline-update（回帰の基準を更新する）
UpdateBaseline == pc = "baseline-update" /\ Go(IF Old /\ r.evidence THEN "evidence" ELSE "sizing-after-implement")

\* sizing-after-implement（規模を判定し直す。実際の差分で）。承認し直しが要れば req へ
SizingAfterImplement == pc = "sizing-after-implement"
    /\ IF r.rework = "reapprove" /\ ~h.reapproved
         THEN GoH("req", [h EXCEPT !.sized = TRUE, !.reapproved = TRUE])
         ELSE GoH(IF Ops THEN "ops-artifacts" ELSE IF ~Old /\ r.evidence THEN "evidence" ELSE "review-round",
                  [h EXCEPT !.sized = TRUE])

\* ops-artifacts（運用の成果物を作る）。台帳の確認事項は req-ask で確かめて戻る。
\*     手元で流して不具合が見つかれば fix か implement へ、業務の決定が要れば req へ
\*     （それぞれ1回まで）
OpsMake == pc = "ops-artifacts"
    /\ IF r.ops = "ledgerQ" /\ ~h.ledgerAsked
         THEN GoH("req-ask", [h EXCEPT !.ledgerAsked = TRUE, !.fromOps = TRUE])
       ELSE IF r.ops = "fix" /\ ~h.opsFixed
         THEN GoH(IF h.defect THEN "fix" ELSE "implement", [h EXCEPT !.opsFixed = TRUE])
       ELSE IF r.ops = "decision" /\ ~h.opsDecided
         THEN GoH("req", [h EXCEPT !.opsDecided = TRUE, !.defect = FALSE])
       ELSE Go("ops-ok")

\* ops-ok（運用の成果物を承認する。人）。承認しないなら ops-artifacts で直す（1回まで）
OpsApprove == pc = "ops-ok"
    /\ IF r.ops = "reject" /\ ~h.opsRejected
         THEN GoH("ops-artifacts", [h EXCEPT !.opsRejected = TRUE])
         ELSE GoH(IF r.evidence THEN "evidence" ELSE "review-round", [h EXCEPT !.opsApproved = TRUE])

\* evidence（受入の証拠を確かめる。確定する）
Evidence == pc = "evidence"
    /\ GoH(IF Old THEN "sizing-after-implement" ELSE "review-round", [h EXCEPT !.evidenceFixed = TRUE])

\* review-round（レビュー）。変更要求なら fix か implement へ
Review == pc = "review-round"
    /\ IF r.rework = "reject" /\ ~h.rejected
         THEN GoH(IF h.defect THEN "fix" ELSE "implement", [h EXCEPT !.rejected = TRUE])
         ELSE Go("audit")

\* audit（完了前に監査する）。条件付きならやり直し、止めるなら原因の工程（fix か implement）へ
AuditFinal == pc = "audit"
    /\ IF r.rework = "audit" /\ ~h.auditConded
         THEN GoH("audit", [h EXCEPT !.auditConded = TRUE])
       ELSE IF r.rework = "audit" /\ ~h.auditStopped
         THEN GoH(IF h.defect THEN "fix" ELSE "implement", [h EXCEPT !.auditStopped = TRUE])
       ELSE Go("final-ok")

Final == pc = "final-ok" /\ Go("Done")
Finished == pc = "Done" /\ UNCHANGED vars

\* 中断と再開（ほかの組み合わせ）。状態の数を抑えるため、代表として工程 implement でだけ
\* 1回まで起きうる割り込みにする。再開の時に、人が承認した成果物が中断の間に
\* 変わっていたか（apChanged）を非決定に選ぶ。変わっていれば人に確かめてから戻る
Interrupt == pc = "implement" /\ ~h.interrupted
    /\ GoH("R", [h EXCEPT !.interrupted = TRUE, !.savedPc = pc])
Resume == pc = "R" /\ \E ch \in BOOLEAN :
    GoH(IF ch THEN "HR" ELSE h.savedPc,
        [h EXCEPT !.resumed = TRUE, !.apChanged = ch])
ResumeHuman == pc = "HR" /\ GoH(h.savedPc, [h EXCEPT !.humanChecked = TRUE])

Next == Intake \/ Sizing \/ Survey \/ Formal \/ DataAudit \/ SurveyAsk \/ Baseline
        \/ Requirements \/ Primary \/ Model \/ Confirm \/ DesignToExt \/ Design \/ Approve
        \/ SizingAfterDesign \/ TestDesign \/ Breakdown \/ Implement \/ FixToDesign
        \/ FixSplit \/ FixCode \/ UpdateBaseline \/ SizingAfterImplement \/ OpsMake
        \/ OpsApprove \/ Evidence \/ Review
        \/ AuditFinal \/ Final \/ Finished
        \/ Interrupt \/ Resume \/ ResumeHuman

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"Done", "R", "HR"}

\* 回帰の基準は、コードを変える工程（fix・implement）より前に通す（A に当たるとき）
BaselineBeforeCode == (pc \in {"fix", "implement"} /\ A) => h.baseline

\* 設計の判断に人の決定待ちが残っている作業は、始めない
NoImplementWithPending == pc = "implement" => ~h.pending

\* 仮説・未確定の業務規則を残したまま、設計や試験の設計へ進まない
NoHypothesisIntoDesign == pc \in {"design", "test-design"} => ~h.hypo

\* 規則が変わるなら、モデルを直してから設計や試験の設計へ進む
ModelBeforeDesign == (pc \in {"design", "test-design"} /\ Changes /\ h.req) => h.modelDone

\* 要件の確認事項の未回答を、人に確かめてから設計や試験の設計へ進む
ReqQuestionsAnswered == (pc \in {"design", "test-design"} /\ r.spec = "reqQuestion" /\ h.req) => h.reqAsked

\* 一次情報が要るなら、調べてから試験の設計や設計の承認へ進む
ExtBeforeUse == /\ (pc = "test-design" /\ r.external \in {"ok", "hypo"} /\ h.req) => h.extDone
                /\ (pc = "design-ok" /\ r.external /= "none") => h.extDone

\* 受入の証拠は、確定してからレビューに回す
EvidenceBeforeReview == (pc = "review-round" /\ r.evidence) => h.evidenceFixed

\* 監査の前に、最後の変更の後で規模を判定し直している
SizingBeforeAudit == pc = "audit" => h.sized

\* 作業に分ける条件に当たるなら、監査の前に作業の一覧がある
TasksBeforeAudit == (pc = "audit" /\ r.tasks) => h.taskList

\* 確定した受入の証拠を、要件の書き直し（工程 req）で無駄にしない
EvidenceNotWasted == ~(pc = "req" /\ h.evidenceFixed)

\* 運用の成果物が要るなら、最後の変更の後で承認してから、証拠の確定とレビューへ進む
OpsApprovedBeforeReview == (pc \in {"evidence", "review-round"} /\ Ops) => h.opsApproved

\* どの依頼でも、いつか終わる（手戻りは有限）
\* 中断の間に人が承認した成果物が変わったら、人に確かめてから工程に戻る
ApprovedChangeNeedsHuman == (h.resumed /\ h.apChanged /\ pc \in Steps) => h.humanChecked

\* 再開したら、中断した工程（の最初）に戻る。割り込みは突き合わせの書き出しから
\* 外しているので、戻り先はこの性質で確かめる
ResumeReturnsToSaved == [][(pc \in {"R", "HR"} /\ pc' \in Steps) => pc' = h.savedPc]_vars

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
\* 中断と再開は遷移の表に載らない割り込みなので、書き出さない
EdgeProbe == LET e == << pc, pc' >> IN
    IF pc \in {"R", "HR"} \/ pc' \in {"R", "HR"} THEN TRUE
    ELSE IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
