----------------------- MODULE ProfileVersionControl -----------------------
(***************************************************************************)
(* skills/dev-profile-version-control の工程と、工程の間の決まりのモデル。  *)
(* 単位の中身は抽象化し、工程の順序、条件、戻る流れ、人の決定だけを表す。   *)
(***************************************************************************)
EXTENDS Naturals, TLC

VARIABLES pc, r, h, nexec, napp
vars == << pc, r, h, nexec, napp >>

\* 表さない工程: なし。"start"（入口の判定）は工程ではない
Steps == {"workspace", "work", "integrate", "resolve", "contract-ask", "recover", "destructive-ok", "cleanup"}

\* entry: 入口（作業場所を作る／統合する／衝突を解く／戻る／片付ける）
\* hasWorkspace: 作業場所を使っているか
\* requestCleanup: 片付けまで依頼されているか（入口 workspace・cleanup に加えて統合時に片付けを求める場合）
\* discardApproved: 統合せず破棄する人の承認があるか
\* workTrouble / mergeTrouble / resolveTrouble: 各工程でトラブルが起きたか
\* conflict: 衝突または統合後の不整合があるか
\* contractChange: 未決の契約の変化があるか
\* destructive: 印に「取り返せない」が付く操作または外部道具の導入が要るか
\* needResolveAfterRecovery: 復旧後に衝突の解消が要るか
Entries == {"workspace", "integrate", "resolve", "recover", "cleanup"}
Flags == {"hasWorkspace", "requestCleanup", "discardApproved",
          "workTrouble", "conflict", "mergeTrouble",
          "contractChange", "resolveTrouble", "destructive",
          "needResolveAfterRecovery"}

Init ==
    /\ pc = "start"
    /\ r \in [entry: Entries] \X [Flags -> BOOLEAN]
    /\ h = [isolated |-> FALSE, tableMade |-> FALSE, contractDecided |-> FALSE,
            resolved |-> FALSE, planned |-> FALSE, approved |-> FALSE,
            recovered |-> FALSE, workRecovered |-> FALSE,
            mergeRecovered |-> FALSE, resolveRecovered |-> FALSE,
            integrated |-> (r[1].entry = "cleanup"),
            discardApproved |-> (r[1].entry = "cleanup" /\ r[2].discardApproved),
            aborted |-> FALSE, execAtAbort |-> 0, cleaned |-> FALSE, lastSource |-> "none"]
    /\ nexec = 0
    /\ napp = 0

E == r[1].entry
F == r[2]

HasWs == (E \in {"workspace", "cleanup"}) \/ F.hasWorkspace
CleanupRequested == (E \in {"workspace", "cleanup"}) \/ F.requestCleanup
NeedIntegrate == (HasWs /\ CleanupRequested) \/ (E = "integrate")

Go(s) == pc' = s /\ UNCHANGED << r, h, nexec, napp >>
GoH(s, h2) == pc' = s /\ h' = h2 /\ UNCHANGED << r, nexec, napp >>
GoHN(s, h2, ne, na) == pc' = s /\ h' = h2 /\ nexec' = ne /\ napp' = na /\ UNCHANGED r

\* 入口
Start == pc = "start"
    /\ Go(CASE E = "workspace" -> "workspace"
            [] E = "integrate" -> "integrate"
            [] E = "resolve"   -> "resolve"
            [] E = "recover"   -> "recover"
            [] OTHER           -> "cleanup")

\* workspace（作業場所を作る。ファイルだけでなく保存先・実行枠・依存の隔離を確かめてから work へ）
MakeWorkspace == pc = "workspace"
    /\ GoH("work", [h EXCEPT !.isolated = TRUE])

\* work（作業する）
Work == pc = "work"
    /\ IF F.workTrouble /\ ~h.workRecovered
         THEN GoH("recover", [h EXCEPT !.lastSource = "work"])
         ELSE Go("integrate")

\* integrate（取り込む。統合の完了・確認または破棄承認を終えてから cleanup へ進む）
Integrate == pc = "integrate"
    /\ IF F.mergeTrouble /\ ~h.mergeRecovered
         THEN GoH("recover", [h EXCEPT !.lastSource = "integrate"])
       ELSE IF F.conflict /\ ~h.resolved /\ ~F.discardApproved
         THEN Go("resolve")
       ELSE LET hDone == [h EXCEPT !.integrated = (@ \/ ~F.discardApproved),
                                   !.discardApproved = (@ \/ F.discardApproved)] IN
            IF HasWs /\ CleanupRequested
              THEN GoH("cleanup", hDone)
              ELSE GoH("Done", hDone)

\* resolve（衝突を解く。編集の前に表を作り、未決の契約の変化があれば人の決定を待つ）
Resolve == pc = "resolve"
    /\ IF F.contractChange /\ ~h.contractDecided
         THEN GoH("contract-ask", [h EXCEPT !.tableMade = TRUE])
       ELSE IF F.resolveTrouble /\ ~h.resolveRecovered
         THEN GoH("recover", [h EXCEPT !.tableMade = TRUE, !.lastSource = "resolve"])
       ELSE IF NeedIntegrate
         THEN GoH("integrate", [h EXCEPT !.tableMade = TRUE, !.resolved = TRUE])
         ELSE GoH("Done", [h EXCEPT !.tableMade = TRUE, !.resolved = TRUE])

