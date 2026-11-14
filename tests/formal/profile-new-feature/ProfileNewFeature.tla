------------------------- MODULE ProfileNewFeature -------------------------
(***************************************************************************)
(* skills/dev-profile-new-feature の工程と、工程の間の決まりのモデル。      *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 依頼ごとの違いは r（初期状態で非決定に選ぶ）、経過は h に持つ。          *)
(* 手戻りは、それぞれ1回まで起きうるとする（依頼ごとに一種類まで）。        *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"R"・"HR"（中断と再開）は工程ではない
Steps == {"sizing", "req", "primary-source", "domain-model", "req-ask", "acceptance",
          "design", "formal-check", "design-ok", "sizing-after-design", "test-cases",
          "tasks", "implement", "sizing-after-implement",
          "ops-artifacts", "ops-ok", "evidence", "review-round", "audit", "final-ok"}

\* 依頼ごとの違い。意味の無い組み合わせを作らないよう、関係する違いは一つの値にまとめる
\*   formal: モデルの検査の依頼なし／あり（反例なし／あり）
\*   spec:   モデルを作らない／作る（仮説なし／仮説あり／回答で規則が変わる）／
\*           要件の確認事項に未回答がある
\*   external: 一次情報の確かめなし／あり（確定だけ／推定の規則が出る）／設計の途中で要ると分かる
\*   rework: 手戻りなし／変更要求／承認し直し／監査の「条件付き」／監査の「止める」／
\*           受入条件の書き直しの案を採る
\*   ops:    運用の成果物（ops-artifacts・ops-ok）が要らない／要る（そのまま承認／台帳の
\*           確認事項を req-ask で確かめる／手元で流して不具合が見つかる／業務の決定が要る／
\*           承認しない）。
\*           状態の数を抑えるため、モデルの検査なし、手戻りなしか変更要求の依頼にだけ掛ける
OpsKinds == {"none", "ok", "ledgerQ", "fix", "decision", "reject"}
Requests == {rr \in [e2e: BOOLEAN, needDesign: BOOLEAN, formal: {"none", "ok", "cex"},
                     pending: BOOLEAN, normal: BOOLEAN, becomeNormal: BOOLEAN,
                     discover: BOOLEAN, evidence: BOOLEAN,
                     external: {"none", "ok", "hypo", "late"},
                     spec: {"none", "model", "modelHypo", "modelHypoChange",
                            "reqQuestion"},
                     rework: {"none", "reject", "reapprove", "auditCond", "auditStop",
                              "acRewrite"},
                     ops: OpsKinds] :
              rr.ops = "none" \/ (rr.formal = "none" /\ rr.rework \in {"none", "reject"})}

Ops == r.ops /= "none"

Hypo    == r.spec \in {"modelHypo", "modelHypoChange"}
Changes == r.spec \in {"model", "modelHypo", "modelHypoChange"}
NeedExt == r.external \in {"ok", "hypo"} \/ (r.external = "late" /\ h.lateFound)

Init ==
    /\ pc = "sizing"
    /\ r \in Requests
    /\ h = [req |-> FALSE, extDone |-> FALSE, modelDone |-> FALSE, hypo |-> FALSE,
            hypoResolved |-> FALSE, changed |-> FALSE,
            designDone |-> FALSE, designPending |-> FALSE, cexHandled |-> FALSE,
            normal |-> FALSE, tests |-> FALSE, taskList |-> FALSE,
            sized |-> FALSE, evidenceFixed |-> FALSE, rejected |-> FALSE,
            reapproved |-> FALSE, discovered |-> FALSE, auditConded |-> FALSE,
            auditStopped |-> FALSE, reqAsked |-> FALSE, acRewritten |-> FALSE,
            lateFound |-> FALSE,
            opsApproved |-> FALSE, fromOps |-> FALSE, ledgerAsked |-> FALSE,
            opsFixed |-> FALSE, opsDecided |-> FALSE, opsRejected |-> FALSE,
            interrupted |-> FALSE, savedPc |-> "none", resumed |-> FALSE,
            apChanged |-> FALSE, humanChecked |-> FALSE]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

\* sizing（受付と規模の判定。着手の時の道は見込み）
Intake == pc = "sizing" /\ GoH("req", [h EXCEPT !.normal = r.normal])

\* req（要件を書く）。寄り道（primary-source・domain-model・req-ask）を済ませてから、
\*    要件を書き終えて先へ。根拠にする規則に仮説があれば（推定を含む）domain-model へ
Require == pc = "req"
    /\ IF NeedExt /\ ~h.extDone THEN Go("primary-source")
       ELSE IF (Changes /\ ~h.modelDone) \/ h.hypo THEN Go("domain-model")
       ELSE IF r.spec = "reqQuestion" /\ ~h.reqAsked THEN Go("req-ask")
       ELSE GoH(IF r.e2e /\ ~h.acRewritten THEN "acceptance"
                ELSE IF r.needDesign THEN "design" ELSE "test-cases",
                [h EXCEPT !.req = TRUE])

\* primary-source（一次情報を調べる）。推定した規則は仮説
Primary == pc = "primary-source"
    /\ GoH("req", [h EXCEPT !.extDone = TRUE,
                            !.hypo = h.hypo \/ (r.external = "hypo" /\ ~h.hypoResolved)])

\* domain-model（モデルを作る）。仮説が残れば req-ask へ
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

\* acceptance（受入条件を確かめる）。書き直しの案を採れば req へ
Acceptance == pc = "acceptance"
    /\ IF r.rework = "acRewrite" /\ ~h.acRewritten
         THEN GoH("req", [h EXCEPT !.acRewritten = TRUE])
         ELSE Go(IF r.needDesign THEN "design" ELSE "test-cases")

\* design（設計する）。設計で新しく外部に依存すると分かったら、req に戻って primary-source を通す
DesignToExt == pc = "design" /\ r.external = "late" /\ ~h.extDone
    /\ GoH("req", [h EXCEPT !.lateFound = TRUE])

Design == pc = "design" /\ ~(r.external = "late" /\ ~h.extDone)
    /\ GoH(IF r.formal /= "none" THEN "formal-check" ELSE "design-ok",
           [h EXCEPT !.designDone = TRUE, !.designPending = r.pending])

\* formal-check（モデルで検査する。人が依頼したとき）
Formal == pc = "formal-check" /\ Go("design-ok")

\* design-ok（設計を承認する。人）。反例があれば扱いを決め、設計を直すなら design へ
Approve == pc = "design-ok"
    /\ IF r.formal = "cex" /\ ~h.cexHandled
         THEN GoH("design", [h EXCEPT !.designPending = FALSE, !.cexHandled = TRUE])
         ELSE GoH("sizing-after-design", [h EXCEPT !.designPending = FALSE])

\* sizing-after-design（規模を判定し直す。設計が固まった時。道が通常の道に変わることがある）
SizingAfterDesign == pc = "sizing-after-design"
    /\ GoH("test-cases", [h EXCEPT !.normal = h.normal \/ r.becomeNormal])

\* test-cases（テストケースを導く）→ 通常の道なら tasks
TestCases == pc = "test-cases"
    /\ GoH(IF h.normal THEN "tasks" ELSE "implement", [h EXCEPT !.tests = TRUE])

\* tasks（作業に分ける）
Breakdown == pc = "tasks" /\ GoH("implement", [h EXCEPT !.taskList = TRUE])

\* implement（実装する）。軽い道の実装中に作業が2つ以上と分かったら、止めて
\*    要る観点の設計（design）か作業に分ける（tasks）へ
ImplementStop == pc = "implement"
    /\ ~h.normal /\ r.discover /\ ~h.discovered
    /\ GoH(IF r.needDesign THEN "design" ELSE "tasks",
           [h EXCEPT !.discovered = TRUE, !.normal = TRUE])

Implement == pc = "implement"
    /\ ~(~h.normal /\ r.discover /\ ~h.discovered)
    /\ GoH("sizing-after-implement", [h EXCEPT !.sized = FALSE, !.evidenceFixed = FALSE,
                                               !.opsApproved = FALSE])

\* sizing-after-implement（規模を判定し直す。実際の差分で）。承認し直しが要れば req へ、
\*    通常の道なのに作業の一覧が無ければ tasks へ
SizingAfterImplement == pc = "sizing-after-implement"
    /\ IF r.rework = "reapprove" /\ ~h.reapproved
         THEN GoH("req", [h EXCEPT !.sized = TRUE, !.reapproved = TRUE])
       ELSE IF h.normal /\ ~h.taskList
         THEN GoH("tasks", [h EXCEPT !.sized = TRUE])
       ELSE GoH(IF Ops THEN "ops-artifacts" ELSE IF r.evidence THEN "evidence" ELSE "review-round",
                [h EXCEPT !.sized = TRUE])

\* ops-artifacts（運用の成果物を作る）。台帳の確認事項は req-ask で確かめて戻る。手元で流して
\*     不具合が見つかれば implement へ、業務の決定が要れば req へ（それぞれ1回まで）
OpsMake == pc = "ops-artifacts"
    /\ IF r.ops = "ledgerQ" /\ ~h.ledgerAsked
         THEN GoH("req-ask", [h EXCEPT !.ledgerAsked = TRUE, !.fromOps = TRUE])
       ELSE IF r.ops = "fix" /\ ~h.opsFixed
         THEN GoH("implement", [h EXCEPT !.opsFixed = TRUE])
       ELSE IF r.ops = "decision" /\ ~h.opsDecided
         THEN GoH("req", [h EXCEPT !.opsDecided = TRUE])
       ELSE Go("ops-ok")

\* ops-ok（運用の成果物を承認する。人）。承認しないなら ops-artifacts で直す（1回まで）
OpsApprove == pc = "ops-ok"
    /\ IF r.ops = "reject" /\ ~h.opsRejected
         THEN GoH("ops-artifacts", [h EXCEPT !.opsRejected = TRUE])
         ELSE GoH(IF r.evidence THEN "evidence" ELSE "review-round", [h EXCEPT !.opsApproved = TRUE])

\* evidence（受入の証拠を確かめる。確定する）
Evidence == pc = "evidence" /\ GoH("review-round", [h EXCEPT !.evidenceFixed = TRUE])

\* review-round（レビュー）。変更要求なら implement へ
Review == pc = "review-round"
    /\ IF r.rework = "reject" /\ ~h.rejected
         THEN GoH("implement", [h EXCEPT !.rejected = TRUE])
         ELSE Go("audit")

\* audit（完了前に監査する）。条件付きならやり直し、止めるなら原因の工程（ここでは implement）へ
Audit == pc = "audit"
    /\ IF r.rework = "auditCond" /\ ~h.auditConded
         THEN GoH("audit", [h EXCEPT !.auditConded = TRUE])
       ELSE IF r.rework = "auditStop" /\ ~h.auditStopped
         THEN GoH("implement", [h EXCEPT !.auditStopped = TRUE])
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

Next == Intake \/ Require \/ Primary \/ Model \/ Confirm \/ Acceptance \/ DesignToExt
        \/ Design \/ Formal \/ Approve \/ SizingAfterDesign
        \/ TestCases \/ Breakdown \/ ImplementStop \/ Implement \/ SizingAfterImplement
        \/ OpsMake \/ OpsApprove
        \/ Evidence \/ Review \/ Audit \/ Final \/ Finished
        \/ Interrupt \/ Resume \/ ResumeHuman

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"Done", "R", "HR"}

