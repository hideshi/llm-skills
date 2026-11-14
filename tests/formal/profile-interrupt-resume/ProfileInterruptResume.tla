----------------------- MODULE ProfileInterruptResume -----------------------
(***************************************************************************)
(* skills/dev-profile-interrupt-resume の工程と、工程の間の決まりのモデル。 *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 中断の間（セッションが切れている間）は、工程の移り変わりの中に畳む。     *)
(* 人による記録の選び直しは1回まで起きうるとする。                         *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口の判定）は工程ではない
Steps == {"handoff", "receipt", "resume", "delegate-result", "resume-ask", "return"}

\* entry: 入口（中断・委任する／記録から再開する／委任の結果が届いた）
\* delegate: 委任の依頼文を送る。delegateOnly: 委任だけで頼んだ側は中断しない
\* handover: 交代する担当に渡す。undelivered: 送れなかった・相手がもう終わっていた
\* approvedChanged: 人が承認・確定・回答した部分が控えの後に変わった
\* ambiguous: 記録を選べない。noRecord: 有効な記録か控えが無い（再開の入口だけ）
\* overreach: 次の一手が依頼の範囲を超える。reselect: 人が記録を選び直す
\* resultIssue: 委任の結果が範囲を超えた・失敗した・人の決定が要る（結果の入口だけ）
Entries == {"suspend", "resume", "result"}
Flags == {"delegate", "delegateOnly", "handover", "undelivered",
          "approvedChanged", "ambiguous", "noRecord", "overreach", "reselect",
          "resultIssue"}

Init ==
    /\ pc = "start"
    /\ r \in [entry: Entries] \X [Flags -> BOOLEAN]
    /\ h = [snap |-> FALSE, recorded |-> FALSE, receipt |-> FALSE,
            compared |-> FALSE, humanDone |-> FALSE, reselected |-> FALSE,
            delegExit |-> FALSE, integrated |-> FALSE]

E == r[1].entry
F == r[2]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

Handoff == F.delegate \/ F.handover
NeedHuman == F.approvedChanged \/ F.ambiguous \/ (E = "resume" /\ F.noRecord)
             \/ F.overreach

\* 入口
Start == pc = "start"
    /\ Go(CASE E = "suspend" -> "handoff" [] E = "resume" -> "resume" [] OTHER -> "delegate-result")

\* handoff（引継ぎを書く。控えを先に取り、記録を書く）
Write == pc = "handoff"
    /\ GoH(IF Handoff THEN "receipt" ELSE "resume",
           [h EXCEPT !.snap = TRUE, !.recorded = TRUE])

\* receipt（受け取りを確かめる）。届かなければ人に伝言を頼む（resume-ask）
Receipt == pc = "receipt"
    /\ IF F.undelivered
         THEN Go("resume-ask")
       ELSE IF F.delegate /\ F.delegateOnly
         THEN GoH("return", [h EXCEPT !.receipt = TRUE, !.delegExit = TRUE])
       ELSE GoH("resume", [h EXCEPT !.receipt = TRUE])

\* resume（再開して照らす）
Resume == pc = "resume"
    /\ IF NeedHuman /\ ~h.humanDone
         THEN GoH("resume-ask", [h EXCEPT !.compared = TRUE])
         ELSE GoH("return", [h EXCEPT !.compared = TRUE])

\* delegate-result（委任の結果を統合する）
Integrate == pc = "delegate-result"
    /\ GoH(IF F.resultIssue THEN "resume-ask" ELSE "return", [h EXCEPT !.integrated = TRUE])

\* resume-ask（人に確かめる）。記録を選び直す・伝言が届いて再開するなら resume で照らし直す
Human == pc = "resume-ask"
    /\ IF (F.reselect /\ ~h.reselected) \/ (F.undelivered /\ ~h.compared /\ ~h.delegExit
                                           /\ ~(F.delegate /\ F.delegateOnly))
         THEN GoH("resume", [h EXCEPT !.reselected = TRUE, !.humanDone = TRUE])
         ELSE GoH("return", [h EXCEPT !.humanDone = TRUE])

\* return（続きに戻る）
Continue == pc = "return" /\ Go("Done")
Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Write \/ Receipt \/ Resume \/ Integrate \/ Human \/ Continue
        \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 中断した側から再開するときは、控えを取り記録を書いてから
SnapshotBeforeResume == (pc = "resume" /\ E = "suspend") => (h.snap /\ h.recorded)

\* 別の担当に渡したときは、受け取りを確かめてから続ける。
\* 届かなかったときは、人に確かめてから（伝言を頼んでから）続ける
ReceiptBeforeContinue ==
    (pc \in {"resume", "return"} /\ E = "suspend" /\ Handoff)
        => IF F.undelivered THEN h.humanDone ELSE h.receipt

\* 続きに戻るのは、今の状態と照らした後か、委任の結果を統合した後
\* （委任だけで受け取りを確かめたとき、届かず人が続け方を決めたときを除く）
ComparedBeforeContinue ==
    pc = "return" => (h.compared \/ h.integrated \/ h.delegExit \/ h.humanDone)

\* 人に確かめる条件に当たるなら、人の決定の前に続きへ戻らない
HumanBeforeContinue == (pc = "return" /\ h.compared /\ NeedHuman) => h.humanDone

\* 委任の結果に問題があるなら、人の決定の前に続きへ戻らない
ResultIssueNeedsHuman == (pc = "return" /\ h.integrated /\ F.resultIssue) => h.humanDone

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
