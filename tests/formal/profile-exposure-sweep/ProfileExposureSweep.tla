----------------------- MODULE ProfileExposureSweep -----------------------
(***************************************************************************)
(* skills/dev-profile-exposure-sweep の工程と、工程の間の決まりのモデル。   *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* triage-ask からの点検し直しは1回まで起きうるとする。                    *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口）は工程ではない
Steps == {"intake", "entry-check", "triage-ask", "final-ok"}

\* permit: 受付で要求を送ってよい相手の許可の記録がある
\* findings: 点検で、問題がある行か人の判断が要る行が出る
\* recheck: triage-ask で、事実を確かめて点検し直すか、人が許可を広げる（1回まで）
\* widen: 点検し直すときに、人が許可を足す
Flags == {"permit", "findings", "recheck", "widen"}

Init ==
    /\ pc = "start"
    /\ r \in [Flags -> BOOLEAN]
    /\ h = [permitted |-> FALSE, sent |-> FALSE, checked |-> FALSE,
            decided |-> FALSE, rechecked |-> FALSE]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

Start == pc = "start" /\ Go("intake")

\* intake（受付）。許可の記録があれば、許可済みとする
Intake == pc = "intake" /\ GoH("entry-check", [h EXCEPT !.permitted = r.permit])

\* entry-check（点検する）。許可があるときだけ要求を送る（無ければ作るところまで）
Check == pc = "entry-check"
    /\ GoH(IF r.findings /\ ~h.decided THEN "triage-ask" ELSE "final-ok",
           [h EXCEPT !.checked = TRUE, !.sent = h.sent \/ h.permitted])

\* triage-ask（人が決める）。点検し直すなら entry-check へ（1回まで）
Decide == pc = "triage-ask"
    /\ IF r.recheck /\ ~h.rechecked
         THEN GoH("entry-check", [h EXCEPT !.rechecked = TRUE,
                                 !.permitted = h.permitted \/ r.widen])
         ELSE GoH("final-ok", [h EXCEPT !.decided = TRUE])

\* final-ok（最終確認）
Final == pc = "final-ok" /\ Go("Done")
Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Intake \/ Check \/ Decide \/ Final \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 要求を送ったなら、受付か点検し直しで人が許可を記録している
SendOnlyWithPermission == h.sent => (r.permit \/ (r.widen /\ h.rechecked))

\* 人が決めるのは、点検を終えた後
CheckBeforeDecide == pc = "triage-ask" => h.checked

\* 問題がある行か人の判断が要る行があれば、人が決めてから最終確認へ
DecisionBeforeFinal == (pc = "final-ok" /\ r.findings) => h.decided

\* 最終確認は、点検を終えた後
CheckBeforeFinal == pc = "final-ok" => h.checked

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
