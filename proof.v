Require Export lemmas.

Definition var_id := nat.
Definition class_id := nat.
Definition obj_id : class_id := 0.
Inductive var : Type :=
| Var : var_id -> var
| This : var.
Definition beq_var (v v' : var) : bool :=
  match v, v' with
  | This, This => true
  | Var vi, Var vi' => beq_nat vi vi'
  | _, _ => false
  end.

Theorem beq_var_refl : forall v, true = beq_var v v.
Proof. intros. destruct v; eauto. simpl. apply beq_nat_refl. Qed.
Theorem beq_var_true : forall v v', v = v' <-> true = beq_var v v'.
Proof.
  intros. split; intro; destruct v; destruct v'; inversion H; eauto.
  - apply beq_var_refl.
  - symmetry in H1. apply beq_nat_true in H1. eauto.
Qed.


Definition field_id := nat.
Definition method_id := nat.
Inductive expr : Type :=
| E_Var : var -> expr
| E_Field : expr -> field_id -> expr
| E_Invk : expr -> method_id -> list expr -> expr
| E_New : class_id -> list expr -> expr
| E_Cast : class_id -> expr -> expr
| E_Lib : expr.

Definition expr_rect_list :=
  fun (P : expr -> Type) (Q : list expr -> Type)
    (g : Q nil) (h : forall e l, P e -> Q l -> Q (e :: l))
    (f : forall v : var, P (E_Var v))
    (f0 : forall e : expr, P e -> forall f0 : field_id, P (E_Field e f0))
    (f1 : forall (c : class_id) (l : list expr), Q l -> P (E_New c l))
    (f2 : forall e : expr, P e -> forall (m : method_id) (l : list expr), Q l -> P (E_Invk e m l))
    (f3 : forall (c : class_id) (e : expr), P e -> P (E_Cast c e)) (f4 : P E_Lib) =>
    fix F (e : expr) : P e :=
    match e as e0 return (P e0) with
    | E_Var v => f v
    | E_Field e0 f5 => f0 e0 (F e0) f5
    | E_New c l => f1 c l (list_rect Q g (fun u r => h u r (F u)) l)
    | E_Invk e0 m l => f2 e0 (F e0) m l (list_rect Q g (fun u r => h u r (F u)) l)
    | E_Cast c e0 => f3 c e0 (F e0)
    | E_Lib => f4
    end.

Definition expr_ind_list :
  forall P : expr -> Prop,
    (forall v : var, P (E_Var v)) ->
    (forall e : expr, P e -> forall f0 : field_id, P (E_Field e f0)) ->
    (forall (c : class_id) (l : list expr), Forall P l -> P (E_New c l)) ->
    (forall e : expr, P e -> forall (m : method_id) (l : list expr), Forall P l -> P (E_Invk e m l)) ->
    (forall (c : class_id) (e : expr), P e -> P (E_Cast c e)) -> P E_Lib -> forall e : expr, P e :=
  fun (P : expr -> Prop) => expr_rect_list P (Forall P) (Forall_nil P) (@Forall_cons expr P).

Definition context := list (var * class_id).

Definition lookup_context (gamma : context) (v : var) : option class_id :=
  option_map snd (find (fun p => beq_var v (fst p)) gamma).

Definition params := list (class_id * var_id).

Inductive constr : Type :=
| Constr : class_id -> params -> list var_id -> list (field_id * var_id) -> constr.

Inductive method := Method : class_id -> method_id -> params -> expr -> method.

Inductive class : Type :=
| Obj : class
| C : class_id -> class_id -> list (class_id * field_id) -> constr -> list method -> class.

(* Table Definitions *)

Definition class_table : Type := (class_id -> option class) * (class_id -> option class).
Hint Unfold class_table.

Definition empty_map : class_id -> option class := fun _ => None.
Hint Unfold empty_map.

Definition ct_app (ct : class_table) : class_table :=
  match ct with (app, _) => (app, empty_map) end.

Definition ct_lib (ct : class_table) : class_table :=
  match ct with (_, lib) => (empty_map, lib) end.

Definition lookup_class (ct : class_table) (i : class_id) : option class :=
  match ct with (app, lib) =>
                match app i with
                | Some c => Some c
                | None => lib i
                end
  end.

Definition lookup_method (c : class) (mi : method_id) : option method :=
  match c with
  | Obj => None
  | C _ _ _ _ ms => find (fun m => match m with Method _ mi' _ _ => beq_nat mi mi' end) ms
  end.

Definition id_of (c : class) : class_id :=
  match c with
  | Obj => obj_id
  | C ci _ _ _ _ => ci
  end.

Definition par_id_of (c : class) : option class_id :=
  match c with
  | Obj => None
  | C _ di _ _ _ => Some di
  end.

Definition in_lib_id (ct : class_table) (i : class_id) : Prop :=
  match ct with (_, lib) => exists c, lib i = Some c end.
Hint Unfold in_lib_id.

Definition in_app_id (ct : class_table) (i : class_id) : Prop :=
  match ct with (app, _) => exists c, app i = Some c end.
Hint Unfold in_app_id.

Definition in_lib (ct : class_table) (c : class) : Prop :=
  match ct with (_, lib) => lib (id_of c) = Some c end.
Hint Unfold in_lib.

Definition in_app (ct : class_table) (c : class) : Prop :=
  match ct with (app, _) => app (id_of c) = Some c end.
Hint Unfold in_app.

Definition in_table_id (ct : class_table) (i : class_id) : Prop :=
  in_app_id ct i \/ in_lib_id ct i.
Hint Unfold in_table_id.

Definition in_table (ct : class_table) (c : class) : Prop :=
  in_app ct c \/ in_lib ct c.
Hint Unfold in_table.

(* Table Lemmas *)

Lemma in_app_in_table : forall (ct : class_table) (c : class),
    in_app ct c -> in_table ct c.
Proof. eauto. Qed.
Hint Resolve in_app_in_table.

Lemma in_lib_in_table : forall (ct : class_table) (c : class),
    in_lib ct c -> in_table ct c.
Proof. eauto. Qed.
Hint Resolve in_lib_in_table.

Lemma in_app_in_table_id : forall (ct : class_table) (ci : class_id),
    in_app_id ct ci -> in_table_id ct ci.
Proof. eauto. Qed.
Hint Resolve in_app_in_table_id.

Lemma in_lib_in_table_id : forall (ct : class_table) (ci : class_id),
    in_lib_id ct ci -> in_table_id ct ci.
Proof. eauto. Qed.
Hint Resolve in_lib_in_table_id.

Lemma in_app_in_app_id : forall ct c,
    in_app ct c -> in_app_id ct (id_of c).
Proof.
  intros. destruct ct; eexists; eauto.
Qed.
Hint Resolve in_app_in_app_id.

Lemma in_lib_in_lib_id : forall ct c,
    in_lib ct c -> in_lib_id ct (id_of c).
Proof.
  intros. destruct ct; eexists; eauto.
Qed.
Hint Resolve in_lib_in_lib_id.

Lemma in_table_in_table_id : forall ct c,
    in_table ct c -> in_table_id ct (id_of c).
Proof.
  intros. destruct H; eauto.
Qed.
Hint Resolve in_table_in_table_id.

(* More Definitions *)

Definition extends (ct : class_table) (c d : class) : Prop :=
  match c with
  | Obj => False
  | C _ di _ _ _ => lookup_class ct di = Some d
  end.

Definition extends_id (ct : class_table) (ci di : class_id) : Prop :=
  match lookup_class ct ci with
  | None => False
  | Some Obj => False
  | Some (C _ di' _ _ _) => di = di'
  end.

Inductive subtype (ct : class_table) : class -> class -> Type :=
| S_Ref : forall (c : class), in_table ct c -> subtype ct c c
| S_Trans : forall (c d e : class), subtype ct c d -> subtype ct d e -> subtype ct c e
| S_Sub : forall (c d : class), in_table ct c -> extends ct c d -> subtype ct c d.
Hint Constructors subtype.

Inductive subtype_id (ct : class_table) : class_id -> class_id -> Prop :=
| SI_Ref : forall ci, in_table_id ct ci -> subtype_id ct ci ci
| SI_Sub : forall ci di, extends_id ct ci di -> subtype_id ct ci di
| SI_Trans : forall ci di ei, subtype_id ct ci di -> subtype_id ct di ei -> subtype_id ct ci ei.
Hint Constructors subtype_id.

Inductive valid_class (ct : class_table) : class -> Type :=
| ValidObj : in_lib ct Obj -> ~ in_app ct Obj -> valid_class ct Obj
| ValidParent : forall c d,
    valid_class ct d -> extends ct c d ->
    ~ (in_lib ct c /\ in_app ct c) ->
    (in_lib ct d /\ in_table ct c) \/ (in_app ct d /\ in_app ct c)  ->
    valid_class ct c.
Hint Constructors valid_class.

Definition body (m : method) : expr := match m with Method _ _ _ e => e end.
Hint Unfold body.

Definition ret_type (m : method) : class_id := match m with Method ci _ _ _  => ci end.
Hint Unfold ret_type.

Definition params_of (m : method) : params :=
    match m with
    | Method _ _ l _ => l
    end.
Hint Unfold params_of.

Definition param_names (m : method) : list var := map Var (map snd (params_of m)).
Hint Unfold param_names.

Definition params_as_context (m : method) : list (var * class_id) :=
  map (fun p => (Var (snd p), fst p)) (params_of m).
Hint Unfold params_as_context.

Definition mid (m : method) : method_id := match m with Method _ mi _ _ => mi end.
Hint Unfold mid.

Definition mtype_of (m : method) :=
  (map fst (params_of m), ret_type m).
Hint Unfold mtype_of.

Fixpoint find_method {ct : class_table} {c : class} (mi : method_id) (pfc : valid_class ct c) : option method :=
  match pfc with
  | ValidObj _ _ _ => None
  | ValidParent _ _ _ pfd _ _ _ => match lookup_method c mi with
                               | Some m => Some m
                               | None => find_method mi pfd
                               end
  end.
Hint Unfold find_method.

Fixpoint mtype (ct : class_table) (mi : method_id) (c : class) (pfc : valid_class ct c) :
  option (list class_id * class_id) :=
  match pfc with
  | ValidObj _ _ _ => None
  | ValidParent _ _ d pfd _ _ _  =>
    match lookup_method c mi with
    | None => mtype ct mi d pfd
    | Some m => Some (mtype_of m)
    end
  end.
Hint Unfold mtype.

Definition dfields (c : class) : list (class_id * field_id) :=
  match c with
  | Obj => nil
  | C _ _ fs _ _ => fs
  end.
Hint Unfold dfields.

Definition dfield_ids (c : class) : list field_id :=
  map snd (dfields c).
Hint Unfold dfield_ids.

Definition dfield_typs (c : class) : list class_id :=
  map fst (dfields c).
Hint Unfold dfield_typs.

Fixpoint fields {ct : class_table} {c : class} (pfc : valid_class ct c) : list (class_id * field_id) :=
  dfields c ++ match pfc with
               | ValidParent _ _ _ pfd  _ _ _ => fields pfd
               | ValidObj _ _ _ => nil
               end.
Hint Unfold fields.

Definition field_ids {ct : class_table} {c : class} (pfc : valid_class ct c) : list field_id :=
  map snd (fields pfc).
Hint Unfold field_ids.

Definition lookup_field {ct : class_table} {c : class} (pfc : valid_class ct c) (f : field_id) : option class_id :=
  option_map fst (find (fun p => beq_nat f (snd p)) (fields pfc)).
Hint Unfold lookup_field.

Fixpoint declaring_class (ct : class_table) (c : class) (pfc : valid_class ct c) (fi : field_id) : option class_id :=
  match pfc with
  | ValidObj _  _ _ => None
  | ValidParent _ _ d pfd  _ _ _ => if (@existsb field_id (beq_nat fi) (dfield_ids c))
                                    then Some (id_of c)
                                    else declaring_class ct d pfd fi
  end.
Hint Unfold declaring_class.

Inductive type_of (ct : class_table) (gamma : context) : expr -> class_id -> Prop :=
| T_Var : forall x ci,
    lookup_context gamma x = Some ci ->
    in_table_id ct ci ->
    type_of ct gamma (E_Var x) ci
| T_Field : forall e c (pfc : valid_class ct c) di f,
    type_of ct gamma e (id_of c) ->
    lookup_field pfc f = Some di ->
    type_of ct gamma (E_Field e f) di
| T_New : forall c (pfc : valid_class ct c) le lc,
    length (field_ids pfc) = length le -> length le = length lc ->
    Forall (fun p => type_of ct gamma (fst p) (snd p)) (combine le lc) ->
    Forall (fun p => subtype_id ct (fst p) (snd p)) (combine lc (field_ids pfc)) ->
    type_of ct gamma (E_New (id_of c) le) (id_of c)
| T_Invk : forall e c pfc ld ret mi le lc,
    type_of ct gamma e (id_of c) ->
    mtype ct mi c pfc = Some (ld, ret) ->
    length ld = length le -> length le = length lc ->
    Forall (fun p => type_of ct gamma (fst p) (snd p)) (combine le lc) ->
    Forall (fun p => subtype_id ct (fst p) (snd p)) (combine lc ld) ->
    type_of ct gamma (E_Invk e mi le) (id_of c)
| T_Cast : forall e ci di,
    type_of ct gamma e di ->
    in_table_id ct ci ->
    type_of ct gamma (E_Cast ci e) ci
| T_Lib : forall ci, in_table_id ct ci -> type_of ct gamma E_Lib ci.
Hint Constructors type_of.

Definition type_of_ind_list :=
  fun (ct : class_table) (gamma : context) (P : expr -> class_id -> Prop)
    (f : forall (x : var) (ci : class_id), lookup_context gamma x = Some ci -> in_table_id ct ci -> P (E_Var x) ci)
    (f0 : forall (e : expr) (c : class) (pfc : valid_class ct c) (di : class_id) (f0 : field_id),
        type_of ct gamma e (id_of c) -> P e (id_of c) -> lookup_field pfc f0 = Some di -> P (E_Field e f0) di)
    (f1 : forall (c : class) (pfc : valid_class ct c) (le : list expr) (lc : list class_id),
        length (field_ids pfc) = length le ->
        length le = length lc ->
        Forall (fun p : expr * class_id => type_of ct gamma (fst p) (snd p)) (combine le lc) ->
        Forall (fun p : class_id * class_id => subtype_id ct (fst p) (snd p)) (combine lc (field_ids pfc)) ->
        Forall (fun p : expr * class_id => P (fst p) (snd p)) (combine le lc) ->
        P (E_New (id_of c) le) (id_of c))
    (f2 : forall (e : expr) (c : class) (pfc : valid_class ct c) (ld : list class_id) (ret : class_id)
            (mi : method_id) (le : list expr) (lc : list class_id),
        type_of ct gamma e (id_of c) ->
        P e (id_of c) ->
        mtype ct mi c pfc = Some (ld, ret) ->
        length ld = length le ->
        length le = length lc ->
        Forall (fun p : expr * class_id => type_of ct gamma (fst p) (snd p)) (combine le lc) ->
        Forall (fun p : class_id * class_id => subtype_id ct (fst p) (snd p)) (combine lc ld) ->
        Forall (fun p : expr * class_id => P (fst p) (snd p)) (combine le lc) ->
        P (E_Invk e mi le) (id_of c))
    (f3 : forall (e : expr) (ci di : class_id),
        type_of ct gamma e di -> P e di -> in_table_id ct ci -> P (E_Cast ci e) ci)
    (f4 : forall ci : class_id, in_table_id ct ci -> P E_Lib ci) =>
    fix F (e : expr) (c : class_id) (t : type_of ct gamma e c) {struct t} : P e c :=
    match t in (type_of _ _ e0 c0) return (P e0 c0) with
    | T_Var _ _ x ci e0 i => f x ci e0 i
    | T_Field _ _ e0 c0 pfc di f5 t0 e1 => f0 e0 c0 pfc di f5 t0 (F e0 (id_of c0) t0) e1
    | T_New _ _ c0 pfc le lc e0 e1 f5 f6 =>
      f1 c0 pfc le lc e0 e1 f5 f6
         (let Q := (fun p => type_of ct gamma (fst p) (snd p)) in
          let P' := (fun p => P (fst p) (snd p)) in
          (fix f_impl (l : list (expr * class_id)) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ p l' Qp Ql' => Forall_cons p (F (fst p) (snd p) Qp) (f_impl l' Ql')
             end) (combine le lc) f5)
    | T_Invk _ _ e0 c0 pfc ld ret mi le lc t0 e1 e2 e3 f5 f6 =>
      f2 e0 c0 pfc ld ret mi le lc t0 (F e0 (id_of c0) t0) e1 e2 e3 f5 f6
         (let Q := (fun p => type_of ct gamma (fst p) (snd p)) in
          let P' := (fun p => P (fst p) (snd p)) in
          (fix f_impl (l : list (expr * class_id)) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ p l' Qp Ql' => Forall_cons p (F (fst p) (snd p) Qp) (f_impl l' Ql')
             end) (combine le lc) f5)
    | T_Cast _ _ e0 ci di t0 i => f3 e0 ci di t0 (F e0 di t0) i
    | T_Lib _ _ ci H => f4 ci H
    end.

Definition type_checks ct gamma e :=
  exists ci, type_of ct gamma e ci.
Hint Unfold type_checks.

(*Inductive type_checks (ct : class_table) (gamma : context) : expr -> Prop :=
| TC_Var : forall x ci, lookup_context gamma x = Some ci -> in_table_id ct ci -> type_checks ct gamma (E_Var x)
| TC_Field : forall e f di, type_of ct gamma (E_Field e f) di -> in_table_id ct di -> type_checks ct gamma e ->
                       type_checks ct gamma (E_Field e f)
| TC_New : forall ci le, in_table_id ct ci -> Forall (type_checks ct gamma) le -> type_checks ct gamma (E_New ci le)
| TC_Invk : forall e m le di, type_of ct gamma (E_Invk e m le) di -> in_table_id ct di ->
                      type_checks ct gamma e -> Forall (type_checks ct gamma) le ->
                      type_checks ct gamma (E_Invk e m le)
| TC_Cast : forall e di, in_table_id ct di -> type_checks ct gamma e -> type_checks ct gamma (E_Cast di e)
| TC_Lib : type_checks ct gamma E_Lib.
Hint Constructors type_checks.*)

Definition dmethods (c : class) : list method :=
  match c with
  | Obj => nil
  | C _ _ _ _ ms => ms
  end.
Hint Unfold dmethods.

Definition dmethods_id (c : class) : list method_id :=
  map mid (dmethods c).
Hint Unfold dmethods_id.

Fixpoint mresolve (ct : class_table) (mi : method_id) (c : class) (pfc : valid_class ct c) : option class :=
  match pfc with
  | ValidObj _ _  _ => None
  | ValidParent _ _ d pfd _  _ _ => if (existsb (beq_nat mi) (dmethods_id c))
                                      then Some c
                                      else mresolve ct mi d pfd
  end.
Hint Unfold mresolve.

(*Inductive valid_expr (ct : class_table) (gamma : context) : expr -> Prop :=
| Val_Var : forall x, type_checks ct gamma (E_Var x) -> valid_expr ct gamma (E_Var x)
| Val_Field : forall e f ci c pfc,
    type_checks ct gamma (E_Field e f) ->
    type_of ct gamma e ci -> id_of c = ci ->
    (exists di, declaring_class ct c pfc f = Some di) ->
    valid_expr ct gamma e ->
    valid_expr ct gamma (E_Field e f)
| Val_New : forall ci le,
    type_checks ct gamma (E_New ci le) ->
    Forall (valid_expr ct gamma) le ->
    valid_expr ct gamma (E_New ci le)
| Val_Invk : forall e m le ci c pfc,
    type_checks ct gamma (E_Invk e m le) ->
    valid_expr ct gamma e ->
    Forall (valid_expr ct gamma) le ->
    type_of ct gamma e ci -> id_of c = ci ->
    (exists d, mresolve ct m c pfc = Some d) ->
    valid_expr ct gamma (E_Invk e m le)
| Val_Cast : forall ci e,
    type_checks ct gamma (E_Cast ci e) -> valid_expr ct gamma e -> valid_expr ct gamma (E_Cast ci e)
| Val_Lib : valid_expr ct gamma E_Lib.

Definition valid_expr_ind_list :=
  fun (ct : class_table) (gamma : context) (P : expr -> Prop)
    (f : forall x : var, type_checks ct gamma (E_Var x) -> P (E_Var x))
    (f0 : forall (e : expr) (f0 : field_id) (ci : class_id) (c : class) (pfc : valid_class ct c),
        type_checks ct gamma (E_Field e f0) ->
        type_of ct gamma e ci ->
        id_of c = ci ->
        (exists di : class_id, declaring_class ct c pfc f0 = Some di) ->
        valid_expr ct gamma e -> P e -> P (E_Field e f0))
    (f1 : forall (ci : class_id) (le : list expr),
        type_checks ct gamma (E_New ci le) ->
        Forall (valid_expr ct gamma) le ->
        Forall P le ->
        P (E_New ci le))
    (f2 : forall (e : expr) (m : method_id) (le : list expr) (ci : class_id) (c : class) (pfc : valid_class ct c),
        type_checks ct gamma (E_Invk e m le) ->
        valid_expr ct gamma e ->
        P e ->
        Forall (valid_expr ct gamma) le ->
        Forall P le ->
        type_of ct gamma e ci ->
        id_of c = ci ->
        (exists d : class, mresolve ct m c pfc = Some d) ->
        P (E_Invk e m le))
    (f3 : forall (ci : class_id) (e : expr),
        type_checks ct gamma (E_Cast ci e) -> valid_expr ct gamma e -> P e -> P (E_Cast ci e)) 
    (f4 : P E_Lib) =>
    fix F (e : expr) (v : valid_expr ct gamma e) {struct v} : P e :=
    match v in (valid_expr _ _ e0) return (P e0) with
    | Val_Var _ _ x t => f x t
    | Val_Field _ _ e0 f5 ci c pfc t t0 e1 e2 v0 => f0 e0 f5 ci c pfc t t0 e1 e2 v0 (F e0 v0)
    | Val_New _ _ ci le t f5 => f1 ci le t f5
         (let Q := valid_expr ct gamma in
          let P' := P in
          (fix f_impl (l : list expr) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ e l' Qp Ql' => Forall_cons e (F e Qp) (f_impl l' Ql')
             end) le f5)
    | Val_Invk _ _ e0 m le ci c pfc t v0 f5 t0 e1 e2 => f2 e0 m le ci c pfc t v0 (F e0 v0) f5 
         (let Q := valid_expr ct gamma in
          let P' := P in
          (fix f_impl (l : list expr) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ e l' Qp Ql' => Forall_cons e (F e Qp) (f_impl l' Ql')
             end) le f5) t0 e1 e2
    | Val_Cast _ _ ci e0 t v0 => f3 ci e0 t v0 (F e0 v0)
    | Val_Lib _ _ => f4
    end. *)

Inductive fj_expr : expr -> Prop :=
| FJ_Var : forall x, fj_expr (E_Var x)
| FJ_Field : forall e f, fj_expr e -> fj_expr (E_Field e f)
| FJ_New : forall c le, Forall fj_expr le -> fj_expr (E_New c le)
| FJ_Invk : forall e m le, 
    fj_expr e -> Forall fj_expr le ->
    fj_expr (E_Invk e m le)
| FJ_Cast : forall e d, fj_expr e -> fj_expr (E_Cast d e).
Hint Constructors fj_expr.

Inductive expr_In : var -> expr -> Prop :=
| EIn_Var : forall v, expr_In v (E_Var v)
| EIn_Field : forall v e f, expr_In v e -> expr_In v (E_Field e f)
| EIn_New : forall v le c, Exists (expr_In v) le ->  expr_In v (E_New c le)
| EIn_Invk : forall v e m le, Exists (expr_In v) le \/ expr_In v e -> expr_In v (E_Invk e m le)
| EIn_Cast : forall v e c, expr_In v e -> expr_In v (E_Cast c e).
Hint Constructors expr_In.

Definition T_Method ct c (m : method) : Prop :=
  (exists ei, type_of ct ((This, id_of c) :: params_as_context m) (body m) ei /\
         subtype_id ct ei (ret_type m)) /\
  forall d pfd t, mtype ct (mid m) d pfd = Some t -> t = mtype_of m.
Hint Unfold T_Method.

Definition T_Class ct c : Prop :=
  Forall (T_Method ct c) (dmethods c) /\
  Forall (in_table_id ct) (dfield_typs c).
Hint Unfold T_Class.

Inductive valid_table : class_table -> Prop :=
| VT : forall ct, (forall c, in_table ct c -> valid_class ct c) ->
             (forall c, in_table ct c -> lookup_class ct (id_of c) = Some c) ->
             (forall ci c, lookup_class ct ci = Some c -> ci = id_of c) ->
             (forall ci, ~ (in_lib_id ct ci /\ in_app_id ct ci)) ->
             (forall c pfc c' pfc' fi di di',
                 declaring_class ct c pfc fi = Some di ->
                 declaring_class ct c' pfc' fi = Some di' ->
                 di = di') ->
             (forall c, in_lib ct c -> T_Class (ct_lib ct) c) ->
             (forall c, in_table ct c -> T_Class ct c) ->
             valid_table ct.
Hint Constructors valid_table.

Lemma extends_injective : forall ct c d d',
    valid_class ct c -> extends ct c d -> extends ct c d' -> d = d'.
Proof.
  intros ct c d d' pfc c_ext_d c_ext_d'.
  unfold extends in c_ext_d, c_ext_d'. destruct c as [| ci di k ms fs].
  - inversion c_ext_d.
  - rewrite c_ext_d in c_ext_d'. inversion c_ext_d'. reflexivity.
Qed.
Hint Resolve extends_injective.

Lemma mres_lib_in_lib : forall (ct : class_table) (mi : method_id) (c e : class) (pfc : valid_class ct c),
    in_lib ct c -> mresolve ct mi c pfc = Some e -> in_lib ct e.
  intros ct mi c e pfc c_in_lib c_res_e.
  induction pfc.
  - inversion c_res_e.
  - unfold mresolve in c_res_e. destruct (existsb (beq_nat mi) (dmethods_id c)) in c_res_e.
    + inversion c_res_e. rewrite <- H0. apply c_in_lib.
    + fold mresolve in c_res_e. apply IHpfc.
      * destruct o.
        -- destruct H. apply H.
        -- destruct n. split. apply c_in_lib. destruct H. apply H0.
      * apply c_res_e.
Qed.
Hint Resolve mres_lib_in_lib.

Inductive ave_rel (ct ct' : class_table) : Prop :=
  | AveRel :  valid_table ct -> valid_table ct' ->
              (forall c, in_app ct c <-> in_app ct' c) ->
              (forall c d, (extends ct c d /\ in_table ct' c) <-> extends ct' c d) ->
              (forall d, (exists c, extends ct c d /\ in_lib ct d /\ in_table ct' c) <-> in_lib ct' d) ->
              ave_rel ct ct'.
Hint Constructors ave_rel.
    
Inductive alpha (ct ct' : class_table) (gamma : context) : expr -> expr -> set expr -> Prop :=
| Rel_Field : forall e e' f lpt,
    alpha ct ct' gamma e e' lpt ->
    alpha ct ct' gamma (E_Field e f) (E_Field e' f) lpt
| Rel_Lib_Field : forall e c pfc di f lpt,
    alpha ct ct' gamma e E_Lib lpt ->
    declaring_class ct c pfc f = Some di -> in_lib_id ct di ->
    type_of ct gamma e (id_of c) ->
    alpha ct ct' gamma (E_Field e f) E_Lib lpt
| Rel_New : forall ci le le' lpt,
    in_table_id ct' ci -> length le = length le' ->
    Forall (fun p => alpha ct ct' gamma (fst p) (snd p) lpt) (combine le le') ->
    alpha ct ct' gamma (E_New ci le) (E_New ci le') lpt
| Rel_Lib_New : forall ci le lpt,
    in_lib_id ct ci -> Forall (fun e => alpha ct ct' gamma e E_Lib lpt) le ->
    alpha ct ct' gamma (E_New ci le) E_Lib lpt
| Rel_Invk : forall e e' le le' m lpt,
    alpha ct ct' gamma e e' lpt ->
    length le = length le' ->
    Forall (fun p => alpha ct ct' gamma (fst p) (snd p) lpt) (combine le le') ->
    alpha ct ct' gamma (E_Invk e m le) (E_Invk e' m le') lpt
| Rel_Lib_Invk : forall e le mi lpt,
    (exists c, in_lib ct c /\ In mi (dmethods_id c)) ->
    alpha ct ct' gamma e E_Lib lpt ->
    Forall (fun e' => alpha ct ct' gamma e' E_Lib lpt) le ->
    alpha ct ct' gamma (E_Invk e mi le) E_Lib lpt
| Rel_Cast : forall e e' c lpt,
    alpha ct ct' gamma e e' lpt ->
    alpha ct ct' gamma (E_Cast c e) (E_Cast c e') lpt
| Rel_Lib_Cast : forall e ci lpt,
    alpha ct ct' gamma e E_Lib lpt -> alpha ct ct' gamma (E_Cast ci e) E_Lib lpt
| Rel_Lpt : forall e e' lpt,
    alpha ct ct' gamma e e' lpt -> set_In e' lpt -> alpha ct ct' gamma e E_Lib lpt.
Hint Constructors alpha.

Definition alpha_ind_list :=
  fun (ct ct' : class_table) (gamma : context) (P : expr -> expr -> set expr -> Prop)
    (f : forall (e e' : expr) (f : field_id) (lpt : set expr),
        alpha ct ct' gamma e e' lpt -> P e e' lpt -> P (E_Field e f) (E_Field e' f) lpt)
    (f0 : forall (e : expr) (c : class) (pfc : valid_class ct c) (di : class_id) (f0 : field_id) (lpt : set expr),
        alpha ct ct' gamma e E_Lib lpt ->
        P e E_Lib lpt ->
        declaring_class ct c pfc f0 = Some di ->
        in_lib_id ct di -> type_of ct gamma e (id_of c) -> P (E_Field e f0) E_Lib lpt)
    (f1 : forall (ci : class_id) (le le' : list expr) (lpt : set expr),
        in_table_id ct' ci ->
        length le = length le' ->
        Forall (fun p : expr * expr => alpha ct ct' gamma (fst p) (snd p) lpt) (combine le le') ->
        Forall (fun p : expr * expr => P (fst p) (snd p) lpt) (combine le le') ->
        P (E_New ci le) (E_New ci le') lpt)
    (f2 : forall (ci : class_id) (le : list expr) (lpt : set expr),
        in_lib_id ct ci ->
        Forall (fun e : expr => alpha ct ct' gamma e E_Lib lpt) le ->
        Forall (fun e : expr => P e E_Lib lpt) le ->
        P (E_New ci le) E_Lib lpt)
    (f3 : forall (e e' : expr) (le le' : list expr) (m : method_id) (lpt : set expr),
        alpha ct ct' gamma e e' lpt ->
        P e e' lpt ->
        length le = length le' ->
        Forall (fun p : expr * expr => alpha ct ct' gamma (fst p) (snd p) lpt) (combine le le') ->
        Forall (fun p : expr * expr => P (fst p) (snd p) lpt) (combine le le') ->
        P (E_Invk e m le) (E_Invk e' m le') lpt)
    (f4 : forall (e : expr) (le : list expr) (mi : method_id) (lpt : set expr),
        (exists c : class, in_lib ct c /\ In mi (dmethods_id c)) ->
        alpha ct ct' gamma e E_Lib lpt ->
        P e E_Lib lpt ->
        Forall (fun e' : expr => alpha ct ct' gamma e' E_Lib lpt) le ->
        Forall (fun e : expr => P e E_Lib lpt) le ->
        P (E_Invk e mi le) E_Lib lpt)
    (f5 : forall (e e' : expr) (c : class_id) (lpt : set expr),
        alpha ct ct' gamma e e' lpt -> P e e' lpt -> P (E_Cast c e) (E_Cast c e') lpt)
    (f6 : forall (e : expr) (ci : class_id) (lpt : set expr),
        alpha ct ct' gamma e E_Lib lpt -> P e E_Lib lpt -> P (E_Cast ci e) E_Lib lpt)
    (f7 : forall (e e' : expr) (lpt : set expr),
        alpha ct ct' gamma e e' lpt -> P e e' lpt -> set_In e' lpt -> P e E_Lib lpt) =>
    fix F (e e0 : expr) (s : set expr) (a : alpha ct ct' gamma e e0 s) {struct a} : P e e0 s :=
    match a in (alpha _ _ _ e1 e2 s0) return (P e1 e2 s0) with
    | Rel_Field _ _ _ e1 e' f8 lpt a0 => f e1 e' f8 lpt a0 (F e1 e' lpt a0)
    | Rel_Lib_Field _ _ _ e1 c pfc di f8 lpt a0 e2 i t => f0 e1 c pfc di f8 lpt a0 (F e1 E_Lib lpt a0) e2 i t
    | Rel_New _ _ _ ci le le' lpt i e1 f8 =>
      f1 ci le le' lpt i e1 f8
         (let Q := (fun p => alpha ct ct' gamma (fst p) (snd p) lpt) in
          let P' := (fun p => P (fst p) (snd p) lpt) in
          (fix f_impl (l : list (expr * expr)) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ p l' Qp Ql' => Forall_cons p (F (fst p) (snd p) lpt Qp) (f_impl l' Ql')
             end) (combine le le') f8)
    | Rel_Lib_New _ _ _ ci le lpt i f8 =>
      f2 ci le lpt i f8
         (let Q := (fun e => alpha ct ct' gamma e E_Lib lpt) in
          let P' := (fun e => P e E_Lib lpt) in
          (fix f_impl (l : list expr) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ e l' Qe Ql' => Forall_cons e (F e E_Lib lpt Qe) (f_impl l' Ql')
             end) le f8)
    | Rel_Invk _ _ _ e1 e' le le' m lpt a0 e2 f8 =>
      f3 e1 e' le le' m lpt a0 (F e1 e' lpt a0) e2 f8
         (let Q := (fun p => alpha ct ct' gamma (fst p) (snd p) lpt) in
          let P' := (fun p => P (fst p) (snd p) lpt) in
          (fix f_impl (l : list (expr * expr)) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ p l' Qp Ql' => Forall_cons p (F (fst p) (snd p) lpt Qp) (f_impl l' Ql')
             end) (combine le le') f8)
    | Rel_Lib_Invk _ _ _ e1 le mi lpt e2 a0 f8 =>
      f4 e1 le mi lpt e2 a0 (F e1 E_Lib lpt a0) f8
         (let Q := (fun e => alpha ct ct' gamma e E_Lib lpt) in
          let P' := (fun e => P e E_Lib lpt) in
          (fix f_impl (l : list expr) (F_Q : Forall Q l) : Forall P' l :=
             match F_Q with
             | Forall_nil _ => Forall_nil P'
             | @Forall_cons _ _ e l' Qe Ql' => Forall_cons e (F e E_Lib lpt Qe) (f_impl l' Ql')
             end) le f8)
    | Rel_Cast _ _ _ e1 e' c lpt a0 => f5 e1 e' c lpt a0 (F e1 e' lpt a0)
    | Rel_Lib_Cast _ _ _ e1 ci lpt a0 => f6 e1 ci lpt a0 (F e1 E_Lib lpt a0)
    | Rel_Lpt _ _ _ e1 e' lpt a0 s0 => f7 e1 e' lpt a0 (F e1 e' lpt a0) s0
    end.

Definition subst := list (var * expr).

Fixpoint do_sub (sig : subst) (e : expr) : expr :=
  match e with
  | E_Var v => match find (fun p => beq_var (fst p) v) sig with
              | Some (_, e') => e'
              | None => e
              end
  | E_Field e' f => E_Field (do_sub sig e') f
  | E_New c es => E_New c (map (do_sub sig) es)
  | E_Invk e' m es => E_Invk (do_sub sig e') m (map (do_sub sig) es)
  | E_Cast c e' => E_Cast c (do_sub sig e')
  | E_Lib => E_Lib
  end.
Hint Unfold do_sub.

Definition valid_sub (ct : class_table) (gamma : context) (sig : subst) : Prop :=
  Forall (fun p => exists ci, lookup_context gamma (fst p) = Some ci /\ type_of ct gamma (snd p) ci) sig.
Hint Unfold valid_sub.

Inductive calPexpr (ct' : class_table) (gamma : context) : expr -> Prop :=
| P_Var : forall v, calPexpr ct' gamma (E_Var v)
| P_Field : forall e fi c pfc' di,
    calPexpr ct' gamma e -> declaring_class ct' c pfc' fi = Some di ->
    calPexpr ct' gamma (E_Field e fi)
| P_Invk : forall e mi le c pfc' di,
    calPexpr ct' gamma e -> Forall (calPexpr ct' gamma) le -> mresolve ct' mi c pfc' = Some di ->
    calPexpr ct' gamma (E_Invk e mi le)
| P_New : forall le ci,
    Forall (calPexpr ct' gamma) le -> in_table_id ct' ci ->
    calPexpr ct' gamma (E_New ci le)
| P_Cast : forall e ci,
    calPexpr ct' gamma e -> in_table_id ct' ci ->
    calPexpr ct' gamma (E_Cast ci e)
| P_Lib : calPexpr ct' gamma E_Lib.
Hint Constructors calPexpr.

Definition calP ct' gamma e lpt :=
  calPexpr ct' gamma e /\ (forall e0, set_In e0 lpt -> calPexpr ct' gamma e0).
Hint Unfold calP.

(* Lemmas *)

Lemma not_lib_app : forall (ct : class_table) (c : class) (pfc : valid_class ct c),
    ~ (in_lib ct c /\ in_app ct c).
Proof.
  intros ct c pfc. inversion pfc; trivial.
  unfold not. intros [_ in_app]. contradiction.
Qed.
Hint Resolve not_lib_app.

Lemma eq_valid : forall (ct : class_table) (c d : class) (pfc : valid_class ct c),
    c = d -> valid_class ct d.
Proof.
  intros ct c d pfc cdeq.
  destruct pfc.
  - rewrite <- cdeq. apply ValidObj; trivial. 
  - apply ValidParent with d0; try rewrite <- cdeq; trivial.
Qed.
Hint Resolve eq_valid.

Lemma valid_in_table : forall (ct : class_table) (c : class) (pfc : valid_class ct c),
    in_table ct c.
Proof.
  intros ct c pfc. inversion pfc.
  - apply in_lib_in_table. apply H.
  - destruct H2.
    * apply H2.
    * apply in_app_in_table. apply H2.
Qed.
Hint Resolve valid_in_table.

Lemma id_eq : forall (ct : class_table) c d (pfc : valid_class ct c) (pfd : valid_class ct d),
    valid_table ct -> id_of c = id_of d -> c = d.
Proof.
  intros ct c d pfc pfd pft eq_id. destruct pft as [ct _ look_id _].
  apply valid_in_table in pfc. apply valid_in_table in pfd.
  apply look_id in pfc. apply look_id in pfd.
  rewrite eq_id in pfc. rewrite pfd in pfc. inversion pfc. reflexivity.
Qed.
Hint Resolve id_eq.

Lemma in_ct_lib_in_lib : forall (ct : class_table) (c : class),
    in_table (ct_lib ct) c -> in_lib ct c.
Proof.
  intros ct c in_ct_lib.
  unfold ct_lib, in_table in in_ct_lib; unfold in_lib; destruct ct.
  destruct in_ct_lib.
  - unfold in_app in H. unfold empty_map in H. inversion H.
  - unfold in_lib in H. apply H.
Qed.
Hint Resolve in_ct_lib_in_lib.

Lemma in_ct_lib_in_lib_id : forall (ct : class_table) (ci : class_id),
    in_table_id (ct_lib ct) ci -> in_lib_id ct ci.
Proof.
  intros ct c in_ct_lib_id.
  unfold ct_lib, in_table_id in in_ct_lib_id; unfold in_lib_id; destruct ct.
  destruct in_ct_lib_id.
  - unfold in_app_id in H. unfold empty_map in H. destruct H. inversion H.
  - unfold in_lib_id in H. apply H.
Qed.
Hint Resolve in_ct_lib_in_lib_id.

Lemma valid_obj_Valid_Obj : forall ct (pfc : valid_class ct Obj), exists h1 h2,
      pfc = ValidObj ct h1 h2.
Proof.
  intros ct pfc. dependent destruction pfc.
  - exists i, n. reflexivity.
  - inversion e.
Qed.
Hint Resolve valid_obj_Valid_Obj.

Lemma ext_in_lib_ext_in_ct :
  forall (ct : class_table) (pft : valid_table ct) (c d : class) (pfd : valid_class ct d),
    extends (ct_lib ct) c d -> extends ct c d.
Proof.
  intros ct pft c d pfd ext_in_lib.
  destruct c.
  - inversion ext_in_lib.
  - simpl. simpl in ext_in_lib.
    assert (c0 = id_of d).
    { inversion pft. apply H1. destruct ct as [app lib]. simpl. destruct (app c0) eqn:appc0; try assumption.
      destruct (H2 c0). split; simpl. exists d. assumption. exists c2. assumption. }
    subst. inversion pft. apply H0. apply valid_in_table. assumption.
Qed.
Hint Resolve ext_in_lib_ext_in_ct.

Lemma ext_in_lib_ext_in_ct_id :
  forall (ct : class_table) (pft : valid_table ct) (ci di : class_id),
    in_table_id ct ci -> extends_id (ct_lib ct) ci di -> extends_id ct ci di.
Proof.
  intros _ [[app lib] _ _ _ nlai] ci di ci_in_ct ext_in_lib.
  unfold extends_id. simpl. unfold extends_id in ext_in_lib. simpl in ext_in_lib.
  destruct (app ci) eqn:appci; trivial.
  destruct (lib ci) eqn:libci; try solve [inversion ext_in_lib].
  simpl in nlai. specialize (nlai ci). destruct nlai. split.
  - exists c0. assumption.
  - exists c. assumption.
Qed.
Hint Resolve ext_in_lib_ext_in_ct_id.

Lemma valid_in_lib_in_lib : forall ct c (pfc : valid_class (ct_lib ct) c),
    in_lib ct c.
Proof.
  intros ct c pfc.
  destruct ct as [app lib]. simpl.
  apply valid_in_table in pfc. unfold in_table in pfc. destruct pfc.
  - simpl in H. unfold empty_map in H. inversion H.
  - simpl in H. trivial.
Qed.
Hint Resolve valid_in_lib_in_lib.

Lemma decl_in_lib_in_lib : forall ct c (pfc : valid_class (ct_lib ct) c) fi di,
    declaring_class (ct_lib ct) c pfc fi = Some di -> in_lib_id ct di.
Proof.
  intros ct c pfc fi di decl_in_lib.
  remember pfc as pfc'.
  induction pfc'.
  - simpl in decl_in_lib. inversion decl_in_lib.
  - simpl in decl_in_lib. destruct (@existsb field_id (beq_nat fi) (dfield_ids c)).
    + inversion decl_in_lib. destruct ct as [app lib]. simpl. clear Heqpfc'.
      apply valid_in_lib_in_lib in pfc. simpl in pfc. exists c. trivial.
    + apply IHpfc' with pfc'. trivial. trivial.
Qed.
Hint Resolve decl_in_lib_in_lib.

Lemma supertype_valid : forall (ct : class_table) (c d : class) (pfc : valid_class ct c),
    subtype ct c d -> valid_class ct d.
Proof.
  intros ct c d pfc subtyp. induction subtyp.
  - eauto. 
  - eauto. 
  - inversion pfc.
    + subst. inversion e.
    + replace d with d0; eauto.
Qed.
Hint Resolve supertype_valid.

Lemma supertype_lib_in_lib : forall (ct : class_table) (c d : class) (pfc : valid_class ct c), 
    subtype ct c d -> in_lib ct c -> in_lib ct d.
Proof.
  intros ct c d pfc subtyp c_in_lib. induction subtyp.
  - apply c_in_lib.
  - apply IHsubtyp2.
    apply supertype_valid with (c := c). eauto. eauto.
    apply IHsubtyp1. eauto. eauto.
  - inversion pfc. 
    + subst. inversion e.
    + assert (d = d0) by eauto.
      destruct H2; decomp; subst. eauto.
      destruct H1; eauto.
Qed.
Hint Resolve supertype_lib_in_lib.

Lemma lib_par_same : forall ct (pft : valid_table ct) c d pfc_l pfd_l ext nla sca pfc,
    pfc_l = ValidParent (ct_lib ct) c d pfd_l ext nla sca ->
    exists ext' nla' sca' pfd, pfc = ValidParent ct c d pfd ext' nla' sca'.
Proof.
  intros. remember pfc as pfc'. destruct pfc.
  - inversion ext.
  - assert (d = d0); try subst d.
    { apply extends_injective with ct c; trivial. inversion pft. eauto. }
    split_rec 4; eauto.
Qed.
Hint Resolve lib_par_same.

Lemma simul_induct_lib :
  forall (ct : class_table) (pft : valid_table ct) (P : forall ct c, valid_class (ct_lib ct) c -> valid_class ct c -> Prop),
    (forall o1 o2 o1' o2', P ct Obj (ValidObj (ct_lib ct) o1 o2) (ValidObj ct o1' o2')) ->
    (forall c d pfd_l pfd ext nla sca ext' nla' sca',
        P ct d pfd_l pfd ->
        P ct c (ValidParent (ct_lib ct) c d pfd_l ext nla sca) (ValidParent ct c d pfd ext' nla' sca')) ->
    forall c pfc_l pfc, P ct c pfc_l pfc.
Proof. 
  intros ct pft P Hobj Hind c pfc_l. 
  remember pfc_l as pfc_lr. induction pfc_l.
  - intros. assert (exists h1 h2, pfc = ValidObj ct h1 h2). apply valid_obj_Valid_Obj.
    destruct H as [x [y id]]. rewrite id. rewrite Heqpfc_lr. apply Hobj.
  - intros. assert (exists ext' nla' sca' pfd, pfc = ValidParent ct c d pfd ext' nla' sca').
    { apply lib_par_same with pfc_lr pfc_l e n o; trivial. }
    destruct H as [ext' [nla' [sca' [pfd H']]]].
    rewrite H'. rewrite Heqpfc_lr. apply Hind. apply IHpfc_l. trivial.
Qed.

Lemma rel_par_same : forall ct ct' (rel : ave_rel ct ct') c d pfc pfd ext nla sca pfc',
    pfc = ValidParent ct c d pfd ext nla sca ->
    exists ext' nla' sca' pfd', pfc' = ValidParent ct' c d pfd' ext' nla' sca'.
Proof.
  intros. remember pfc' as pfc''. inversion rel as [val_ct val_ct' keep_app keep_ext keep_lib]. destruct pfc'.
  - inversion ext.
  - assert (d = d0) as deq.
    { apply extends_injective with ct' c.
      - trivial.
      - apply keep_ext. split.
        + assumption.
        + destruct o.
          * apply a.
          * apply in_app_in_table. apply a.
      - trivial. }
    rewrite deq.
    split_rec 4; eauto.
Qed.
Hint Resolve rel_par_same.

Lemma simul_induct :
  forall (ct ct' : class_table) (rel : ave_rel ct ct') 
    (P : forall ct ct' rel c, valid_class ct c -> valid_class ct' c -> Prop),
    (forall o1 o2 o1' o2', P ct ct' rel Obj (ValidObj ct o1 o2) (ValidObj ct' o1' o2')) ->
    (forall c d pfd pfd' ext nla sca ext' nla' sca',
        P ct ct' rel d pfd pfd' ->
        P ct ct' rel c (ValidParent ct c d pfd ext nla sca) (ValidParent ct' c d pfd' ext' nla' sca')) ->
    forall c pfc pfc', P ct ct' rel c pfc pfc'.
Proof. 
  intros ct ct' rel P Hobj Hind c pfc. inversion rel as [val_ct val_ct' keep_app keep_ext keep_lib].
  remember pfc as pfc_r. induction pfc.
  - intros. assert (exists h1 h2, pfc' = ValidObj ct' h1 h2). apply valid_obj_Valid_Obj.
    destruct H as [x [y id]]. rewrite id. rewrite Heqpfc_r. apply Hobj.
  - intros. assert (exists ext' nla' sca' pfd, pfc' = ValidParent ct' c d pfd ext' nla' sca').
    { apply rel_par_same with ct pfc_r pfc e n o.
      - trivial.
      - trivial. }
    destruct H as [ext' [nla' [sca' [pfd' H']]]].
    rewrite H'. rewrite Heqpfc_r. apply Hind. apply IHpfc. trivial.
Qed.

Lemma val_in_lib_val_in_ct :
  forall (ct : class_table) (c : class) (pfc : valid_class (ct_lib ct) c),
    (forall c, in_table ct c -> valid_class ct c) -> valid_class ct c.
Proof.
  intros ct c pfc H.
  apply H. apply in_lib_in_table. apply valid_in_lib_in_lib. trivial.
Qed.
Hint Resolve val_in_lib_val_in_ct.

Lemma fields_in_lib_fields_in_ct :
  forall (ct : class_table) (pft : valid_table ct) (c : class) (pfc_l : valid_class (ct_lib ct) c) (pfc : valid_class ct c),
    fields pfc_l = fields pfc.
Proof.
  intros ct pft c pfc_l pfc.
  apply simul_induct_lib with (ct := ct) (c := c) (pfc_l := pfc_l) (pfc := pfc); trivial.
  intros. simpl. destruct c0; trivial.
  rewrite H. trivial.
Qed.
Hint Resolve fields_in_lib_fields_in_ct.

Lemma fields_in_lib_fields_in_ct_id :
  forall (ct : class_table) (pft : valid_table ct) (c : class) (pfc_l : valid_class (ct_lib ct) c) (pfc : valid_class ct c),
    field_ids pfc_l = field_ids pfc.
Proof. intros. unfold field_ids. erewrite fields_in_lib_fields_in_ct; eauto. Qed.
Hint Resolve fields_in_lib_fields_in_ct_id.

Lemma mtype_in_lib_mtype_in_ct :
  forall (ct : class_table) (pft : valid_table ct) (c : class) (pfc_l : valid_class (ct_lib ct) c) (pfc : valid_class ct c) mi,
    mtype (ct_lib ct) mi c pfc_l = mtype ct mi c pfc.
Proof.
  intros ct pft c pfc_l pfc mi.
  apply simul_induct_lib with (ct := ct) (c := c) (pfc_l := pfc_l) (pfc := pfc); trivial.
  intros. simpl. destruct (lookup_method c0 mi); trivial.
Qed.
Hint Resolve mtype_in_lib_mtype_in_ct.

Lemma subtyp_id_lib_subtyp_id_ct : forall (ct : class_table) (ci : class_id) (di : class_id),
    valid_table ct -> subtype_id (ct_lib ct) ci di -> subtype_id ct ci di.
Proof.
  intros ct ci di pft subtyp_id_lib.
  induction subtyp_id_lib; eauto.
  - apply SI_Sub. apply ext_in_lib_ext_in_ct_id; eauto. apply in_lib_in_table_id. destruct ct as [app lib].
    simpl in H. simpl. unfold extends_id in H. destruct (lookup_class (empty_map, lib) ci) eqn:look; try inversion H.
    simpl in look. exists c. trivial. 
Qed.
Hint Resolve subtyp_id_lib_subtyp_id_ct.

Lemma typ_in_lib_typ_in_ct :
  forall (ct : class_table) (pft : valid_table ct) (gamma : context) (e : expr) (ci : class_id),
    type_of (ct_lib ct) gamma e ci -> type_of ct gamma e ci.
Proof.
  intros ct pft gamma e ci typ_in_lib.
  induction typ_in_lib using type_of_ind_list; eauto; inversion pft;
    try assert (valid_class ct c) as pfc' by eauto; subst.
  - eapply T_Field with (pfc := pfc'); eauto.
    unfold lookup_field. erewrite <- fields_in_lib_fields_in_ct; eauto.
  - eapply T_New with (pfc := pfc'); eauto; erewrite <- fields_in_lib_fields_in_ct_id; eauto.
    eapply Forall_impl; try eassumption; eauto.
  - eapply T_Invk with (pfc := pfc'); eauto.
    * erewrite <- mtype_in_lib_mtype_in_ct; eauto.
    * eapply Forall_impl; try eassumption; eauto.
Qed.
Hint Resolve typ_in_lib_typ_in_ct.

Lemma decl_in_lib_decl_in_ct :
  forall (ct : class_table) (pft : valid_table ct) (c : class) (pfc : valid_class ct c) (pfc_l : valid_class (ct_lib ct) c) fi,
    declaring_class (ct_lib ct) c pfc_l fi = declaring_class ct c pfc fi.
  intros ct pft c pfc pfc_l.
  apply simul_induct_lib with (ct := ct) (c := c) (pfc_l := pfc_l) (pfc := pfc); trivial.
  clear c pfc pfc_l. intros c d pfd_l pfd ext nla sca ext' nla' sca' IHd fi.
  simpl. destruct (@existsb field_id (beq_nat fi) (dfield_ids c)); trivial.
Qed.
Hint Resolve decl_in_lib_decl_in_ct.

Lemma mresolve_lib_ct :
  forall ct (pft : valid_table ct) c (pfc_l : valid_class (ct_lib ct) c) (pfc : valid_class ct c) mi,
    mresolve (ct_lib ct) mi c pfc_l = mresolve ct mi c pfc.
Proof.
  intros ct pft c pfc_l pfc.
  apply simul_induct_lib with (ct := ct) (c := c) (pfc_l := pfc_l) (pfc := pfc); trivial.
  clear c pfc pfc_l. intros c d pfd_l pfd ext nla sca ext' nla' sca' IHd mi.
  simpl. destruct (existsb (beq_nat mi) (dmethods_id c)); trivial.
Qed.
Hint Resolve mresolve_lib_ct.

Lemma invk_valid_in_lib_m_in_lib : forall (ct : class_table) e le mi (gamma : context),
    type_checks (ct_lib ct) gamma (E_Invk e mi le) -> exists c, in_lib ct c /\ In mi (dmethods_id c).
Proof.
  intros ct e le mi gamma [et typ_et].
  inversion typ_et; subst. clear typ_et H2. remember pfc as pfc'. induction pfc; subst; try discriminate.
  simpl in H3. destruct (lookup_method c mi) eqn:exstb; eauto.
  + exists c. split; [eauto|]. unfold lookup_method in exstb. destruct c; try discriminate.
    apply find_some in exstb. unfold dmethods_id. destruct m. decomp.
    rewrite beq_nat_true_iff in H0. subst m. apply in_map_iff.
    eexists; split; try eassumption. reflexivity.
Qed.
Hint Resolve invk_valid_in_lib_m_in_lib.

Lemma find_In_var : forall lv v,
    In v lv <-> find (fun v' => beq_var v' v) lv <> None.
Proof.
  split; induction lv; intros; eauto; simpl; simpl in H.
  - destruct H.
    + rewrite H. rewrite <- beq_var_refl. unfold not. intro. inversion H0.
    + destruct (beq_var a v); eauto. unfold not. intro. inversion H0.
  - apply H. reflexivity.
  - destruct (beq_var a v) eqn:beq_av.
    + left. apply beq_var_true. eauto.
    + right. apply IHlv. trivial.
Qed.
Hint Resolve find_In_var.

Lemma type_checks_lib_ct : forall (ct : class_table) (gamma : context) (e : expr),
    valid_table ct -> type_checks (ct_lib ct) gamma e -> type_checks ct gamma e.
Proof.
  intros ct gamma e pft typ_lib. 
  induction e using expr_ind_list; destruct typ_lib as [ei Hei]; inversion Hei; econstructor; eauto; subst.
Qed.
Hint Resolve type_checks_lib_ct.

Lemma valid_class_irrelevance :
  forall ct c (pfc : valid_class ct c) (pfc' : valid_class ct c),
    pfc = pfc'.
Proof.
  intros. generalize dependent pfc'. induction pfc.
  - intros. assert (exists i' n', pfc' = ValidObj ct i' n') by (apply valid_obj_Valid_Obj; trivial).
    destruct H as [i' [n' Heqpfc']]. subst.
    replace i' with i by apply proof_irrelevance. replace n' with n by apply proof_irrelevance.
    reflexivity.
  - intros. destruct pfc' eqn:Heqpfc'; try inversion e.
    assert (d = d0) by (apply extends_injective with ct c; eauto). subst d0.
    replace e0 with e by apply proof_irrelevance.
    replace n0 with n by apply proof_irrelevance.
    replace o0 with o by apply proof_irrelevance.
    replace v with pfc by apply IHpfc. reflexivity.
Qed.
Hint Resolve valid_class_irrelevance.

Lemma type_of_fn : forall ct gamma e ci di,
    valid_table ct -> fj_expr e -> type_of ct gamma e ci -> type_of ct gamma e di -> ci = di.
Proof with subst; eauto.
  intros ct gamma e ci di pft fj_e tci. generalize dependent di.
  induction tci; intros di0 tdi0; inversion tdi0; inversion fj_e; subst_some; subst; eauto.
  assert (c = c0)... assert (pfc = pfc0)... subst_some. reflexivity.
Qed.
Hint Resolve type_of_fn.

Ltac invert_id x :=
  match goal with
  | [ H : x _ |- _ ] => inversion H
  | _ => idtac
  end.

Lemma lookup_field_in_table : forall ct c (pfc : valid_class ct c) fi di,
    valid_table ct -> lookup_field pfc fi = Some di -> in_table_id ct di.
Proof.
  intros ct c pfc.
  induction pfc; intros; try discriminate.
  unfold lookup_field in *. simpl in *.
  destruct (find (fun p => PeanoNat.Nat.eqb fi (snd p)) (dfields c ++ fields pfc)) eqn:find_f; try discriminate.
  apply find_app in find_f. destruct find_f; eauto.
  - invert_id valid_table. assert (in_table ct c) by eauto.
    destruct (H8 c H10) as [_ dfields_in_table].
    unfold dfield_ids in dfields_in_table.
    simpl in *. subst_some.
    unfold dfield_typs in *.
    eapply Forall_In; try eassumption. apply in_map.
    apply find_some in H1. decomp. eauto.
  - eapply IHpfc; eauto. rewrite <- H1 in H0. eassumption.
Qed.
Hint Resolve lookup_field_in_table.

Lemma decl_of_lib_in_lib : forall ct c pfc d fi,
    valid_table ct -> in_lib ct c -> declaring_class ct c pfc fi = Some d -> in_lib_id ct d.
Proof.
  intros ct c pfc d fi pft c_in_lib decl.
  induction pfc.
  - inversion decl.
  - simpl in decl.
    destruct (@existsb field_id (beq_nat fi) (dfield_ids c)).
    + inversion decl. subst. destruct ct as [app lib]. simpl. exists c. apply c_in_lib.
    + destruct o as [[par_app ch_app] | [ch_tab par_lib]].
      * apply IHpfc; trivial.
      * destruct n. split; trivial.
Qed.
Hint Resolve decl_of_lib_in_lib.

Lemma type_of_in_table : forall ct gamma e ci,
    valid_table ct -> type_of ct gamma e ci -> in_table_id ct ci.
Proof. intros ct gamma e ci val_ct typ_e_ci. induction typ_e_ci; eauto. Qed.
Hint Resolve type_of_in_table.

Lemma do_valid_sub_keep_type : forall ct gamma sig e ci,
    valid_table ct -> valid_sub ct gamma sig ->
    Forall (fun p => fj_expr (snd p)) sig ->
    (type_of ct gamma e ci <-> type_of ct gamma (do_sub sig e) ci).
Proof with subst; eauto.
  intros ct gamma sig e ci pft val_sub fj_expr_sub.
  generalize dependent ci. induction e using expr_ind_list; intros; simpl.
  - destruct (find (fun p : var * expr => beq_var (fst p) v) sig)eqn:findp.
    + destruct p. apply find_some in findp. unfold valid_sub in val_sub.
      destruct findp. simpl in *. assert (v0 = v) by (apply beq_var_true; eauto). subst v0.
      eapply Forall_In in val_sub... simpl in *.
      destruct val_sub as [ci' [lookup_ci' type_of_ci']].
      split; intros G.
      * inversion G. subst_some. assumption.
      * econstructor. rewrite type_of_fn with ct gamma e ci ci'...
        ++ replace e with (snd (v, e)) by reflexivity.
           eapply Forall_In with (P := fun p => fj_expr (snd p)); eauto.
        ++ eapply type_of_in_table...
    + reflexivity.
  - split; intros; inversion H; apply T_Field with c pfc; trivial; apply IHe; trivial.
  - split; intros; inversion H0; subst; apply T_New with pfc lc;
      try rewrite map_length; trivial; try rewrite <- (map_length (do_sub sig)); trivial;
        apply Forall_add_combine with (lb := lc) in H.
    + rewrite combine_map_l. apply Forall_map_swap. simpl.
      eapply Forall_list_impl; try eassumption. simpl.
      eapply Forall_impl; [intros a P; eapply iff_and in P|]; try eassumption.
      destruct P; eauto.
    + apply Forall_list_impl with (P := fun p => (fun p => type_of ct gamma (fst p) (snd p))
                                                ((fun p => (do_sub sig (fst p), snd p)) p)).
      * apply Forall_map_swap with (P := fun p => type_of ct gamma (fst p) (snd p)).
        rewrite <- combine_map_l. assumption.
      * simpl. eapply Forall_impl; [intros a P; eapply iff_and in P|]; try eassumption.
        destruct P; eauto.
  - split; intros; inversion H0; subst; apply T_Invk with pfc ld ret lc; eauto;
      try solve [apply IHe; trivial]; try rewrite map_length; trivial;
        try rewrite <- (map_length (do_sub sig)); trivial;
          apply Forall_add_combine with (lb := lc) in H.
    + rewrite combine_map_l. apply Forall_map_swap. simpl.
      eapply Forall_list_impl; try eassumption. simpl.
      eapply Forall_impl; [intros a P; eapply iff_and in P|]; try eassumption.
      destruct P; eauto.
    + apply Forall_list_impl with (P := fun p => (fun p => type_of ct gamma (fst p) (snd p))
                                                ((fun p => (do_sub sig (fst p), snd p)) p)).
      * apply Forall_map_swap with (P := fun p => type_of ct gamma (fst p) (snd p)).
        rewrite <- combine_map_l. assumption.
      * simpl. eapply Forall_impl; [intros a P; eapply iff_and in P|]; try eassumption.
        destruct P; eauto.
  - split; intros; inversion H; apply T_Cast with di; trivial; apply IHe; trivial.
  - reflexivity.
Qed.
Hint Resolve do_valid_sub_keep_type.

Lemma mresolve_in_methods : forall ct c pfc d mi,
    mresolve ct mi c pfc = Some d -> In mi (dmethods_id d).
Proof.
  intros. induction pfc.
  - inversion H.
  - simpl in H.
    destruct (existsb (beq_nat mi) (dmethods_id c)) eqn:exst; eauto.
    inversion H. subst. rewrite existsb_exists in exst. destruct exst as [x [in_eqb]].
    apply beq_nat_true in H0. rewrite H0. trivial.
Qed.
Hint Resolve mresolve_in_methods.

Lemma lookup_field_declaring_class : forall ct c pfc fi,
    (exists ei, lookup_field pfc fi = Some ei) <-> (exists ei, declaring_class ct c pfc fi = Some ei).
Proof.
  intros.
  induction pfc; split; intros; destruct H as [ei Hei]; try discriminate;
    unfold lookup_field in *; simpl in *;
      destruct (@existsb field_id (beq_nat fi) (dfield_ids c)) eqn:exstb;
      try solve [eexists; trivial].
  - destruct (find (fun p => beq_nat fi (snd p)) (dfields c ++ fields pfc)) eqn:find_fi; try discriminate.
    apply find_app in find_fi. destruct find_fi.
    + contradict exstb. apply Bool.not_false_iff_true.
      apply existsb_find. eexists. unfold dfield_ids.
      erewrite (@find_map (class_id * nat) nat (@snd class_id nat)). rewrite H.
      reflexivity.
    + apply IHpfc. eexists. rewrite H. reflexivity.
  - destruct (find (fun p => beq_nat fi (snd p)) (dfields c ++ fields pfc)) eqn:find_fi; try discriminate.
    + destruct p. eexists. reflexivity.
    + contradict exstb. eapply not_iff. apply existsb_find. apply not_exists_some_iff_none.
      apply not_find_app in find_fi. unfold dfield_ids. rewrite find_map. apply option_map_None.
      apply find_fi.
  - 

Lemma valid_table_valid_lib : forall ct,
    valid_table ct -> valid_table (ct_lib ct).
Proof.
  intros ct pft. inversion pft. subst.
  apply VT.
  - intros.
    assert (valid_class ct c) as pfc.
    { apply H. apply in_lib_in_table. apply in_ct_lib_in_lib. trivial. }
    destruct ct as [app lib]. induction pfc.
    + apply ValidObj; trivial; discriminate.
    + apply ValidParent with d.
      * apply IHpfc. unfold in_table. simpl. right. inversion pfc; trivial.
        destruct o as [[don _] | [_ con]]; trivial.
        destruct n. split; trivial. apply in_ct_lib_in_lib. trivial.
      * destruct c; trivial.
        simpl. simpl in e. destruct (app c0) eqn:appc0; trivial.
        inversion e. subst c2. clear e. destruct o as [[d_in_lib c_in_table] | [d_in_app c_in_app]].
        -- destruct (not_lib_app (app, lib) d pfc). split. apply d_in_lib.
           assert (lookup_class (app, lib) c0 = app c0).
           { simpl. rewrite appc0. reflexivity. }
           assert (c0 = id_of d); subst; trivial.
           apply H1. rewrite <- appc0. assumption.
        -- simpl in H3. unfold in_table in H3. destruct H6.
           ++ unfold empty_map in H3. inversion H6.
           ++ destruct n. split; eauto.  
      * simpl. intro. decomp. discriminate.
      * left. split; trivial.
        destruct o; decomp; eauto.
        destruct n; split; eauto. 
  - destruct ct as [app lib]. intros. simpl.
    assert (in_table (app, lib) c) as c_in_table. apply in_lib_in_table. apply in_ct_lib_in_lib; trivial.
    apply H0 in c_in_table as lookc. simpl in lookc. destruct (app (id_of c)) eqn:appcid; trivial.
    inversion lookc. subst c0. apply H in c_in_table as pfc.
    destruct (not_lib_app (app, lib) c pfc).
    split; trivial. apply in_ct_lib_in_lib; trivial.
  - intros. destruct ct as [app lib].
    simpl in H2. apply H1. simpl. destruct (app ci) eqn:appci; eauto.
    remember appci as appci'. clear Heqappci'.
    replace (app ci) with (lookup_class (app, lib) ci) in appci'; simpl; try rewrite appci; try reflexivity.
    rename appci' into lookci. 
    apply H1 in lookci; trivial. subst ci.
    assert (valid_class (app, lib) c0) as pfc0. apply H. apply in_app_in_table. apply appci.
    destruct (H2 (id_of c0)). split.
    + eexists; eassumption.
    + eexists; eassumption.
  - destruct ct as [app lib]. simpl. unfold not. intros ci [_ [c contra]]. inversion contra.
  - intros c pfc_l c' pfc_l' fi di di' decl_c decl_c'.
    assert (valid_class ct c) as pfc.
    { apply H. apply in_lib_in_table. apply in_ct_lib_in_lib. apply valid_in_table. assumption. }
    assert (valid_class ct c') as pfc'.
    { apply H. apply in_lib_in_table. apply in_ct_lib_in_lib. apply valid_in_table. assumption. }
    rewrite decl_in_lib_decl_in_ct with (pfc := pfc) in decl_c; try assumption.
    rewrite decl_in_lib_decl_in_ct with (pfc := pfc') in decl_c'; try assumption.
    apply H3 with c pfc c' pfc' fi; assumption.
  - intros. destruct ct. eauto.
  - intros. destruct ct. eauto.
Qed.
Hint Resolve valid_table_valid_lib.

Lemma decl_index_of : forall ct c pfc fi d (pfd : valid_class ct d),
    declaring_class ct c pfc fi = Some (id_of d) ->
    exists n, index_of (beq_nat fi) (field_ids pfc) = Some n.
Proof.
  intros. induction pfc; try discriminate.
  simpl in *. unfold field_ids. simpl.
  destruct (@existsb field_id (beq_nat fi) (dfield_ids c)) eqn:exstb;
    unfold dfield_ids in *; apply index_of_existsb; rewrite map_app, existsb_app, exstb;
      try apply index_of_existsb; auto.
Qed.
Hint Resolve decl_index_of.

Inductive FJ_reduce (ct : class_table) : expr -> expr -> Prop :=
| R_Field : forall c (pfc : valid_class ct c) fi le ei n,
    index_of (beq_nat fi) (field_ids pfc) = Some n ->
    nth_error le n = Some ei ->
    FJ_reduce ct (E_Field (E_New (id_of c) le) fi) ei
| R_Invk : forall c (pfc : valid_class ct c) m mi le newle,
    find_method mi pfc = Some m ->
    FJ_reduce ct (E_Invk (E_New (id_of c) newle) mi le)
              (do_sub ((This, (E_New (id_of c) newle)) :: (combine (param_names m) le)) (body m))
| R_Cast : forall c d le,
    subtype ct c d -> FJ_reduce ct (E_Cast (id_of d) (E_New (id_of c) le)) (E_New (id_of c) le)
| RC_Field : forall e e' f,
    FJ_reduce ct e e' -> FJ_reduce ct (E_Field e f) (E_Field e' f)
| RC_Invk_Recv : forall e e' m le,
    FJ_reduce ct e e' -> FJ_reduce ct (E_Invk e m le) (E_Invk e' m le)
| RC_Invk_Arg : forall e m le le' e0 e0' n,
    nth_error le n = Some e0 -> nth_error le' n = Some e0' ->
    FJ_reduce ct e0 e0' -> FJ_reduce ct (E_Invk e m le) (E_Invk e m le')
| RC_New_Arg : forall c le le' e0 e0' n,
    nth_error le n = Some e0 -> nth_error le' n = Some e0' ->
    FJ_reduce ct e0 e0' -> FJ_reduce ct (E_New c le) (E_New c le')
| RC_Cast : forall c e e',
    FJ_reduce ct e e' -> FJ_reduce ct (E_Cast c e) (E_Cast c e').
Hint Constructors FJ_reduce.

Inductive FJ_reduce' (ct : class_table) : expr -> expr -> Prop :=
| R'_refl : forall e, FJ_reduce' ct e e
| R'_step : forall e e' e'',
    FJ_reduce ct e e' ->
    FJ_reduce' ct e' e'' ->
    FJ_reduce' ct e e''.
Hint Constructors FJ_reduce'.

Inductive AVE_reduce (ct : class_table) : expr -> set expr -> expr -> set expr -> Prop :=
| RA_FJ : forall e e' lpt,
    FJ_reduce ct e e' -> AVE_reduce ct e lpt e' lpt
| RA_Field : forall f c pfc di e lpt,
    declaring_class ct c pfc f = Some di -> in_lib_id ct di ->
    AVE_reduce ct e lpt e (add (E_Field E_Lib f) lpt)
| RA_New : forall c (pfc : valid_class ct c) e lpt,
    in_lib ct c ->
    AVE_reduce ct e lpt e (add (E_New (id_of c) (repeat E_Lib (length (fields pfc)))) lpt)
| RA_Invk : forall m c e lpt,
    In m (dmethods c) -> in_lib ct c ->
    AVE_reduce ct e lpt e (add (E_Invk E_Lib (mid m) (repeat E_Lib (length (param_names m)))) lpt)
| RA_Cast : forall c lpt, AVE_reduce ct (E_Cast c E_Lib) lpt E_Lib lpt
| RA_Lib_Invk : forall mi c pfc newle largs d lpt,
    mresolve ct mi c pfc = Some d -> in_lib ct d ->
    AVE_reduce ct
               (E_Invk (E_New (id_of c) newle) mi largs)
               lpt
               E_Lib
               (add (E_New (id_of c) newle) (set_from_list largs U lpt))
| RA_Return : forall e lpt,
    set_In e lpt -> AVE_reduce ct E_Lib lpt e lpt
| RA_Sub : forall e e' lpt lpt' d,
    set_In e lpt -> AVE_reduce ct e lpt e' lpt' ->
    AVE_reduce ct d lpt d (add e' (lpt' U lpt))
| RAC_Field : forall e e' lpt lpt' f,
    AVE_reduce ct e lpt e' lpt' ->
    AVE_reduce ct (E_Field e f) lpt (E_Field e' f) (lpt' U lpt)
| RAC_Invk_Recv : forall e e' m le lpt lpt',
    AVE_reduce ct e lpt e' lpt' ->
    AVE_reduce ct (E_Invk e m le) lpt (E_Invk e' m le) (lpt' U lpt)
| RAC_Invk_Arg : forall e m le le' e0 e0' n lpt lpt',
    nth_error le n = Some e0 -> nth_error le' n = Some e0' ->
    AVE_reduce ct e0 lpt e0' lpt' ->
    AVE_reduce ct (E_Invk e m le) lpt (E_Invk e m le') (lpt' U lpt)
| RAC_New_Arg : forall c le le' e0 e0' n lpt lpt',
    nth_error le n = Some e0 -> nth_error le' n = Some e0' ->
    AVE_reduce ct e0 lpt e0' lpt' ->
    AVE_reduce ct (E_New c le) lpt (E_New c le') (lpt' U lpt)
| RAC_Cast : forall c e e' lpt lpt',
    AVE_reduce ct e lpt e' lpt' ->
    AVE_reduce ct (E_Cast c e) lpt (E_Cast c e') (lpt' U lpt).
Hint Constructors AVE_reduce.

Inductive AVE_reduce' (ct : class_table) : expr -> set expr -> expr -> set expr -> Prop :=
| RA'_refl : forall e lpt, AVE_reduce' ct e lpt e lpt
| RA'_step : forall e lpt e' lpt' e'' lpt'',
    AVE_reduce ct e lpt e' lpt' ->
    AVE_reduce' ct e' lpt' e'' lpt'' ->
    AVE_reduce' ct e lpt e'' lpt''.
Hint Constructors AVE_reduce'.

Lemma lemma1 : forall (ct : class_table) (c e : class) (mi : method_id) (pfc : valid_class ct c),
    mresolve ct mi c pfc = Some e -> in_app ct e -> in_app ct c.
Proof.
  intros ct c e mi pfc c_res_e e_in_app. induction pfc as [ | c d pfd IHd c_ext_d not_lib_app sca look].
  - unfold mresolve in c_res_e. inversion c_res_e.
  - unfold mresolve in c_res_e. destruct (existsb (beq_nat mi) (dmethods_id c)) in c_res_e.
    + inversion c_res_e. apply e_in_app.
    + fold mresolve in c_res_e. apply IHd in c_res_e. destruct sca.
      * inversion pfd.
        -- subst. contradiction.
        -- destruct H2. split. apply H. apply c_res_e.
      * destruct H. apply H0.
Qed.
Hint Resolve lemma1.

Lemma lemma2 : forall ct ct' (pft : ave_rel ct ct') c pfc pfc' e e' mi,
      in_app ct c -> mresolve ct mi c pfc = Some e -> mresolve ct' mi c pfc' = Some e' ->
      (in_app ct e \/ in_lib ct' e').
Proof.
  intros ct ct' pft c pfc pfc'. 
  apply simul_induct with (ct := ct) (ct' := ct') (c := c) (pfc := pfc) (pfc' := pfc'); trivial.
  (* c is Obj *)
  - contradiction.
  (* c extends d *)
  - clear c pfc pfc'. intros c d pfd pfd' ext nla sca ext' nla' sca' IHd e e' mi c_in_app mres_e mres_e'.
    inversion pft as [ct_val ct'_val keep_app keep_ext keep_lib].
    simpl in mres_e. destruct (existsb (beq_nat mi) (dmethods_id c)) eqn:exst.
    (* m-res *)
    + left. inversion mres_e. rewrite <- H0. trivial.
    (* m-res-inh *)
    + simpl in mres_e'. rewrite exst in mres_e'. 
      destruct sca as [[d_in_lib _] | [d_in_app _]].
      (* d in lib - use averroes transformation properties *)
      * right. apply mres_lib_in_lib with mi d pfd'; trivial.
        apply keep_lib; exists c; split; try split; trivial. apply in_app_in_table; apply keep_app; trivial.
      (* d in app - use induction hypothesis *)
      * apply IHd with mi; trivial. 
Qed.
Hint Resolve lemma2.

Lemma lemma3 : forall ct ct' lv le le' gamma e0 lpt,
    ave_rel ct ct' ->
    (length lv = length le) -> (length lv = length le') ->
    (forall v, expr_In v e0 -> In v lv) ->
    (Forall (fun p => alpha ct ct' gamma (fst p) (snd p) lpt) (combine le le')) ->
    type_checks ct' gamma e0 -> fj_expr e0 ->
    alpha ct ct' gamma (do_sub (combine lv le) e0) (do_sub (combine lv le') e0) lpt.
Proof.
  intros ct ct' lv le le' gamma e0 lpt rel lenve lenve' valid_body sub_rel typ_chk fj_e0.
  induction e0 using expr_ind_list.
  (* Case Var *)
  - simpl. destruct (find (fun p : var * expr => beq_var (fst p) v) (combine lv le)) eqn:sigv.
    + destruct (find (fun p0 : var * expr => beq_var (fst p0) v) (combine lv le')) eqn:sigv'.
      * assert (In (snd p, snd p0) (combine le le')).
        { apply find_pair_in_zip with (la := lv) (f := (fun v' => beq_var v' v)); trivial. }
        destruct p. destruct p0. simpl in H. 
        assert (alpha ct ct' gamma (fst (e, e0)) (snd (e, e0)) lpt).
        { apply Forall_In with (l := combine le le') (a := (e, e0)); trivial. }
        eauto.
      * apply (extract_combine (fun v' => beq_var v' v) lv le' lenve') in sigv'.
        assert (In v lv). apply valid_body. apply EIn_Var.
        apply find_In_var in H. contradiction.
    + apply (extract_combine (fun v' => beq_var v' v) lv le lenve) in sigv.
      assert (In v lv). apply valid_body. apply EIn_Var.
      apply find_In_var in H. contradiction.
  (* Case Field *)
  - simpl. destruct typ_chk as [ei Hei]. inversion Hei. inversion fj_e0.
    constructor; eauto. apply IHe0; eauto.
  (* Case New *)
  - simpl. destruct typ_chk as [ei Hei]. inversion Hei. inversion fj_e0. constructor; eauto.
    + rewrite map_length, map_length. reflexivity.
    + rewrite combine_map_l, combine_map_r. repeat apply Forall_map_swap. simpl.
      apply Forall_combine_same with
      (P := fun a b => alpha ct ct' gamma (do_sub (combine lv le) a) (do_sub (combine lv le') b) lpt).
      apply Forall_list_impl with (P := fj_expr). assumption.
      apply Forall_list_impl with (P := type_checks ct' gamma).
      { unfold type_checks. eapply Forall_exists; try eassumption. apply PeanoNat.Nat.lt_eq_cases. auto. }
      apply Forall_list_impl with (P := fun e => forall v, expr_In v e -> In v lv); try assumption.
      { eapply Forall_forall. intros. apply valid_body. constructor.
        apply Exists_exists. split_rec 2; eassumption. }
  (* Case Invk *)
  - simpl. destruct typ_chk as [ei Hei]. inversion Hei. inversion fj_e0. apply Rel_Invk; eauto.
    + apply IHe0; eauto. 
    + rewrite map_length, map_length. reflexivity.
    + rewrite combine_map_l, combine_map_r. repeat apply Forall_map_swap. simpl.
      apply Forall_combine_same with
      (P := fun a b => alpha ct ct' gamma (do_sub (combine lv le) a) (do_sub (combine lv le') b) lpt).
      apply Forall_list_impl with (P := fj_expr). assumption.
      apply Forall_list_impl with (P := type_checks ct' gamma).
      { unfold type_checks. eapply Forall_exists; try eassumption. apply PeanoNat.Nat.lt_eq_cases. auto. }
      apply Forall_list_impl with (P := fun e => forall v, expr_In v e -> In v lv); try assumption.
      { eapply Forall_forall. intros. apply valid_body. constructor. left.
        apply Exists_exists. split_rec 2; eassumption. }
  - simpl. destruct typ_chk as [ei Hei]. inversion Hei. inversion fj_e0. constructor; eauto.
    apply IHe0; eauto.
  - inversion fj_e0.
Qed.
Hint Resolve lemma3.

Lemma lemma4 : forall ct ct' lv le gamma e0 lpt,
    ave_rel ct ct' ->
    length lv = length le ->
    (forall v, expr_In v e0 -> In v lv) ->
    (Forall (fun e => alpha ct ct' gamma e E_Lib lpt) le) ->
    Forall fj_expr le ->
    type_checks (ct_lib ct) gamma e0 -> fj_expr e0 ->
    valid_sub ct gamma (combine lv le) ->
    alpha ct ct' gamma (do_sub (combine lv le) e0) E_Lib lpt.
Proof. 
  intros ct ct' lv le gamma e0 lpt rel lenve valid_body sub_rel fj_le typ_chk_lib fj_e0 val_sub.
  inversion rel as [pft pft' keep_app keep_ext keep_lib].
  assert (type_checks ct gamma e0) as typ_chk_ct by eauto.
  induction e0 using expr_ind_list; eauto.
  - simpl. destruct (find (fun p : var * expr => beq_var (fst p) v) (combine lv le)) eqn:sigv.
    + apply find_some in sigv. destruct sigv. destruct p. apply zip_In_r in H.
      apply Forall_In with (l := le) (a := e); eauto.
    + apply (extract_combine (fun v' => beq_var v' v) lv le lenve) in sigv.
      assert (In v lv). apply valid_body. apply EIn_Var.
      apply find_In_var in H. contradiction.
  - simpl. destruct typ_chk_lib as [ei_l Hei_l]. inversion Hei_l.
    destruct typ_chk_ct as [ei Hei]. inversion Hei. inversion fj_e0. subst.
    rename pfc into pfc_l. inversion pft. assert (valid_class ct c) as pfc by auto.
    apply Rel_Lib_Field with c pfc ei_l; eauto.
    + apply IHe0; eauto.
    + rewrite <- decl_in_lib_decl_in_ct with (pfc_l := pfc_l); trivial.
    + apply do_valid_sub_keep_type; trivial. subst ci. apply typ_in_lib_typ_in_ct; eauto.
  - simpl. inversion val_in_lib. inversion val_in_ct. inversion fj_e0. 
    apply Rel_Lib_New; eauto.
    + inversion H2. apply in_ct_lib_in_lib_id; trivial.
    + assert (Forall (fun e0 => (forall v : var, expr_In v e0 -> In v lv)) l).
      { apply Forall_forall. intros. apply valid_body.
        apply EIn_New. apply Exists_exists; eauto. }
      repeat (solve [rewrite Forall_map_swap; assumption] || eapply Forall_list_impl in H; try eassumption).
  - simpl. inversion val_in_lib. inversion val_in_ct. inversion fj_e0. 
    apply Rel_Lib_Invk; eauto.
    + apply IHe0; eauto. intros. apply valid_body. apply EIn_Invk. eauto.
    + assert (Forall (fun e0 => (forall v : var, expr_In v e0 -> In v lv)) l).
      { apply Forall_forall. intros. apply valid_body.
        apply EIn_Invk. left. apply Exists_exists; eauto. }
      repeat (solve [rewrite Forall_map_swap; assumption] || eapply Forall_list_impl in H; try eassumption).
  - simpl. inversion val_in_lib. inversion val_in_ct. inversion fj_e0. 
    apply Rel_Lib_Cast. apply IHe0; eauto.
    intros. apply valid_body. apply EIn_Cast. eauto.
  - inversion fj_e0.
  - inversion rel; trivial.
Qed.
Hint Resolve lemma4.

Lemma lemma5 : forall ct ct' gamma e e' lpt lpt',
    alpha ct ct' gamma e e' lpt -> alpha ct ct' gamma e e' (lpt U lpt').
Proof.
  intros ct ct' gamma e e' lpt lpt' rel.
  induction rel using alpha_ind_list; eauto; econstructor; try eassumption. 
  apply union_introl; trivial.
Qed.
Hint Resolve lemma5.

Lemma lemma7addextra : forall A (ns lpt' lpt : set A),
    ns U lpt' U lpt = (ns U lpt') U ns U lpt.
Proof.
  intros.
  rewrite (union_comm ns lpt'). rewrite union_assoc.
  rewrite <- (union_assoc ns ns lpt). rewrite union_same.
  rewrite <- union_assoc. rewrite (union_comm ns lpt').
  rewrite union_assoc. reflexivity.
Qed.
Hint Resolve lemma7addextra.

Lemma lemma7 : forall ct' e e' lpt lpt' ns,
    AVE_reduce ct' e lpt e' lpt' -> AVE_reduce ct' e (union ns lpt) e' (union ns lpt').
Proof.
  intros ct' e e' lpt lpt' ns reduce.
  induction reduce; try solve [constructor; trivial; try apply union_intror; try apply H]; try rewrite union_addr; try rewrite lemma7addextra;
    try econstructor; try eassumption. 
  - rewrite <- lemma7addextra. rewrite <- union_assoc.
    rewrite (union_comm ns (set_from_list largs)). rewrite union_assoc.
    econstructor; eassumption.
  - apply union_intror. apply H.
Qed.
Hint Resolve lemma7.

Lemma lemma8 : forall ct' e e' lpt lpt',
    AVE_reduce ct' e lpt e' lpt' -> subset lpt lpt'.
Proof. 
  intros. unfold subset. unfold E.Included.
  induction H; intros;
    solve [ apply union_introl; solve [ apply union_introl; reflexivity || trivial
                                      | apply union_intror; reflexivity || trivial
                                      | reflexivity || trivial]
          | apply union_intror; solve [ apply union_introl; reflexivity || trivial
                                      | apply union_intror; reflexivity || trivial
                                      | reflexivity || trivial]
          | reflexivity || trivial].
Qed.
Hint Resolve lemma8.


Lemma lemma9setfromlist : forall {A : Type} (l : list A) (n : nat) (a : A),
    length l = S n -> nth_error l n = Some a ->
    set_from_list (first_n l (S n)) = add a (set_from_list (first_n l n)).
Proof.
  induction l; intros; simpl; inversion H.
  destruct n; rewrite H2; inversion H0.
  - simpl. destruct l; simpl; reflexivity.
  - simpl. rewrite IHl with n a0; trivial.
    unfold add. unfold E.Add. rewrite union_assoc. rewrite (union_comm (E.Singleton A a0) (E.Singleton A a)).
    rewrite <- union_assoc. reflexivity.
Qed.
Hint Resolve lemma9setfromlist.

Lemma lemma9 : forall ct' n le e0 llpt lpt0,
    length le = S n -> length llpt = S n ->
    hd_error le = Some e0 -> hd_error llpt = Some lpt0 ->
    e0 <> E_Lib -> set_In e0 lpt0 ->
    (forall m e lpt e0 lpt0,
        m < n -> nth_error le m = Some e -> nth_error llpt m = Some lpt ->
        nth_error le (S m) = Some e0 -> nth_error llpt (S m) = Some lpt0 ->
        AVE_reduce ct' e lpt e0 lpt0) ->
    (forall m lpt lpt0,
        m < n -> nth_error llpt m = Some lpt -> nth_error llpt (S m) = Some lpt0 ->
        AVE_reduce ct' E_Lib (set_from_list (first_n le (S m)) U lpt)
                   E_Lib (set_from_list (first_n le (S (S m))) U lpt0)).
Proof.
  induction n.
  - intros le e0 llpt lpt0 len_le len_llpt hde0 hdlpt0 neq_lib_e0 in_e_lpt0
           n_reduce m lpt_m lpt_sm le_m_n index_lpt_m index_lpt_sm.
    inversion le_m_n.
  - intros le e0 llpt lpt0 len_le len_llpt hde0 hdlpt0 neq_lib_e0 in_e_lpt0
           n_reduce m lpt_m lpt_sm le_m_n index_lpt_m index_lpt_sm.
    destruct le; inversion len_le.
    destruct llpt; inversion len_llpt.
    inversion hde0. inversion hdlpt0.
    assert ({ m = n } + { m <> n }) by apply PeanoNat.Nat.eq_dec. destruct H.
    + subst m. subst e0.
      assert (exists e', nth_error (e :: le) n = Some e').
      { apply get_nth with (n0 := S (S n)); trivial.
        apply le_S. apply le_m_n. }
      destruct H as [e_m index_e_m].
      assert (exists e', nth_error (e :: le) (S n) = Some e').
      { apply get_nth with (n0 := S (S n)); trivial.
        apply Lt.lt_n_S. apply le_m_n. }
      destruct H as [e_Sm index_e_Sm].
      assert (AVE_reduce ct' e_m lpt_m e_Sm lpt_sm).
      { apply n_reduce with n; trivial. }
      assert (AVE_reduce ct' e_m (set_from_list (first_n (e :: le) (S n)) U lpt_m)
                             e_Sm (set_from_list (first_n (e :: le) (S n)) U lpt_sm)).
      { apply lemma7; trivial. }
      assert (set_from_list (first_n (e :: le) (S (S n))) = add e_Sm (set_from_list (first_n (e :: le) (S n)))).
      { apply lemma9setfromlist; trivial. }
      rewrite H4. rewrite union_addl.
      assert (lpt_sm = lpt_sm U lpt_m).
      { apply union_include. apply lemma8 with ct' e_m e_Sm; trivial. }
      rewrite H5. rewrite (union_comm lpt_sm lpt_m). rewrite <- union_assoc.
      remember (set_from_list (first_n (e :: le) (S n)) U lpt_m) as lpt_m'.
      rewrite <- (union_same lpt_m').
      rewrite (union_comm (lpt_m' U lpt_m')).
      rewrite <- union_assoc.
      rewrite union_same.
      apply RA_Sub with e_m; trivial.
      * rewrite Heqlpt_m'. apply union_introl. apply In_list_set_In_list. apply nth_error_In with n.
        apply nth_error_first_n. apply index_e_m.
      * rewrite union_comm. rewrite Heqlpt_m'. rewrite union_assoc. rewrite (union_comm lpt_m).
        rewrite <- (union_include lpt_m lpt_sm). rewrite <- Heqlpt_m'. apply H2.
        apply lemma8 with ct' e_m e_Sm. trivial.
    + subst e. subst s.
      rewrite remove_last_first_n.
      rewrite (remove_last_first_n (e0 :: le) (S (S m))).
      apply IHn with e0 (remove_last (lpt0 :: llpt)) lpt0; trivial.
      * erewrite <- remove_last_length. reflexivity. assumption.
      * erewrite <- remove_last_length. reflexivity. assumption.
      * destruct le. inversion len_le. reflexivity.
      * destruct llpt. inversion len_llpt. reflexivity.
      * intros. eapply n_reduce with m0; eauto;
                  rewrite remove_last_nth_error; eauto; rewrite len_le || rewrite len_llpt; apply Lt.lt_n_S;
                    solve [apply Lt.lt_S; trivial | apply Lt.lt_n_S; trivial].
      * inversion le_m_n. contradiction. apply H2.
      * rewrite <- remove_last_nth_error. trivial. rewrite len_llpt. apply Lt.lt_n_S. trivial.
      * rewrite <- remove_last_nth_error. trivial. rewrite len_llpt.
        apply Lt.lt_n_S. apply Lt.lt_n_S. inversion le_m_n. contradiction. apply H2.
      * rewrite len_le. apply Lt.lt_n_S. apply Lt.lt_n_S. inversion le_m_n. contradiction. apply H2.
      * rewrite len_le. apply Lt.lt_n_S. apply le_m_n.
Qed.
Hint Resolve lemma9.

Lemma E_Lib_dec : forall e, e = E_Lib \/ e <> E_Lib.
Proof.
  intros. destruct e; solve [left; trivial | right; discriminate].
Qed.
Hint Resolve E_Lib_dec.

Lemma use_lemma_9_1 : forall ct' e lpt e' lpt',
    AVE_reduce' ct' e lpt e' lpt' -> exists le llpt n,
        length le = S n /\ length llpt = S n /\
        hd_error le = Some e /\ hd_error llpt = Some lpt /\
        last_error le = Some e' /\ last_error llpt = Some lpt' /\
        (forall m e lpt e0 lpt0,
            m < n -> nth_error le m = Some e -> nth_error llpt m = Some lpt ->
            nth_error le (S m) = Some e0 -> nth_error llpt (S m) = Some lpt0 ->
            AVE_reduce ct' e lpt e0 lpt0).
Proof.
  intros. induction H.
  - exists (e :: nil). exists (lpt :: nil). exists 0.
    split; split; split; split; split; split; trivial || intros. inversion H.
  - destruct IHAVE_reduce' as [le [llpt [n [len_le [len_llpt [hd_le [hd_llpt [last_le [last_llpt AVE_each]]]]]]]]].
    exists (e :: le). exists (lpt :: llpt). exists (S n).
    split; try split; try split; try split; try split; try split.
    + simpl. rewrite len_le. reflexivity.
    + simpl. rewrite len_llpt. reflexivity.
    + simpl. destruct le; inversion len_le. rewrite last_le. reflexivity.
    + simpl. destruct llpt; inversion len_llpt. rewrite last_llpt. reflexivity.
    + intros. destruct m.
      * inversion H2. inversion H3. inversion H4. inversion H5.
        destruct le; inversion len_le. destruct llpt; inversion len_llpt.
        subst e0. subst lpt0. inversion hd_le. inversion hd_llpt. subst e2. subst s.
        inversion H9. inversion H10. subst e1. subst lpt1. trivial.
      * apply AVE_each with m; try assumption.
        apply Lt.lt_S_n. apply H1.
Qed.
Hint Resolve use_lemma_9_1.

Lemma unuse_lemma_9_1 : forall n ct' e lpt e' lpt' le llpt,
    length le = S n -> length llpt = S n ->
    hd_error le = Some e -> hd_error llpt = Some lpt ->
    last_error le = Some e' -> last_error llpt = Some lpt' ->
    (forall m e lpt e0 lpt0,
        m < n -> nth_error le m = Some e -> nth_error llpt m = Some lpt ->
        nth_error le (S m) = Some e0 -> nth_error llpt (S m) = Some lpt0 ->
        AVE_reduce ct' e lpt e0 lpt0) ->
    AVE_reduce' ct' e lpt e' lpt'.
Proof.
  induction n.
  - intros.
    destruct le; inversion H1. destruct le; inversion H.
    destruct llpt; inversion H4. destruct llpt; inversion H0.
    subst e0. inversion H8. subst s. inversion H2. inversion H3.
    subst e'. subst lpt'. apply RA'_refl.
  - intros ct' e lpt e' lpt' le llpt len_le len_llpt hd_le hd_llpt last_le last_llpt AVE_each.
    destruct le as [| e0 le']; inversion len_le as [len_le'].
    destruct le' as [| e1 le'']; inversion len_le' as [len_le''].
    destruct llpt as [| lpt0 llpt']; inversion len_llpt as [len_llpt'].
    destruct llpt' as [| lpt1 llpt'']; inversion len_llpt' as [len_llpt''].
    apply RA'_step with e1 lpt1.
    + apply AVE_each with 0; trivial. unfold lt. apply le_n_S. apply le_0_n.
    + apply IHn with (e1 :: le'') (lpt1 :: llpt''); trivial.
      intros. apply AVE_each with (S m); try assumption.
      apply Lt.lt_n_S. assumption.
Qed.
Hint Resolve unuse_lemma_9_1.

Lemma lemma10 : forall ct ct' gamma e0 e0' e' lpt lpt',
    alpha ct ct' gamma e0 E_Lib lpt -> alpha ct ct' gamma e0' e' lpt' ->
    FJ_reduce ct e0 e0' -> AVE_reduce' ct' E_Lib lpt e' lpt' -> exists lpt'',
        alpha ct ct' gamma e0' E_Lib lpt'' /\ AVE_reduce' ct' E_Lib lpt E_Lib lpt''.
Proof.
  intros. destruct (E_Lib_dec e').
  - exists lpt'. subst e'. split; trivial.
  - dependent induction H2; try (destruct H3; reflexivity).
    destruct (E_Lib_dec e').
    + assert (exists lpt'' : set expr,
                 alpha ct ct' gamma e0' E_Lib lpt'' /\ AVE_reduce' ct' E_Lib lpt' E_Lib lpt'').
      { apply IHAVE_reduce'; trivial.
        - rewrite (union_include lpt lpt').
          + rewrite union_comm. apply lemma5. trivial.
          + apply lemma8 with ct' E_Lib e'; trivial. }
      destruct H6 as [lpt''0 [alph AVE_red]].
      exists lpt''0. split; trivial.
      subst e'. apply RA'_step with E_Lib lpt'; trivial.
    + inversion H2.
      * inversion H6.
      * symmetry in H10. contradiction.
      * symmetry in H9. contradiction.
      * symmetry in H10. contradiction.
      * subst lpt. subst lpt'. subst e'. rename e'' into e'. rename lpt'' into lpt'.
        assert (exists lpt''', AVE_reduce' ct' E_Lib lpt0 E_Lib lpt''' /\
                          subset lpt' lpt''' /\
                          set_In e' lpt''').
        { apply use_lemma_9_1 in H3 as H7.
          destruct H7 as [le [llpt [n [len_le [len_llpt [hd_le [hd_llpt [last_le [last_llpt AVE_each]]]]]]]]].
          assert (forall m lpt lpt0,
                     m < n -> nth_error llpt m = Some lpt -> nth_error llpt (S m) = Some lpt0 ->
                     AVE_reduce ct' E_Lib (set_from_list (first_n le (S m)) U lpt)
                                E_Lib (set_from_list (first_n le (S (S m))) U lpt0)).
          apply lemma9 with e lpt0; assumption.
          exists (set_from_list (first_n le (S n)) U lpt'). split; try split.
          - apply unuse_lemma_9_1 with n (repeat E_Lib (S n))
                                             (map (fun p => set_from_list (first_n le (S (fst p))) U (snd p))
                                                  (zip_with_ind llpt)); trivial.
            + apply repeat_length.
            + rewrite map_length. rewrite zip_with_ind_length. trivial.
            + destruct llpt; inversion hd_llpt. subst s.
              simpl. f_equal. destruct le; inversion hd_le. subst e1. 
              replace (first_n (e :: le) 1) with (e :: nil) by (destruct le; reflexivity). 
              symmetry. rewrite union_comm. apply union_include.
              unfold subset. unfold E.Included. intros. simpl in H8. destruct H8; inversion H8.
              subst x. apply H6.
            + rewrite last_error_map with (a := (n, lpt')); eauto. 
            + intros. destruct n. inversion H8.
              assert (exists lpt_m, nth_error llpt m = Some lpt_m).
              { apply nth_error_better_Some. rewrite len_llpt. apply le_S. apply H8. }
              assert (exists lpt_Sm, nth_error llpt (S m) = Some lpt_Sm).
              { apply nth_error_better_Some. rewrite len_llpt. apply le_n_S. apply H8. }
              destruct H13 as [lpt_m Hlpt_m]. destruct H14 as [lpt_Sm Hlpt_Sm].
              replace lpt with (set_from_list (first_n le (S m)) U lpt_m).
              replace lpt1 with (set_from_list (first_n le (S (S m))) U lpt_Sm).
              replace e1 with E_Lib. replace e2 with E_Lib.
              * apply H7; trivial. 
              * symmetry. apply repeat_spec with (S (S n)). apply nth_error_In with (S m). trivial.
              * symmetry. apply repeat_spec with (S (S n)). apply nth_error_In with m. trivial.
              * apply nth_error_zip_with_ind in Hlpt_Sm.
                apply nth_error_map with (f := (fun p => set_from_list (first_n le (S (fst p))) U snd p)) in Hlpt_Sm.
                assert (Some (set_from_list (first_n le (S (S m))) U lpt_Sm) = Some lpt1).
                { rewrite <- H12. symmetry. apply Hlpt_Sm. }
                inversion H13. trivial.
              * apply nth_error_zip_with_ind in Hlpt_m.
                apply nth_error_map with (f := (fun p => set_from_list (first_n le (S (fst p))) U snd p)) in Hlpt_m.
                assert (Some (set_from_list (first_n le (S m)) U lpt_m) = Some lpt).
                { rewrite <- H10. symmetry. apply Hlpt_m. }
                inversion H13. trivial.
          - unfold subset. unfold E.Included. intros. apply union_intror. assumption.
          - rewrite <- len_le. rewrite first_n_length. apply union_introl. apply In_list_set_In_list.
            apply last_error_In. apply last_le. }
        destruct H7 as [lpt''' [AVE_red''' [sub_lpt'_lpt''' in_e_lpt''']]].
        exists lpt'''. split; trivial.
        apply Rel_Lpt with e'; trivial.
        rewrite (union_include lpt'); trivial.
        rewrite union_comm. apply lemma5. trivial.
      * symmetry in H10. contradiction.
Qed.
Hint Resolve lemma10.

Lemma fields_same : forall {ct ct' c} (pfc : valid_class ct c) (pfc' : valid_class ct' c),
    ave_rel ct ct' -> fields ct c pfc = fields ct' c pfc'.
Proof.
  intros. apply simul_induct with (ct := ct) (ct' := ct') (c := c) (pfc := pfc) (pfc' := pfc'); trivial.
  - clear c pfc pfc'. intros. simpl. rewrite H0. reflexivity.
Qed.
Hint Resolve fields_same.

Lemma field_ids_same : forall {ct ct' c} (pfc : valid_class ct c) (pfc' : valid_class ct' c),
    ave_rel ct ct' -> field_ids ct c pfc = field_ids ct' c pfc'.
Proof.
  intros. apply simul_induct with (ct := ct) (ct' := ct') (c := c) (pfc := pfc) (pfc' := pfc'); trivial.
  - clear c pfc pfc'. intros. simpl. rewrite H0. reflexivity.
Qed.
Hint Resolve field_ids_same.

Inductive sub_expr : expr -> expr -> Prop :=
| SUB_Refl : forall e, sub_expr e e
| SUB_Trans : forall e e' e'', sub_expr e e' -> sub_expr e' e'' -> sub_expr e e''
| SUB_Field : forall e fi, sub_expr e (E_Field e fi)
| SUB_New : forall e le ci, In e le -> sub_expr e (E_New ci le)
| SUB_Invk_Recv : forall e mi le, sub_expr e (E_Invk e mi le)
| SUB_Invk_Arg : forall e mi le e', In e' le -> sub_expr e' (E_Invk e mi le)
| SUB_Cast : forall e ci, sub_expr e (E_Cast ci e).
Hint Constructors sub_expr.

Lemma calPsub : forall ct' gamma e lpt e',
    calP ct' gamma e lpt -> sub_expr e' e -> calP ct' gamma e' lpt.
Proof.
  intros. induction H0; eauto; unfold calP in H; destruct H as [typ_chk lpt_good];
            inversion typ_chk; unfold calP; split; trivial; apply Forall_In with le; trivial.
Qed.
Hint Resolve calPsub.

Lemma keep_id_keep_class : forall ct ct' c (pfc : valid_class ct c),
    ave_rel ct ct' -> in_lib ct c -> in_table_id ct' (id_of c) -> in_lib ct' c.
Proof.
  intros. destruct ct' as [app' lib']. destruct H1 as [ci_in_app | ci_in_lib].
  - simpl in ci_in_app. destruct ci_in_app as [c0 Hc0].
    inversion H. inversion H2.
    assert (id_of c = id_of c0).
    { apply H8. simpl. rewrite Hc0. reflexivity. }
    rewrite H13 in Hc0.
    assert (in_app (app', lib') c0) as c0_in_app' by assumption.
    apply H3 in c0_in_app' as c0_in_app.
    inversion H1.
    assert (valid_class ct c0).
    { apply H14. apply in_app_in_table. assumption. }
    assert (c = c0).
    { apply id_eq with ct; assumption. }
    subst c0. destruct (not_lib_app ct c pfc). split; assumption.
  - simpl in ci_in_lib. destruct ci_in_lib as [c0 Hc0].
    inversion H. inversion H2.
    assert (id_of c = id_of c0).
    { apply H8. simpl. destruct (app' (id_of c)) eqn:appci; try assumption.
      destruct (H9 (id_of c)). simpl. split. exists c0. assumption. exists c1. assumption. }
    rewrite H13 in Hc0.
    assert (in_lib (app', lib') c0) as c0_in_lib' by assumption.
    apply H5 in c0_in_lib' as exst. destruct exst as [_ [_ [c0_in_lib _]]].
    inversion H1.
    assert (valid_class ct c0).
    { apply H14. apply in_lib_in_table. assumption. }
    assert (c = c0).
    { apply id_eq with ct; assumption. }
    subst c0. assumption.
Qed.
Hint Resolve keep_id_keep_class.

Lemma In_fields_decl_exists : forall {ct c} (pfc : valid_class ct c) fi,
    In fi (field_ids ct c pfc) <-> (exists ci, declaring_class ct c pfc fi = Some ci).
Proof.
  induction pfc; intros.
  - split; intros; inversion H. inversion H0.
  - split; intros.
    + simpl. destruct (@existsb field_id (beq_nat fi) (dfields c)) eqn:exstb; try (exists (id_of c); reflexivity).
      apply IHpfc. destruct c; try inversion H.
      simpl in H. apply in_app_or in H. destruct H; try assumption.
      simpl in exstb.
      assert (@existsb field_id (beq_nat fi) (map snd l) = true).
      { apply existsb_exists. exists fi. split. assumption. symmetry. apply beq_nat_refl. }
      rewrite exstb in H0. discriminate H0.
    + destruct H as [ci Hci]. simpl in Hci.
      destruct (@existsb field_id (beq_nat fi) (dfields c)) eqn:exstb.
      * destruct c; inversion exstb.
        simpl. simpl in Hci. apply in_or_app. left. apply existsb_exists in H0.
        destruct H0 as [x [Inx Heqx]]. apply beq_nat_true in Heqx. subst. assumption.
      * destruct c; inversion e. simpl in exstb. simpl. apply in_or_app. right. apply IHpfc.
        exists ci. assumption.
Qed.
Hint Resolve In_fields_decl_exists.

Lemma decl_of_in_lib_in_lib : forall {ct c} (pfc : valid_class ct c) fi di,
    declaring_class ct c pfc fi = Some di -> in_lib ct c -> in_lib_id ct di.
Proof.
  induction pfc; intros.
  - inversion H.
  - simpl in H. destruct (@existsb field_id (beq_nat fi) (dfields c)).
    + inversion H. subst. destruct ct. simpl. exists c. assumption.
    + apply IHpfc with fi; try assumption.
      destruct o as [[in_lib _] | [_ contra]]; try assumption.
      destruct n. split; assumption.
Qed.
Hint Resolve decl_of_in_lib_in_lib.

Lemma decl_ct'_decl_ct : forall ct ct' (pft : ave_rel ct ct') c pfc pfc' fi,
    declaring_class ct' c pfc' fi = declaring_class ct c pfc fi.
Proof.
  intros ct ct' pft c pfc pfc'.
  apply simul_induct with (ct := ct) (ct' := ct') (c := c) (pfc := pfc) (pfc' := pfc'); try assumption.
  - split; trivial.
  - clear c pfc pfc'. intros c d pfd pfd' ext nla sca ext' nla' sca' IHc fi.
    simpl. destruct (@existsb field_id (beq_nat fi) (dfields c)) eqn:exstb; try reflexivity.
    apply IHc. 
Qed.
Hint Resolve decl_ct'_decl_ct.

Lemma valid_ct_not_lib_app_id : forall {ct},
    valid_table ct -> (forall ci, ~ (in_lib_id ct ci /\ in_app_id ct ci)).
Proof. intros. destruct H. apply H2. Qed.
Hint Resolve valid_ct_not_lib_app_id.

Lemma valid_ct'_valid_ct : forall ct ct' c (pfc' : valid_class ct' c),
    ave_rel ct ct' -> valid_class ct c.
Proof.
  intros. destruct H. induction pfc'.
  - apply ValidObj.
    + apply H3 in i. destruct i as [_ [_ [in_lib _]]]. assumption.
    + intro. apply H1 in H4. contradiction.
  - apply ValidParent with d; try assumption.
    + apply H2 in e. apply e.
    + intro. destruct H4. destruct (valid_ct_not_lib_app_id H (id_of c)).
      destruct ct as [app lib]. split; exists c; assumption.
    + destruct o as [[d_in_lib' c_in_table'] | [d_in_app' c_in_app']].
      * left. split.
        -- apply H3 in d_in_lib'. destruct d_in_lib' as [_ [_ [in_lib _]]]. assumption.
        -- destruct c_in_table'.
           ++ apply in_app_in_table. apply H1. assumption.
           ++ apply H3 in H4. apply in_lib_in_table. destruct H4. apply H4.
      * right. split; apply H1; assumption.
Qed.
Hint Resolve valid_ct'_valid_ct.

Lemma decl_in_table : forall ct c pfc fi di,
    declaring_class ct c pfc fi = Some di -> in_table_id ct di.
Proof.
  intros ct c pfc fi di decl. induction pfc.
  - inversion decl.
  - simpl in decl. destruct (@existsb field_id (beq_nat fi) (dfields c)) eqn:exst; eauto.
    inversion decl. subst. destruct ct as [app lib].
    destruct o as [[_ [in_app | in_lib]] | [_ in_app]];
      solve [left; exists c; assumption | right; exists c; assumption ].
Qed.
Hint Resolve decl_in_table.

Lemma in_table_in_table' : forall ct ct' c,
    ave_rel ct ct' -> in_table ct c -> in_table_id ct' (id_of c) -> in_table ct' c.
Proof.
  intros. inversion H. destruct H0.
  - apply H4 in H0. left. assumption.
  - right. destruct ct' as [app' lib']. destruct H1.
    + destruct H1 as [c0 Hc0]. inversion H3. 
      assert (id_of c = id_of c0).
      { apply H8. simpl. rewrite Hc0. reflexivity. }
      rewrite H13 in Hc0.
      assert (in_app (app', lib') c0) as c0_in_app' by assumption.
      apply H4 in c0_in_app' as c0_in_app.
      inversion H2 as [ct' in_table_valid _ _ _ _ _]. subst.
      assert (valid_class ct c) as pfc.
      { apply in_table_valid. apply in_lib_in_table. assumption. }
      assert (valid_class ct c0) as pfc0.
      { apply in_table_valid. apply in_app_in_table. assumption. }
      apply id_eq with (ct := ct) in H13; try assumption.
      subst c0. destruct (not_lib_app ct c); try split; assumption.
    + destruct H1 as [c0 Hc0]. inversion H3.
      assert (id_of c = id_of c0).
      { apply H8. simpl. destruct (app' (id_of c)) eqn:appci; try assumption.
        destruct (H9 (id_of c)). split; [exists c0 | exists c1]; assumption. }
      rewrite H13 in Hc0.
      assert (in_lib (app', lib') c0) as c0_in_lib' by assumption.
      apply H6 in c0_in_lib' as c0_in_lib.
      destruct c0_in_lib as [_ [_ [c0_in_lib _]]].
      inversion H2 as [ct' in_table_valid _ _ _ _ _]. subst.
      apply id_eq with (ct := ct) in H13; subst; try assumption;
        apply in_table_valid; apply in_lib_in_table; assumption.
Qed.
Hint Resolve in_table_in_table'.

Lemma decld_class_same_decl : forall ct c pfc fi e pfe,
    valid_table ct -> 
    declaring_class ct c pfc fi = Some (id_of e) ->
    declaring_class ct e pfe fi = Some (id_of e).
Proof.
  intros. remember pfc as rempfc. induction rempfc as [| c d pfd]. inversion H0.
  assert (rem_decl := H0).
  simpl in H0. destruct (@existsb field_id (beq_nat fi) (dfields c)).
  - inversion H0. apply id_eq with (ct := ct) in H2; try assumption. subst c.
    assert (pfc = pfe) by apply valid_class_irrelevance.
    subst. subst. assumption.
  - apply IHpfd with pfd; try reflexivity. assumption.
Qed.
Hint Resolve decld_class_same_decl.

Lemma fields_field_ids_length : forall ct c pfc,
    length (fields ct c pfc) = length (field_ids ct c pfc).
Proof.
  intros. induction pfc; try reflexivity.
  simpl. destruct c; try solve [inversion e].
  repeat (rewrite app_length; rewrite map_length). rewrite IHpfc. reflexivity.
Qed.
Hint Resolve fields_field_ids_length.
