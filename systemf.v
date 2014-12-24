Require Import Arith.
Require Import Bool.
Require Import Omega.
Require Import NPeano.
Require Import Max.

(* -------------------- I---- Defining the Type System -------------------- *)

(* ---- I.2 --- Definitions ---*)

(* Question 1 *)

Inductive kind : Set := star : nat -> kind.

Inductive typ : Type := 
  |typ_var : nat -> typ
  |typ_fleche : typ -> typ -> typ
  |typ_pourtout : kind -> typ -> typ.

(* Décale vers la droite les variables libres dans un type.
i.e : typ_var(n) => typ_var(n+1) *)
Fixpoint typ_shift_in_type T:typ :=
  match T with
    |typ_var n => typ_var (n+1)
    |typ_fleche T1 T2 => typ_fleche (typ_shift_in_type T1) (typ_shift_in_type T2)
    |typ_pourtout X T1 => typ_pourtout X (typ_shift_in_type T1)
    end.

(* substitution de X par U dans T *)
Fixpoint tsubst (X:nat) (U:typ) (T:typ) :=
  match T with
    |typ_var m => match lt_eq_lt_dec X m with (* X<m \/ X=m \/ X>m *)
      |inleft(left _) => T 
      |inleft(right _) => U
      |inright(_) => T
      end
    |typ_fleche T1 T2 => typ_fleche (tsubst X U T1) (tsubst X U T2)
    |typ_pourtout Y T1 => typ_pourtout Y (tsubst (X-1) (typ_shift_in_type U) T1)
  end.


(* Question 2 *)

Inductive term : Set :=
  |term_var : nat -> term
  |term_small_lambda : typ -> term -> term
  |term_app_term : term -> term -> term
  |term_big_lambda : kind -> term -> term
  |term_app_typ : term -> typ -> term.

(* Décale vers la droite les variables libres de type dans un terme.
i.e : typ_var(n) => typ_var(n+1) *)
Fixpoint typ_shift_in_term t:term :=
  match t with
    |term_var _ => t
    |term_small_lambda T t1 => term_small_lambda T (typ_shift_in_term t1)
    |term_app_term t1 t2 => term_app_term (typ_shift_in_term t1) (typ_shift_in_term t2)
    |term_big_lambda k t1 => term_big_lambda k (typ_shift_in_term t1)
    |term_app_typ t1 T => term_app_typ (typ_shift_in_term t1) (typ_shift_in_type T)
    end.

(* Décale vers la droite les variables libres de terme dans un terme.
i.e : term_var(n) => term_var(n+1) *)
Fixpoint term_shift_in_term t:term :=
  match t with
    |term_var n => term_var (n+1)
    |term_small_lambda T t1 => term_small_lambda T (term_shift_in_term t1)
    |term_app_term t1 t2 => term_app_term (term_shift_in_term t1) (term_shift_in_term t2)
    |term_big_lambda k t1 => term_big_lambda k (term_shift_in_term t1)
    |term_app_typ t1 T => term_app_typ (term_shift_in_term t1) T
    end.

Fixpoint subst_typ (X:nat) (U:typ) (t:term) :=
  match t with
    |term_var _ => t
    |term_small_lambda T t1 => term_small_lambda T (subst_typ (X-1) (typ_shift_in_type U) t1)
    |term_app_term t1 t2 => term_app_term (subst_typ X U t1) (subst_typ X U t2)
    |term_big_lambda k t1 => term_big_lambda k (subst_typ (X-1) (typ_shift_in_type U) t1)
    |term_app_typ t1 T => term_app_typ (subst_typ X U t1) (tsubst X U T)
    end.

(* Substitution de x libre par t1 dans t2 *)
Fixpoint subst (x:nat) (t1:term) (t2:term) :=
  match t2 with
    |term_var m => match lt_eq_lt_dec x m with (* x<m \/ x=m \/ x>m *)
      |inleft(left _) => t2
      |inleft(right _) => t1
      |inright(_) => t2
      end
    |term_small_lambda T t3 => term_small_lambda T (subst (x-1) (term_shift_in_term t1) t3)
    |term_app_term t3 t4 => term_app_term (subst x t1 t3) (subst x t1 t4)
    |term_big_lambda k t3 => term_big_lambda k (subst (x-1) (term_shift_in_term t1) t3)
    |term_app_typ t3 T => term_app_typ (subst x t1 t3) T
    end.