\* contract-ask（人が決める。契約の選択を決めて resolve に戻る）
DecideContract == pc = "contract-ask"
    /\ GoH("resolve", [h EXCEPT !.contractDecided = TRUE])

\* recover（困りごとから戻す。印に「取り返せない」が付く操作または外部道具の導入なら毎回 destructive-ok で承認を得る）
Recover == pc = "recover"
    /\ IF F.destructive /\ ~h.approved
         THEN GoH("destructive-ok", [h EXCEPT !.planned = TRUE])
       ELSE LET ne == IF F.destructive THEN nexec + 1 ELSE nexec
                hExec == [h EXCEPT !.recovered = TRUE,
                                   !.planned = FALSE,
                                   !.approved = FALSE] IN
            IF h.lastSource = "work"
              THEN GoHN("work", [hExec EXCEPT !.workRecovered = TRUE], ne, napp)
            ELSE IF h.lastSource = "resolve" \/ (F.needResolveAfterRecovery /\ ~h.resolved)
              THEN LET hNext == IF h.lastSource = "integrate"
                                  THEN [hExec EXCEPT !.mergeRecovered = TRUE]
                                ELSE IF h.lastSource = "resolve"
                                  THEN [hExec EXCEPT !.resolveRecovered = TRUE]
                                  ELSE hExec IN
                   GoHN("resolve", hNext, ne, napp)
            ELSE IF h.lastSource = "integrate" \/ (HasWs /\ CleanupRequested)
              THEN GoHN("integrate", IF h.lastSource = "integrate"
                               THEN [hExec EXCEPT !.mergeRecovered = TRUE]
                               ELSE hExec, ne, napp)
            ELSE GoHN("Done", hExec, ne, napp)

\* destructive-ok（破壊的な操作を承認する。訪問ごとに承認か中止を非決定に選ぶ。中止なら実行せず終わる）
ApproveDestructive == pc = "destructive-ok"
    /\ \/ GoHN("recover", [h EXCEPT !.approved = TRUE], nexec, napp + 1)
       \/ GoHN("Done", [h EXCEPT !.planned = FALSE, !.approved = FALSE, !.aborted = TRUE,
                                 !.execAtAbort = nexec], nexec, napp)

\* cleanup（片付ける）
Cleanup == pc = "cleanup"
    /\ GoH("Done", [h EXCEPT !.cleaned = TRUE])

Finished == pc = "Done" /\ UNCHANGED vars

Next == Start \/ MakeWorkspace \/ Work \/ Integrate \/ Resolve
        \/ DecideContract \/ Recover \/ ApproveDestructive \/ Cleanup \/ Finished

Spec == Init /\ [][Next]_vars /\ WF_vars(Next)

-----------------------------------------------------------------------------
TypeOK == pc \in Steps \cup {"start", "Done"}

\* 作業場所を作ったときは、隔離を確かめてから作業へ進む
IsolatedBeforeWork == (pc = "work") => h.isolated

\* 衝突の解消を終えた時点で、統合の判断表がある（表と編集の前後は単位の中の順序で、ここでは検査しない）
TableBeforeResolved == h.resolved => h.tableMade

\* 未決の契約の変化があるなら、人の決定の前に解消を終えない
ContractDecisionBeforeDone ==
    (h.tableMade /\ F.contractChange /\ (h.resolved \/ pc \in {"integrate", "cleanup", "Done"})) => h.contractDecided

\* 印に「取り返せない」が付く復旧（または外部道具の導入）の実行回数は、destructive-ok での承認回数を超えない
ApprovalBeforeDestructive ==
    nexec <= napp

\* 人が中止を決めた場合、そのまま中止状態として終わり、中止の後に破壊的操作の実行回数が増えない
AbortedNeverExecutes ==
    h.aborted => (pc = "Done" /\ nexec = h.execAtAbort)

\* 作業場所の片付けは、統合完了・確認後または破棄承認後（あるいは片付けを入口にした場合）だけに行う
IntegrationOrDiscardBeforeCleanup ==
    (pc = "cleanup" \/ h.cleaned) => (h.integrated \/ h.discardApproved)

\* 片付けが必要な依頼では、中止しない限り片付けを終えてから完了する
CleanupBeforeDone ==
    (HasWs /\ CleanupRequested /\ ~h.aborted /\ pc = "Done") => h.cleaned

Terminates == <>(pc = "Done")

-----------------------------------------------------------------------------
(* 工程の移り変わりの書き出し（scripts/check_dev_flows.py が使う。検査には影響しない） *)
ASSUME TLCSet(42, {})
EdgeProbe == LET e == << pc, pc' >> IN
    IF e \in TLCGet(42) THEN TRUE
    ELSE PrintT(<< "EDGE", pc, pc' >>) /\ TLCSet(42, TLCGet(42) \cup {e})
=============================================================================
