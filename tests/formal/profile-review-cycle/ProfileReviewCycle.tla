------------------------ MODULE ProfileReviewCycle ------------------------
(***************************************************************************)
(* skills/dev-profile-review-cycle の工程と、工程の間の決まりのモデル。     *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 変更要求は最大2回、人への差し戻しと監査の「条件付き」「止める」は各1回  *)
(* まで起きうるとする。                                                     *)
(* 中断と再開（ほかの組み合わせ）は、どの工程でも1回まで起きうる割り込み   *)
(* として表す。"R"（再開）と "HR"（再開の時の人の確認）は工程ではない。    *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口の判定）、"H"（人の決定）、"R"・"HR"（中断と再開）は工程ではない
Steps == {"evidence", "brief", "review", "rework", "re-review-round", "audit", "final-ok"}

\* approvedChanged: 中断の間に、人が承認した成果物（完了条件の一覧など）が変わった
Flags == {"evidence", "reject1", "reject2", "escalate", "evidenceTouched",
          "auditCond", "auditStop", "approvedChanged"}

\* 記録で再開した担当は、前の担当と同じ側として扱う（工程の間の決まり）
InheritRole == TRUE

\* actor: いま工程を進める担当の側。authorView: その担当が作った側の説明を読んだか

Init ==
    /\ pc = "start"
    /\ r \in [Flags -> BOOLEAN]
    /\ h = [evidenceFixed |-> FALSE, rounds |-> 0, approved |-> FALSE,
            escalated |-> FALSE, auditConded |-> FALSE, auditStopped |-> FALSE,
            briefed |-> FALSE, actor |-> "author", authorView |-> TRUE,
            interrupted |-> FALSE, savedPc |-> "none", role |-> "none",
            resumed |-> FALSE, humanChecked |-> FALSE]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

\* 入口: 画面・録画・帳票の証拠があれば evidence、無ければ brief
Start == pc = "start" /\ Go(IF r.evidence THEN "evidence" ELSE "brief")

\* evidence（受入の証拠を確かめる。確定する）。直した後のやり直しなら re-review-round へ
Evidence == pc = "evidence"
    /\ IF h.rounds > 0
         THEN GoH("re-review-round", [h EXCEPT !.evidenceFixed = TRUE, !.actor = "reviewer",
                                 !.authorView = FALSE])
         ELSE GoH("brief", [h EXCEPT !.evidenceFixed = TRUE])

\* brief（依頼文を書く）
\*    レビューは別の担当に渡す（作った側の説明は依頼文に入れない）
Brief == pc = "brief" /\ GoH("review", [h EXCEPT !.briefed = TRUE, !.actor = "reviewer",
                                        !.authorView = FALSE])

\* review（レビューする。別の担当）。変更要求なら rework、人へ戻すなら人の決定の後 rework、承認なら audit
Conduct == pc = "review"
    /\ IF r.reject1 /\ h.rounds = 0
         THEN IF r.escalate /\ ~h.escalated
                THEN GoH("H", [h EXCEPT !.escalated = TRUE])
                ELSE GoH("rework", [h EXCEPT !.actor = "author", !.authorView = TRUE])
         ELSE GoH("audit", [h EXCEPT !.approved = TRUE, !.actor = "auditor",
                                 !.authorView = FALSE])

\* 人の決定 → rework（作った側が直す）
Human == pc = "H" /\ GoH("rework", [h EXCEPT !.actor = "author", !.authorView = TRUE])

\* rework（直す）。証拠に関係する所を変えたら evidence をやり直す
Fix == pc = "rework"
    /\ IF r.evidence /\ r.evidenceTouched
         THEN GoH("evidence", [h EXCEPT !.rounds = h.rounds + 1, !.evidenceFixed = FALSE,
                                 !.approved = FALSE])
         ELSE GoH("re-review-round", [h EXCEPT !.rounds = h.rounds + 1, !.approved = FALSE,
                                 !.actor = "reviewer", !.authorView = FALSE])

\* re-review-round（再レビュー。直した所に絞る）。2回目の変更要求も起きうる。
\*    同じ指摘で2回合意できなければ人に戻す（ここでは2回目の後は承認に倒す）
ReReview == pc = "re-review-round"
    /\ IF r.reject2 /\ h.rounds = 1
         THEN GoH("rework", [h EXCEPT !.actor = "author", !.authorView = TRUE])
         ELSE GoH("audit", [h EXCEPT !.approved = TRUE, !.actor = "auditor",
                                 !.authorView = FALSE])

\* audit（完了前に監査する）。条件付きならやり直し、止めるなら rework へ
Audit == pc = "audit"
    /\ IF r.auditCond /\ ~h.auditConded
         THEN GoH("audit", [h EXCEPT !.auditConded = TRUE])
       ELSE IF r.auditStop /\ ~h.auditStopped /\ h.rounds < 2
         THEN GoH("rework", [h EXCEPT !.auditStopped = TRUE, !.actor = "author",
                                 !.authorView = TRUE])
       ELSE Go("final-ok")

Final == pc = "final-ok" /\ Go("Done")

\* 中断: final-ok を除くどの工程でも1回まで。引継ぎの記録に、位置と担当の側を残す
Interrupt == pc \in Steps \ {"final-ok"} /\ ~h.interrupted
    /\ GoH("R", [h EXCEPT !.interrupted = TRUE, !.savedPc = pc, !.role = h.actor])

\* 再開: 記録を読んだ担当が、控えと今の状態を照らす。
\*   人が承認した成果物が変わっていれば人に確かめる。工程はその工程から（やり直し）。
\*   InheritRole が偽のとき（決まりが無いとき）は、新しい担当が「作っていない変更」と
\*   見て、依頼文の前（工程 brief）からでもレビュー（工程 review）へ進んでしまう
ResumeTarget == IF InheritRole \/ h.savedPc # "brief" THEN h.savedPc ELSE "review"
Resume == pc = "R"
    /\ GoH(IF r.approvedChanged THEN "HR" ELSE ResumeTarget,
           [h EXCEPT !.resumed = TRUE,
                     !.actor = IF InheritRole THEN h.role ELSE "reviewer",
                     !.authorView = (h.role = "author")])

\* 再開の時の人の確認 → 元の工程へ
ResumeHuman == pc = "HR" /\ GoH(ResumeTarget, [h EXCEPT !.humanChecked = TRUE])
Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Evidence \/ Brief \/ Conduct \/ Human \/ Fix \/ ReReview
        \/ Audit \/ Final \/ Finished \/ Interrupt \/ Resume \/ ResumeHuman

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "H", "Done", "R", "HR"}

\* 受入の証拠は確定してから依頼文に添える（brief と re-review-round の依頼文）
EvidenceBeforeBrief == (pc \in {"brief", "re-review-round"} /\ r.evidence) => h.evidenceFixed

\* 依頼文を書いてからレビューする
BriefBeforeReview == pc = "review" => h.briefed

\* 承認されてから監査する
AuditAfterApproval == pc = "audit" => h.approved

\* レビューする担当は、作った側の説明を読んでいない別の担当（review と re-review-round）
ReviewIndependent == pc \in {"review", "re-review-round"} => (h.actor = "reviewer" /\ ~h.authorView)

\* 中断の間に人が承認した成果物が変わったら、人に確かめてから工程に戻る
ApprovedChangeNeedsHuman == (h.resumed /\ r.approvedChanged /\ pc \in Steps) => h.humanChecked

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