(* Question 3 *)

Inductive env : Set :=
  |env_empty : env
  |declare_kind : kind -> env -> env
  |declare_typ : typ -> env -> env.

(*Soit e un environnement et X une variable de type, la fonction qui suit renvoie le kind e(X) 
 si défini, None sinon *)
Fixpoint get_kind (X:nat) (e:env) :=
  match (e, X) with 
    |(env_empty, _) => None
    |(declare_kind T e1, 0) => Some T
    |(declare_kind T e1, S n) => get_kind n e1
    |(declare_typ t e1, 0) => None
    |(declare_typ t e1, S n) => get_kind n e1
    end.

(*Soit e un environnement et X une variable de terme, la fonction qui suit
 renvoie e(x) si défini, None sinon *)
Fixpoint get_type (x:nat) (e:env) :=
  match (e, x) with 
    |(env_empty,_) => None
    |(declare_kind T e1, 0) => None
    |(declare_kind T e1, S n) => get_type n e1
    |(declare_typ t e1, 0) => Some t
    |(declare_typ t e1, S n) => get_type n e1
    end.

(* Question 4 *)

(*
Fixpoint wf_env (e:env) :=
  match e with
    |env_empty => True
    |declare_kind k e1 => wf_env e1
    |declare_typ T e1 => (wf_env e1) /\ (exists p, (kinding e1 T (star p) ))
    end

with kinding (e:env) (T:typ) (k:kind) :=
  match (T, k) with
    |(typ_var X, star(q)) => (exists p, (((get_kind X e) = Some(star p)) /\ (p <= q))) /\ wf_env e
    |(typ_pourtout (star q) T1, star(r)) => exists p, ((kinding (declare_kind (star q) e) T1 (star p)) /\ (r = (max p q)+1))
    |(typ_fleche T1 T2, star(r)) => (exists p, exists q, (kinding e T1 (star p) /\ (kinding e T2 (star q) /\ (r = (max p q)))))
    end.

Fixpoint typing (e:env) (t:term) (T:typ) :=
  match (t, T) with
    |(term_var x, T) => ((get_type x e) = Some(T)) /\ wf_env e
    |(term_small_lambda T1 t1, typ_fleche T3 T2) => (T3=T1) /\ typing (declare_typ T1 e) t1 T2
    |(term_app_term t1 t2, T2) => exists T1, ((typing e t1 (typ_fleche T1 T2)) /\ (typing e t2 T1))
    |(term_big_lambda (star p) t1, typ_pourtout (star q) T1) => (p=q) /\ typing (declare_kind (star p) e) t T1
    |(term_app_typ t1 T2, T3) => exists l, exists T1, (kinding e T2 (star l)) /\ typing e t1 (typ_pourtout (star l) T1) /\ (exists X, T3 = tsubst X T2 T1)
    |_ => False
    end.
*)

Fixpoint wf_typ (e:env) (T:typ) : bool :=
  match T with
    |typ_var X => match get_kind X e with
      |None => false
      |_ => true
      end
    |typ_fleche T1 T2 => wf_typ e T1 && wf_typ e T2
    |typ_pourtout k T2 => wf_typ (declare_kind k e) T2
    end.

Fixpoint wf_env (e:env) : bool :=
   match e with
     |env_empty => true
     |declare_typ T e => wf_typ e T && wf_env e
     |declare_kind k e => wf_env e
     end.

Inductive kinding : env -> typ -> kind -> Prop :=
  |kinding_var : forall (e:env) (X:nat) (p q : nat),
    get_kind X e = Some (star p) -> p <= q -> (wf_env e = true) -> kinding e (typ_var X) (star q)
  
  |kinding_pourtout : forall (e:env) (T:typ) (X:nat) (p q:nat),
    kinding (declare_kind (star q) e) T (star p) -> kinding e (typ_pourtout (star q) T) (star (max p q + 1))
    
  |kinding_fleche : forall (e:env) (T1 T2:typ) (p q:nat),
    kinding e T1 (star p) -> kinding e T2 (star q) -> kinding e (typ_fleche T1 T2) (star (max p q)).


