---------------------- MODULE ProfileDependencyUpkeep ----------------------
(***************************************************************************)
(* skills/dev-profile-dependency-upkeep の工程と、工程の間の決まりのモデル。 *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 差分の点検の高の指摘、レビューの変更要求、監査の「止める」と「条件付き」 *)
(* は、それぞれ1回まで起きうるとする。                                     *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口の判定）は工程ではない
Steps == {"intake", "advisory-check", "triage-ask", "baseline", "bump", "diff-check",
          "baseline-update", "sizing-after-implement", "procedure", "procedure-ok",
          "review-round", "audit", "final-ok"}

\* entry: 告知への対応／定期の更新
\* precheck: 定期の更新でも告知を先に照らす
\* fixSome: triage-ask で直すと決めた行がある
\* baseline: 基準を固める条件に当たる
\* design: 追随に設計が要ると分かる（別の組み合わせへ出る）
\* follow: 追随のコードがある。expect: 期待値が変わった検証点がある
\* prod: sizing-after-implement の規模の判定で、運用の作業「本番の手順」が当たる
\* diffHigh, reviewChange, auditStop, auditCond: 1回まで起きる差し戻し
\* procReject: procedure-ok で手順を承認しない（1回まで）
Entries == {"advisory", "periodic"}
Flags == {"precheck", "fixSome", "baseline", "design", "follow", "expect",
          "prod", "diffHigh", "reviewChange", "auditStop", "auditCond",
          "procReject", "procFix"}

Init ==
    /\ pc = "start"
    /\ r \in [entry: Entries] \X [Flags -> BOOLEAN]
    /\ h = [checked |-> FALSE, decided |-> FALSE, based |-> FALSE,
            bumped |-> FALSE, procOk |-> FALSE, reviewed |-> FALSE,
            auditOk |-> FALSE, exitDesign |-> FALSE, exitNoFix |-> FALSE,
            usedDiff |-> FALSE, usedReview |-> FALSE, usedStop |-> FALSE,
            usedCond |-> FALSE, usedProcReject |-> FALSE, usedProcFix |-> FALSE]

E == r[1].entry
F == r[2]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

CheckFirst == E = "advisory" \/ F.precheck

\* 版上げの後の行き先（diff-check・baseline-update・sizing-after-implement のどれか）
AfterBump == IF F.follow THEN "diff-check" ELSE IF F.expect THEN "baseline-update" ELSE "sizing-after-implement"
AfterCheck == IF F.expect THEN "baseline-update" ELSE "sizing-after-implement"

\* bump に戻るときは、手順の承認とレビューの結果を失効させる
Back(hh) == [hh EXCEPT !.procOk = FALSE, !.reviewed = FALSE, !.auditOk = FALSE]

Start == pc = "start" /\ Go("intake")

\* intake（受付）
Intake == pc = "intake"
    /\ Go(IF CheckFirst THEN "advisory-check" ELSE IF F.baseline THEN "baseline" ELSE "bump")

\* advisory-check（告知を点検する）
Check == pc = "advisory-check" /\ GoH("triage-ask", [h EXCEPT !.checked = TRUE])

\* triage-ask（当たるかを決める。人）
Decide == pc = "triage-ask"
    /\ IF F.fixSome
         THEN GoH(IF F.baseline THEN "baseline" ELSE "bump", [h EXCEPT !.decided = TRUE])
         ELSE GoH("final-ok", [h EXCEPT !.decided = TRUE, !.exitNoFix = TRUE])

\* baseline（上げる前の基準を固める）
Baseline == pc = "baseline" /\ GoH("bump", [h EXCEPT !.based = TRUE])

\* bump（版を上げる）。追随に設計が要れば外へ出る
Bump == pc = "bump"
    /\ IF F.design
         THEN GoH("final-ok", [h EXCEPT !.exitDesign = TRUE])
         ELSE GoH(AfterBump, [Back(h) EXCEPT !.bumped = TRUE])

\* diff-check（差分を点検する）。高の指摘が残れば bump に戻る（1回まで）
Diff == pc = "diff-check"
    /\ IF F.diffHigh /\ ~h.usedDiff
         THEN GoH("bump", [h EXCEPT !.usedDiff = TRUE])
         ELSE Go(AfterCheck)

\* baseline-update（基準を更新する）
Update == pc = "baseline-update" /\ Go("sizing-after-implement")

\* sizing-after-implement（規模を判定し直す）。運用の作業「本番の手順」が当たれば procedure へ
Sizing == pc = "sizing-after-implement" /\ Go(IF F.prod THEN "procedure" ELSE "review-round")

\* procedure（本番の手順を作る）
\*    手元で流して不具合が見つかれば、bump に戻って版上げを直す（1回まで）
Proc == pc = "procedure"
    /\ IF F.procFix /\ ~h.usedProcFix
         THEN GoH("bump", [h EXCEPT !.usedProcFix = TRUE])
         ELSE Go("procedure-ok")

\* procedure-ok（本番の手順を承認する。人）。承認しないなら procedure で直す（1回まで）
ProcApprove == pc = "procedure-ok"
    /\ IF F.procReject /\ ~h.usedProcReject
         THEN GoH("procedure", [h EXCEPT !.usedProcReject = TRUE])
         ELSE GoH("review-round", [h EXCEPT !.procOk = TRUE])

\* review-round（レビュー）。変更要求なら bump に戻る（1回まで）
Review == pc = "review-round"
    /\ IF F.reviewChange /\ ~h.usedReview
         THEN GoH("bump", [h EXCEPT !.usedReview = TRUE])
         ELSE GoH("audit", [h EXCEPT !.reviewed = TRUE])

\* audit（完了前に監査する）
Audit == pc = "audit"
    /\ IF F.auditStop /\ ~h.usedStop
         THEN GoH("bump", [h EXCEPT !.usedStop = TRUE])
       ELSE IF F.auditCond /\ ~h.usedCond
         THEN GoH("audit", [h EXCEPT !.usedCond = TRUE])
       ELSE GoH("final-ok", [h EXCEPT !.auditOk = TRUE])

\* final-ok（最終確認。人）
Final == pc = "final-ok" /\ Go("Done")
Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Intake \/ Check \/ Decide \/ Baseline \/ Bump \/ Diff
        \/ Update \/ Proc \/ ProcApprove \/ Sizing \/ Review \/ Audit \/ Final
        \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 告知を点検したなら、人が当たるかを決める前に版を上げない
DecideBeforeBump == (pc = "bump" /\ CheckFirst) => h.decided

\* 全件を直さないと決めたら、版を上げない
NoBumpWithoutFix == (CheckFirst /\ ~F.fixSome) => ~h.bumped

\* 基準を固める条件に当たるなら、版を上げる前に固める
BaselineBeforeBump == (pc = "bump" /\ F.baseline) => h.based

\* 本番の手順が要るなら、レビューの前に（戻った後も改めて）承認する
ProcedureBeforeReview == (pc = "review-round" /\ F.prod) => h.procOk

\* 監査は、直近の版上げの後のレビューの承認を受けてから
ReviewBeforeAudit == pc = "audit" => h.reviewed

\* 版上げを終えて最終確認に来るのは、監査が「進めてよい」の後
\* （全件を直さない、または設計が要って外へ出るときを除く）
AuditBeforeFinal ==
    (pc = "final-ok" /\ ~h.exitNoFix /\ ~h.exitDesign) => (h.auditOk /\ h.bumped)

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
