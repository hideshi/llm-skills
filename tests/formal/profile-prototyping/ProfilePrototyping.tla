----------------------- MODULE ProfilePrototyping -------------------------
(***************************************************************************)
(* skills/dev-profile-prototyping の工程と、工程の間の決まりのモデル。     *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* build と wireframe の間の切り替え、show-ask からの試作の直し、          *)
(* direction-ask からのもう一周は、それぞれ1回まで起きうるとする。          *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口）は工程ではない
Steps == {"intake", "workspace", "build", "wireframe", "show-ask",
          "direction-ask", "cleanup", "final-ok"}

\* screen: もとにする画面の設計がある
\* code: 動くもので確かめる問いがある（モックで人に見せる問いを含む。
\*        無ければワイヤーから始める）
\* crossB: 動くコードの後に、ワイヤーでも確かめる（screen が要る。1回まで）
\* crossW: ワイヤーの後に、動くコードが要る（1回まで）
\* retry: show-ask で答えが出ず、試作を直す（1回まで）
\* retryWire: 直す先がワイヤー（偽なら動くコード。screen が要る）
\* again: direction-ask で、もう一周試作すると人が決める（1回まで）
\* againWire: もう一周の先がワイヤー（偽なら動くコード。screen が要る）
Flags == {"screen", "code", "crossB", "crossW", "retry", "retryWire",
          "again", "againWire"}

Init ==
    \* 確かめたい問いは、動くコードかワイヤーのどちらかで答える
    \* （ワイヤーは画面の設計が要る）
    /\ r \in {f \in [Flags -> BOOLEAN]: f.code \/ f.screen}
    /\ pc = "start"
    /\ h = [isolated |-> FALSE, builtCode |-> FALSE, builtWire |-> FALSE,
            crossed |-> FALSE, shown |-> FALSE, decided |-> FALSE,
            discardOk |-> FALSE, cleaned |-> FALSE, retried |-> FALSE,
            agained |-> FALSE]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

Start == pc = "start" /\ Go("intake")

\* intake（受付）
Intake == pc = "intake" /\ Go("workspace")

\* workspace（試作の場所を分ける）
Workspace == pc = "workspace"
    /\ GoH(IF r.code THEN "build" ELSE "wireframe",
           [h EXCEPT !.isolated = TRUE])

\* build（動くコードで試作する）
Build == pc = "build"
    /\ IF r.crossB /\ r.screen /\ ~h.crossed
         THEN GoH("wireframe", [h EXCEPT !.builtCode = TRUE, !.crossed = TRUE])
         ELSE GoH("show-ask", [h EXCEPT !.builtCode = TRUE])

\* wireframe（ワイヤーで試作する）
Wireframe == pc = "wireframe"
    /\ IF r.crossW /\ ~h.crossed
         THEN GoH("build", [h EXCEPT !.builtWire = TRUE, !.crossed = TRUE])
         ELSE GoH("show-ask", [h EXCEPT !.builtWire = TRUE])

\* show-ask（人に見せて確かめる）。答えが出なければ試作を直す（1回まで）
ShowAsk == pc = "show-ask"
    /\ IF r.retry /\ ~h.retried
         THEN IF r.retryWire /\ r.screen
                THEN GoH("wireframe", [h EXCEPT !.shown = TRUE, !.retried = TRUE])
                ELSE GoH("build", [h EXCEPT !.shown = TRUE, !.retried = TRUE])
         ELSE GoH("direction-ask", [h EXCEPT !.shown = TRUE])

\* direction-ask（進め方を人が決める）。
\* もう一周なら試作へ（1回まで）。本開発に進むか捨てるなら、破棄の承認を
\* 確かめたうえで片付けへ
DirectionAsk == pc = "direction-ask"
    /\ IF r.again /\ ~h.agained
         THEN IF r.againWire /\ r.screen
                THEN GoH("wireframe", [h EXCEPT !.decided = TRUE, !.agained = TRUE])
                ELSE GoH("build", [h EXCEPT !.decided = TRUE, !.agained = TRUE])
         ELSE GoH("cleanup", [h EXCEPT !.decided = TRUE, !.discardOk = TRUE])

\* cleanup（片付ける）
Cleanup == pc = "cleanup" /\ GoH("final-ok", [h EXCEPT !.cleaned = TRUE])

\* final-ok（最終確認）
Final == pc = "final-ok" /\ Go("Done")
Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Intake \/ Workspace \/ Build \/ Wireframe \/ ShowAsk
        \/ DirectionAsk \/ Cleanup \/ Final \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 試作（コード・ワイヤー）を作るのは、場所を分けた後
BuildIsolated == (h.builtCode \/ h.builtWire) => h.isolated

\* ワイヤーの単位で試作するのは、もとにする画面の設計があるときだけ
WireNeedsScreen == h.builtWire => r.screen

\* 人に見せるのは、コードかワイヤーを作った後
ShowAfterBuild == (pc \in {"show-ask", "direction-ask"}) =>
                      (h.builtCode \/ h.builtWire)

\* 進め方を人が決めるのは、人に見せた後
DecideAfterShow == h.decided => h.shown

\* 片付けに入るのは、進め方を人が決めた後
DecideBeforeCleanup == (pc \in {"cleanup", "final-ok"}) => h.decided

\* 片付けるのは、破棄の承認を確かめた後（統合しない）
DiscardBeforeClean == h.cleaned => h.discardOk

\* 最終確認は、片付けの後
CleanBeforeFinal == pc = "final-ok" => h.cleaned

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