Inductive typing : env -> term -> typ -> Prop :=
  |typing_var : forall (e:env) (x:nat) (T:typ),
    get_type x e = Some T -> (wf_env e = true) -> typing e (term_var x) T

  |typing_small_lambda : forall (e:env) (t:term) (T1 T2: typ),
    typing (declare_typ T1 e) t T2 -> typing e (term_small_lambda T1 t) (typ_fleche T1 T2)

  |typing_app_term : forall (e:env) (t1 t2 :term) (T1 T2 T1T2:typ),
    typing e t1 (typ_fleche T1 T2) -> typing e t2 T1 -> typing e (term_app_term t1 t2) T2

  |typing_big_lambda : forall (e:env) (t: term) (T: typ) (p:nat),
    typing (declare_kind (star p) e) t T -> typing e (term_big_lambda (star p) t) (typ_pourtout (star p) T)

  |typing_app_typ : forall (e:env) (t:term) (T1 T2:typ) (l:nat),
    typing e t (typ_pourtout (star l) T1) -> kinding e T2 (star l) -> typing e (term_app_typ t T2) (tsubst 0 T2 T1).

(* Remarque : chacune des règles conserve les indices de Bruijn : on n'a pas besoin de faire des décalages *)

(* Question 5 *)

(* On peut décider si deux kinds k et l sont égaux *)
Lemma kind_eq_dec : forall (k l :kind), {k=l} + {k<>l}.
Proof.
decide equality; decide equality.
Qed.

(* On peut décider si deux types T et U sont égaux *)
Lemma typ_eq_dec : forall (T U :typ), {T=U} + {T<>U}.
Proof.
decide equality; decide equality; decide equality.
Qed.



Fixpoint infer_kind (e:env) (T:typ) :=
  match T with
    |typ_var X => if wf_env e then get_kind X e else None
    |typ_pourtout (star q) T1 => match infer_kind (declare_kind (star q) e) T1 with 
          |None => None 
          |Some (star p) => Some (star(max p q + 1))
          end
    |typ_fleche T1 T2 => match (infer_kind e T1, infer_kind e T2) with
          |(Some (star p), Some (star q)) => Some (star (max p q))
          |_ => None
          end
     end.

Fixpoint infer_type (e:env) (t:term) :=
  match t with
   |term_var x => if wf_env e then get_type x e else None
   |term_small_lambda T t1 => match infer_type (declare_typ T e) t1 with
     |Some(U) => Some (typ_fleche T U)
     |None => None
     end
   |term_app_term t1 t2 => match (infer_type e t1, infer_type e t2) with
     |(Some (typ_fleche T1 T2), Some T3) => match typ_eq_dec T1 T3 with
       | left(_) => Some T2 (* T1 = T3 *)
       |_ => None
       end
     |_ => None
     end
   |term_big_lambda k t1 => match infer_type (declare_kind k e) t1 with
     |Some T => Some (typ_pourtout k T)
     |_ => None
     end
   |term_app_typ t1 T2 => match (infer_type e t1, infer_kind e T2) with
     |(Some (typ_pourtout k1 T1), Some (k2)) => match kind_eq_dec k1 k2 with
       |left(_) => Some (tsubst 0 T2 T1) (* k1 = k2 *)
       |_ => None end
     |_ => None
     end
  end.


Lemma kinference_correct : forall (T:typ) (e:env), 
  forall r, infer_kind e T = Some (star r) -> kinding e T (star r).
induction T.
- intros e r infer. simpl. inversion infer. 
  split.
  + exists r. split.
    now destruct (wf_env e). trivial.
  + destruct (wf_env e). trivial. discriminate.
- intros e max_pq infer. simpl.
  inversion infer.
  specialize (IHT1 e); specialize (IHT2 e).
  destruct (infer_kind e T1) as [k1 |]. destruct (infer_kind e T2) as [k2|].
  + destruct k1 as [p]. destruct k2 as [q].
    exists p,q.
    split. now apply IHT1. split. now apply IHT2. now injection H0.
  + destruct k1 as [p]. discriminate.
  + discriminate.
- intros e max_pq_plus1 infer. simpl. destruct k as [q].
  cut (exists p : nat, infer_kind (declare_kind (star q) e) T = Some (star p) /\ max_pq_plus1 = max p q + 1).
  intro. destruct H as [p].
  exists p. split.
  now apply IHT. apply H.
  inversion infer.
  destruct (infer_kind (declare_kind (star q) e) T) as [k1|]. destruct k1 as [n].
  + exists n. split. trivial. congruence.
  + discriminate H0.
Qed.
    
  
Lemma tinference_correct : forall (t:term) (e:env) (T:typ), 
  infer_type e t = Some (T) -> typing e t T.
induction t as [|T1|t1|k t|t Heq T2].
- intros e T infer. simpl. inversion infer.
  split.
  + now destruct (wf_env e).
  + destruct (wf_env e). trivial. discriminate.
- intros e T1T2 infer. simpl; inversion infer.
  destruct T1T2 as [|T1' T2|].
  + destruct (infer_type (declare_typ T1 e) t); discriminate; discriminate.
  + destruct (infer_type (declare_typ T1 e) t) as [T3|].
    split. injection H0. intros. now rewrite H1.
    apply IHt. inversion infer.
    destruct (infer_type (declare_typ T1 e) t) as [T4|].
    injection H1. intros. now rewrite H.
    discriminate.
    discriminate.
  + destruct (infer_type (declare_typ T1 e) t). discriminate. discriminate.
- intros e T2 infer. simpl. inversion infer.
  remember (infer_type e t1) as T1T2.
  destruct T1T2 as [T1T2|_].
  destruct T1T2 as [|T1' T2'|].
  + discriminate.
  + exists T1'. split.
    * apply IHt1; destruct (infer_type e t2) as [T|]. destruct (typ_eq_dec T1' T).
      congruence. discriminate. discriminate.
    * apply IHt2. destruct (infer_type e t2) as [T|]. destruct (typ_eq_dec T1' T).
      congruence. discriminate. discriminate.
  + discriminate.
  + discriminate.
- intros e T infer. simpl. inversion infer. destruct k. destruct T as [| |].
  + destruct (infer_type (declare_kind (star n) e) t);discriminate.
  + destruct (infer_type (declare_kind (star n) e) t); discriminate.
  + remember (infer_type (declare_kind (star n) e) t) as T'.
    destruct T' as [T1|].
    * destruct k as [m]. split.
      congruence.
      apply IHt. congruence.
    * discriminate.
- intros e T3 infer. simpl. inversion infer. 
  remember (infer_type e t) as allT1. destruct allT1 as [allT1|]. destruct allT1 as [ | |k T1]. discriminate. discriminate.
  remember (infer_kind e T2) as k1. destruct k1 as [k1|].
  exists k1, T1. split.
  + destruct k1 as [n]. apply kinference_correct. congruence.
  + split.
    * apply Heq. destruct (kind_eq_dec k k1) as [k_k1|]. congruence. discriminate.
    * destruct (kind_eq_dec k k1). injection H0. auto. discriminate.
  + discriminate.
  + discriminate.
Qed.


(* ---- I.2 --- Basic Metatheory ---*)

Definition kle (k1 : kind) (k2 : kind) := match (k1, k2) with
  |(star n, star m) => n <= m
  end.

Infix "<=k" := kle (at level 80).

(* Par rapport à l'énoncé, on change l'ordre de quantification
en mettant e après T, pour que l'hypothèse d'induction soit applicable
à tous les contextes, ce qui est important pour le cas où T est un
type "pour tout" *)
SearchAbout max.
Lemma cumulativity : forall (T:typ) (e:env) (k1 k2:kind),
  kinding e T k1 -> k1 <=k k2 -> kinding e T k2.
Proof.
induction T as [X|T1 IH1 T2 IH2 |k T1 IH];intro e; intros k1 k2 H0 H; destruct k1 as [q];destruct k2 as [s];
compute in H; simpl in H0; simpl.
- destruct H0 as [(p,[H2 H3]) H4]. 
  split; [exists p;split; [apply H2 | omega] | apply H4].
- destruct H0 as (p, (r, [H1 [H2 H3]])).
  assert (p <= q) by (rewrite H3; apply (Nat.le_max_l p r)).
  assert (r <= q) by (rewrite H3; apply (Nat.le_max_r p r)).
  exists s,s; split;
    [apply IH1 with (star p);[apply H1|compute;omega] | 
    split; [apply IH2 with (star r);[apply H2|compute;omega] |];
    symmetry; apply max_idempotent
    ].
- destruct k as [r]. destruct H0 as (p, [H1 H2]).
  assert (p <= max p r) by apply (le_max_l).
  assert (r <= max p r) by apply (le_max_r).
  exists (s-1); split;[apply IH with (star p);[apply H1 |
    change (p<= (s-1)); omega]|
    assert ((max (s-1) r) = s-1) by (apply max_l;omega); omega
    ].
Qed.



  
 
  

  
  
    
      
    

