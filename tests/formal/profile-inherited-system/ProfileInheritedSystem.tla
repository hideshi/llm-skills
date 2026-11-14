---------------------- MODULE ProfileInheritedSystem ----------------------
(***************************************************************************)
(* skills/dev-profile-inherited-system の工程と、工程の間の決まりのモデル。 *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(* 前任者への問いの答え、目録と台帳の答え、期限つきの保留、承認しないこと *)
(* は、それぞれ1回まで起きうるとする。                                     *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h
vars == << pc, r, h >>

\* 表さない工程: なし。"start"（入口）は工程ではない
Steps == {"intake", "map", "map-ask", "catalog", "ledger", "inventory-ask", "inventory-ok"}

\* qs: 地図から前任者や人に問う事実確認が出る
\* absent: 前任者がいない（問いは不明として残す）
\* personal: 個人の情報を扱うと人が決めた
\* catQs: 目録に人に問う事実確認が出る。ledQs: 台帳に確認事項が出る
\* defer: inventory-ask で答えを待たず期限つきで保留にする
\* reject: inventory-ok で承認しない（直す先は target）
Targets == {"map", "catalog", "ledger"}
\* mapExists: 承認した地図が既にあり、受付から目録へ進む
Flags == {"qs", "absent", "personal", "catQs", "ledQs", "defer", "reject", "mapExists"}

Init ==
    /\ pc = "start"
    /\ r \in [target: Targets] \X [Flags -> BOOLEAN]
    /\ h = [asked |-> FALSE, catDone |-> FALSE, ledDone |-> FALSE,
            ansCat |-> FALSE, ansLed |-> FALSE, deferred |-> FALSE,
            rejected |-> FALSE, approved |-> FALSE]

T == r[1].target
F == r[2]

Go(s) == pc' = s /\ UNCHANGED << r, h >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED r

PendingCat == F.catQs /\ ~h.ansCat /\ ~h.deferred
PendingLed == F.personal /\ F.ledQs /\ ~h.ansLed /\ ~h.deferred

\* 承認しないときの直す先（台帳を作らないなら目録へ）
RejectTo == IF T = "ledger" /\ ~F.personal THEN "catalog" ELSE T

\* 直したら承認はやり直し
Changed(hh) == [hh EXCEPT !.approved = FALSE]

Start == pc = "start" /\ Go("intake")

\* intake（受付）
Intake == pc = "intake" /\ Go(IF F.mapExists THEN "catalog" ELSE "map")

\* map（地図を作る）。問う事実確認があり、まだ問うていなければ map-ask へ
Map == pc = "map"
    /\ GoH(IF F.qs /\ ~h.asked THEN "map-ask" ELSE "catalog", Changed(h))

\* map-ask（前任者か人に確かめる）。答えを受けたら map で反映、いなければ catalog へ
Ask == pc = "map-ask"
    /\ GoH(IF F.absent THEN "catalog" ELSE "map", [h EXCEPT !.asked = TRUE])

\* catalog（秘密の目録を作る）
Catalog == pc = "catalog"
    /\ LET h2 == [Changed(h) EXCEPT !.catDone = TRUE] IN
       GoH(IF F.personal THEN "ledger"
           ELSE IF PendingCat THEN "inventory-ask" ELSE "inventory-ok", h2)

\* ledger（個人情報の台帳を作る）
Ledger == pc = "ledger"
    /\ LET h2 == [Changed(h) EXCEPT !.ledDone = TRUE] IN
       GoH(IF PendingCat \/ PendingLed THEN "inventory-ask" ELSE "inventory-ok", h2)

\* inventory-ask（人に確かめる）。答えを目録か台帳に反映する。または期限つきで保留
Confirm == pc = "inventory-ask"
    /\ IF F.defer
         THEN GoH("inventory-ok", [h EXCEPT !.deferred = TRUE])
       ELSE IF PendingCat
         THEN GoH("catalog", [h EXCEPT !.ansCat = TRUE])
       ELSE GoH("ledger", [h EXCEPT !.ansLed = TRUE])

\* inventory-ok（承認する）。承認しないなら直す先へ（1回まで）
Approve == pc = "inventory-ok"
    /\ IF F.reject /\ ~h.rejected
         THEN GoH(RejectTo, [h EXCEPT !.rejected = TRUE])
         ELSE GoH("Done", [h EXCEPT !.approved = TRUE])

Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ Intake \/ Map \/ Ask \/ Catalog \/ Ledger \/ Confirm
        \/ Approve \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 地図に問う事実確認があれば、目録へ進む前に問う
AskBeforeCatalog == (pc = "catalog" /\ F.qs /\ ~F.mapExists) => h.asked

\* 台帳は、個人の情報を扱うと人が決めたときだけ作る
LedgerOnlyIfPersonal == h.ledDone => F.personal

\* 個人の情報を扱うなら、承認の前に台帳がある
LedgerBeforeApproval == (pc = "inventory-ok" /\ F.personal) => h.ledDone

\* 承認の前に、目録と台帳の問いは答えを反映したか期限つきで保留にした
AnswersBeforeApproval == pc = "inventory-ok" => (~PendingCat /\ ~PendingLed)

\* 終わるのは、直した後の版を人が承認したときだけ
DoneOnlyApproved == pc = "Done" => h.approved

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