\* 要件（完了条件の一覧）を書き終えてから、設計とテストケースへ進む
ReqBeforeDesign == pc \in {"acceptance", "design", "test-cases"} => h.req

\* 仮説・未確定の業務規則を残したまま、設計やテストケースへ進まない
NoHypothesisIntoDesign == pc \in {"design", "test-cases"} => ~h.hypo

\* モデルを作る依頼なら、モデルを作ってから設計やテストケースへ進む
ModelBeforeDesign == (pc \in {"design", "test-cases"} /\ Changes) => h.modelDone

\* 要件の確認事項の未回答を、人に確かめてから設計やテストケースへ進む
ReqQuestionsAnswered == (pc \in {"design", "test-cases"} /\ r.spec = "reqQuestion") => h.reqAsked

\* 一次情報が要るなら、調べてからテストケースや設計の承認へ進む
ExtBeforeUse == /\ (pc = "test-cases" /\ r.external \in {"ok", "hypo"}) => h.extDone
                /\ (pc = "design-ok" /\ r.external /= "none") => h.extDone

\* 設計の判断に人の決定待ちが残っている作業は、始めない
NoImplementWithPending == pc = "implement" => ~h.designPending

\* 要る観点の設計をしてから実装する
DesignBeforeImplement == (pc = "implement" /\ r.needDesign) => h.designDone

\* テストケースを導いてから実装する
TestsBeforeImplement == pc = "implement" => h.tests

\* 最後の変更の後で規模を判定し直してから、レビューに回す
SizingBeforeReview == pc = "review-round" => h.sized

\* 受入の証拠は、確定してからレビューに回す
EvidenceBeforeReview == (pc = "review-round" /\ r.evidence) => h.evidenceFixed

\* 運用の成果物が要るなら、最後の変更の後で承認してから、証拠の確定とレビューへ進む
OpsApprovedBeforeReview == (pc \in {"evidence", "review-round"} /\ Ops) => h.opsApproved

\* 通常の道なら、監査の前に作業の一覧がある
TasksBeforeAudit == (pc = "audit" /\ h.normal) => h.taskList

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
