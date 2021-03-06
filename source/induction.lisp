(IN-PACKAGE :INKA)

;;;;;  this module uses the following ATTRIBUTES in the datastructure WFO:
;;;;;
;;;;;  -  FCTS.SUGGESTED :   a list of functions/predicates suggesting the actual
;;;;;                        well-founded ordering
;;;;;  -  GTERMS.SUGGESTED:  a list of all gterms suggesting the actual well-founded
;;;;;                        ordering


;;; Description how to proceed to determine an induction scheme:
;;;
;;; \begin{enumerate}
;;;  \item  Compute all sets of possible induction variables and sort them according 
;;;         their size.
;;;  \item  Compute all sets of these variables which are compatible wrt. rippling
;;;         (or all if none of them succeeds)
;;;  \item  Compute all sets of variables which may be joinded to one induction 
;;;         scheme. (or all if none of them succeeds)
;;;  \item  Take the first and add all additional case splits needed to evaluate 
;;;         the occurrences of some variable.
;;; \end{enumerate}


(defun ind-induction (gterm &optional already.used.terms conditions)

  ;;; Input  :  a gterm, denoting a negated formula to be proven
  ;;; Effect :  computes an appropriate induction scheme for \verb$GTERM$, creates 
  ;;;           gterms denoting the induction hypotheses.
  ;;; Value:    a description of the induction hypotheses

  (let ((wfos (ind=select.appropriate.scheme (ind=gterm.compute.applicable.schemes gterm already.used.terms) gterm 
					     (mapcar #'(lambda (x) (da-formula.negate x)) conditions))))
    (cond (wfos 
	   (setq wfos (ind=merge.compatible.wfos (ind=wfo.delete.subsumed.wfos wfos)))
	   (ind=gterm.create.final.ind.scheme 
	    gterm (ind=merge.with.partial.orderings gterm (car wfos)))))))


(defun ind-determine.suggested.wfos (gterm &optional already.used.terms conditions)

  ;;; Input  :  a gterm, denoting a negated formula to be proven
  ;;; Effect :  computes an appropriate induction schemes for \verb$GTERM$
  ;;; Value  :  a list of wfos'

  (ind=collect.all.schemes (ind=gterm.compute.applicable.schemes gterm already.used.terms) gterm conditions))


(defun ind-wfo.instantiate (wfo actual.parameters)

  ;;; Input: a wfo and a list of parameters
  ;;; Value: instantiates \verb$WFO$ with the list of parameters \verb$ACTUAL.PARAMETERS$

  (ind=wfo.instantiate wfo actual.parameters nil nil nil))


(defun ind-apply.wfo (gterm wfo)

  ;;; Input  :  a gterm, denoting a negated formula to be proven, and a well-founded ordering
  ;;; Effect :  creates gterms denoting the induction hypotheses.
  ;;; Value:    A description of the induction hypotheses.

  (ind=gterm.create.final.ind.scheme gterm wfo))


(defun ind=gterm.create.final.ind.scheme (gterm wfo)

  (let (replacement parameters)
    (setq parameters (ind=gtermlist.skolem.constants (da-wfo.parameters wfo)))
    (cond ((neq 'fail (setq replacement (norm-gn.compute.replacement gterm parameters)))
	   (values (ind=wfo.create.hypotheses (da-wfo.tree wfo) replacement nil)
		   (getf (da-wfo.attributes wfo) 'gterms.suggested))))))



;;;;;=======================================================================================
;;;;;
;;;;;   Chapter 2
;;;;;   -------
;;;;;
;;;;;   Computation of induction sets which have appropriate induction schemes.
;;;;;
;;;;;=======================================================================================



;;; Intermediate structure to compute the best schemes:
;;;
;;; <param_descr>           ::=  (<param> <set_of_ind_schemes> <set_of_case_analyses> <malus_rippling> <malus_case>)
;;; <param>                 ::=  any gterm consisting of skolem constants and constructors
;;; <set_of_ind_schemes>    ::=  <ind.scheme>*
;;; <ind.scheme>            ::=  (<malus_rippling> <taf> <suggested.wfo> <ind.params> <case.params>)
;;; <malus_rippling>        ::=  <number>
;;; <ind.params>            ::=  <gterm>*
;;; <case.params>           ::=  <gterm>*


(defun ind=select.appropriate.scheme (schemes gterm conditions)

  ;;; Input:   a list of tupels (ind.term induction.schemes case.analysis.schemes ???_)
  ;;; Effect:  selects a subset of schemes according to some heuristics and instantiates them

  (let (selected.schemes)
    (mapc #'(lambda (scheme)
	      (cond ((and (second scheme) (null (third scheme))
			  (or (null selected.schemes)
			      (< (fourth scheme) (fourth selected.schemes))))
		     (setq selected.schemes scheme))))
	  schemes)
    (cond ((null selected.schemes)
	   (mapc #'(lambda (scheme)
		     (cond ((and (third scheme)
				 (or (null selected.schemes)
				     (< (fifth scheme) (fifth selected.schemes))))
			    (setq selected.schemes scheme))))
		 schemes)
	   (cond (selected.schemes
		  (mapcar #'(lambda (scheme)
			      (ind=instantiate.internal.scheme scheme gterm conditions))
			  (third selected.schemes)))))
	  (t (mapcar #'(lambda (scheme)
			 (ind=instantiate.internal.scheme scheme gterm conditions))
		     (second selected.schemes))))))


(defun ind=collect.all.schemes (schemes gterm conditions)

  ;;; Input:    a list of tuples (ind.term induction.schemes case.analysis.schemes ???_)
  ;;; Effect:   computes all available induction schemes.

  (mapcan #'(lambda (ind.scheme)
	      (append (ind=wfo.delete.subsumed.wfos
		       (mapcar #'(lambda (scheme)
				   (ind=instantiate.internal.scheme scheme gterm conditions))
			       (second ind.scheme)))
		      (ind=wfo.delete.subsumed.wfos
		       (mapcar #'(lambda (scheme) 
				   (ind=instantiate.internal.scheme scheme gterm conditions))
			       (third ind.scheme)))))
	  schemes))


(defun ind=instantiate.internal.scheme (wfo gterm conditions)

  ;;; Input:  a wfo in its partly instantiated manner
  ;;; Effect: instantiates the case-analysis etc.
  ;;; Value : the completely instantiated scheme
  
  (ind=wfo.instantiate (third wfo) (fourth wfo) (fifth wfo)
		       (ind=wfo.attribute.create
			(da-access (second wfo) gterm)
			(getf (da-wfo.attributes (third wfo)) 'add.cases)
			(da-wfo.parameters (third wfo))
			(fourth wfo))
		       conditions))



(defun ind=gterm.compute.applicable.schemes (gterm already.used.terms)

  ;;; Input:  a gterm
  ;;; Effect:  computes all applicable induction schemes and case analyses and 
  ;;;          inserts them into a global list.
  ;;; Value:   the computed list

  (let* ((tafs (ind=gterm.skolem.term.tafs gterm))
	 (ind.terms (mapcar #'(lambda (taf) (da-access taf gterm)) tafs))
	 checked.tafs ind.schemes wfos sub.term)
    (mapc #'(lambda (taf)
	      (cond ((not (member (cdr taf) checked.tafs :test 'equal))
		     (push (cdr taf) checked.tafs)
		     (setq sub.term (da-access (cdr taf) gterm))
		     (cond ((and (not (member sub.term already.used.terms :test 'uni-gterm.are.equal))
				 (setq wfos (ind=gterm.applicable.wfos.of.taf sub.term (cdr taf) ind.terms)))
			    (mapc #'(lambda (wfo)
				      (cond ((mapc #'(lambda (term)
						       (setq ind.schemes (ind=gterm.insert.scheme 
									  (ind=term.all.subterms term ind.terms)
									  wfo ind.schemes t)))
						   (fourth wfo)))
					    (t (mapc #'(lambda (term)
							 (setq ind.schemes (ind=gterm.insert.scheme 
									    (ind=term.all.subterms term ind.terms)
									    wfo ind.schemes nil)))
						     (fifth wfo)))))
				  wfos))))))
	  tafs)
    (ind=schemes.compute.induction.ranking ind.schemes gterm)
    (ind=schemes.compute.case.analysis.ranking ind.schemes gterm)
    ind.schemes))


(defun ind=term.all.subterms (term termlist)

  ;;; Input:  a term and a list of terms
  ;;; Value:  T iff every element of termlist is no proper subterm of term.

  (remove-duplicates (remove-if #'(lambda (term2)
				    (not (DA-GTERM.OCCURS.IN.GTERM term2 term)))
				termlist)
		     :test #'(lambda(x y) (uni-term.are.equal x y))))


(defun ind=schemes.compute.induction.ranking (ind.schemes gterm)

  ;;; Input:   a list of induction schemes and a gterm
  ;;; Effect:  computes the probability of each induction scheme that the corresponding induction formula
  ;;;          can be proven. This is done by 
  ;;;            -  a rippling analysis (considering the recursive parameters of functions and predicates)
  ;;;            -  if the induction scheme has several induction variables then the sum of all variables 
  ;;;               is considered.

  (mapc #'(lambda (ind.scheme) 
	    (cond ((second ind.scheme) 
		   (setf (fourth ind.scheme) (ind=term.rippling.analysis gterm (car ind.scheme)))))) 
	ind.schemes)
  (mapc #'(lambda (schemes)
	    (mapc #'(lambda (wfo)
		      (let ((sum 0))
			(mapc #'(lambda (param)
				  (incf sum (cond ((some #'(lambda (scheme) 
							     (cond ((uni-gterm.are.equal (car scheme) param) (fourth scheme))))
							 ind.schemes))
						  (t 1000))))
			      (fourth wfo))))
		  (second schemes)))
	ind.schemes))


(defun ind=schemes.compute.case.analysis.ranking (ind.schemes gterm)

  ;;; Input:   a list of case analysis schemes and a gterm
  ;;; Effect:  computes the probability of each case analysis
  ;;;          This is done by 
  ;;;            - considering the maximal symbols of a gterm and prefering case analyses to
  ;;;              remove maximal symbols.

  (let* ((symbols (da-gterm.prefuns gterm))
	 (max.symbols (remove-if-not #'(lambda (prefun)
					 (da-prefun.is.independent prefun (remove prefun symbols)))
				     symbols)))
    (mapc #'(lambda (ind.scheme)
	      (cond ((third ind.scheme) 
		     (setf (fifth ind.scheme) (ind=term.case.analysis.check gterm (third ind.scheme) max.symbols)))))
	  ind.schemes)
    ))


(defun ind=term.case.analysis.check (gterm ind.scheme max.symbols)

  (let ((failures (count-if #'(lambda (scheme)
				(not (member (da-gterm.symbol (da-access (second scheme) gterm))
					     max.symbols)))
			    ind.scheme))
	sum)
    (setq sum (floor (/ (* failures 100) (length ind.scheme))))
    (mapc #'(lambda (scheme)
	      (mapc #'(lambda (term) (cond ((ind=term.check.for.defined.terms term) (incf sum 20)))) (fourth scheme))
	      (mapc #'(lambda (term) (cond ((ind=term.check.for.defined.terms term) (incf sum 20)))) (fifth scheme)))
	  ind.scheme)
    sum))


(defun ind=term.check.for.defined.terms (term)

  ;;; Input:   a term
  ;;; Value:   T, if there is a defined function symbol inside term

  (some #'(lambda (fct)
	    (and (not (da-function.skolem fct))
		 (not (da-function.is.constructor fct))))
	(da-gterm.functions term)))
	    

(defun ind=gterm.insert.scheme (terms wfo schemes ind)

  (let (entry)
    (cond ((cdr terms) (setq ind nil)))
    (mapc #'(lambda (term)
	      (cond ((setq entry (assoc term schemes :test 'uni-gterm.are.equal)))
		    (t (push (list term nil nil 0 0) schemes)
		       (setq entry (car schemes))))
	      (push wfo (nth (cond (ind 1) (t 2)) entry)))
	  terms)
    schemes))



(defun ind=gterm.applicable.wfos.of.taf (term taf ind.terms)

  ;;; Input  : a gterm
  ;;; Effect : computes a list of possible induction orderings of case analyses for this gterm
  ;;; Value:   a list of partially instantiated schemes (which is a list of 5 element:
  ;;;          a natural number indicating the malus of the scheme, a taf indicating the 
  ;;;          subterm causing this scheme, a list of induction variables, a list of case-analysis
  ;;;          variables.

  (let (wfos.suggested actual.rec.params actual.case.params)
    (cond ((and (da-prefun.is (da-gterm.symbol term))
		(setq wfos.suggested (da-prefun.wfo.suggested (da-gterm.symbol term))))
	   (mapcan #'(lambda (wfo.suggested)
		       (setq actual.rec.params
			     (ind=get.actual.rec.parms (da-wfosug.positions wfo.suggested) 
						       (da-gterm.termlist term)))
		       (setq actual.case.params
			     (ind=get.actual.rec.parms (da-wfosug.case.positions wfo.suggested) 
						       (da-gterm.termlist term)))
		       (cond ((and actual.rec.params 
				   (every #'(lambda (actual.par)
					      (not (cdr (ind=term.all.subterms actual.par ind.terms))))
					  actual.rec.params))
			      (cond ((ind-wfo.is.applicable (da-wfosug.wfo wfo.suggested) actual.rec.params ind.terms)
				     (list (list 0 taf (da-wfosug.wfo wfo.suggested) actual.rec.params actual.case.params)))))
			     (t (setq actual.case.params (append actual.rec.params actual.case.params))
				(cond ((ind-wfo.case.is.applicable actual.case.params ind.terms)
				       
				       (list (list 0 taf (ind=wfo.turn.to.case.analysis (da-wfosug.wfo wfo.suggested))
						   nil actual.case.params)))))))
		   wfos.suggested)))))



(defun ind-wfo.case.is.applicable (parameters ind.terms)

  ;;; Input:  the list of actual parameters of a case analysis and a list of possible induction terms
  ;;; Value:  T, if each parameter is either an induction term or contains no defined function symbol.

  (every #'(lambda (parameter)
	     (or (member parameter ind.terms :test #'(lambda (x y) (uni-term.are.equal x y)))
		 (not (ind=term.check.for.defined.terms parameter))))
	 parameters))


(defun ind=wfo.turn.to.case.analysis (wfo)

  ;;; Input:  an induction scheme
  ;;; Value:  a case analysis computed by removing all induction hypotheses (i.e. predecessor sets)

  (da-wfo.create nil 
		 (ind=wfo.tree.turn.to.case.analysis (da-wfo.tree wfo)) 
		 (da-wfo.attributes wfo)
		 nil
		 (append (da-wfo.parameters wfo) (da-wfo.case.parameters wfo))))


(defun ind=wfo.tree.turn.to.case.analysis (tree)

  ;;; Input:  the case analysis tree of an induction scheme
  ;;; Value:  the case analysis tree of the case analysis computed by removing all induction hypotheses (i.e. predecessor sets)

  (cond ((da-wfo.tree.is.leaf tree)
	 (da-wfo.tree.pred.set.create nil))
	(t (da-wfo.tree.create (mapcar #'(lambda (case)
					   (cons (ind=wfo.tree.turn.to.case.analysis (car case))
						 (cdr case)))
				       (da-wfo.tree.subnodes tree))))))
		 
(defun ind=gterm.skolem.term.tafs (gterm &optional taf)

  ;;; Input:   a gterm
  ;;; Effect:  computes maximal subterms of gterm such that this term contains
  ;;;          only skolem-constants and constructor-symbols.
  ;;; Value:   a list of tafs.

  (let ((symbol (da-gterm.symbol gterm)))
    (cond ((null (da-gterm.termlist gterm))
	   (cond ((and (da-function.is symbol)
		       (da-function.skolem symbol))
		  (values (list taf) t))
		 ((and (da-function.is symbol)
		       (da-function.is.constructor symbol))
		  (values nil t))
		 (t (values nil nil))))
	  (t (let ((new.taf (da-taf.create.zero taf))
		   (all.skolem t) all.tafs)
	       (mapc #'(lambda (subterm)
			 (setq new.taf (da-taf.create.next new.taf))
			 (multiple-value-bind (tafs skolem.is)
			     (ind=gterm.skolem.term.tafs subterm new.taf)
			   (setq all.tafs (append tafs all.tafs))
			   (setq all.skolem (and all.skolem skolem.is))))
		     (da-gterm.termlist gterm))
	       (cond ((and (da-function.is symbol)
			   (da-function.is.constructor symbol)
			   all.skolem)
		      (values (cond (all.tafs (list taf))) t))
		     (t (values all.tafs nil))))))))


;;;;;=======================================================================================
;;;;;
;;;;;   Chapter 3
;;;;;   --------
;;;;;
;;;;;   Filter for possible induction schemes by rippling posibities.
;;;;;
;;;;;    Check that rippling is enabled for choosen var-set.
;;;;;
;;;;;=======================================================================================



(defun ind=term.rippling.analysis (gterm ind.term)

  ;;; Input:  a gterm and a induction term
  ;;; Effect: computes the probability the corresponding induction formula can be proven
  ;;;         by considering whether all occurring wave-fronts occur inside recursive 
  ;;;         arguments.
  ;;; Value   a multiple value: the computed malus and a flag indicating whether still a
  ;;;         a wave front exists after rippling.

  (cond ((uni-gterm.are.equal gterm ind.term) (values 0 t))
	((null (da-gterm.termlist gterm)) (values 0 nil))
	(t (let ((counter 0) (sum 0) glob.rippl central.rippl rec.pos commutative)
	     (cond ((da-prefun.is (da-gterm.symbol gterm))
		    (setq commutative (or (DA-SYMBOL.HAS.ATTRIBUTE (da-gterm.symbol gterm) 'commutative)
					  (DA-SYMBOL.HAS.ATTRIBUTE (da-gterm.symbol gterm) 'symmetric)))
		    (setq rec.pos (DA-prefun.rec.positions (da-gterm.symbol gterm)))
		    (setq central.rippl (GETF (DA-PREFUN.ATTRIBUTES (da-gterm.symbol gterm)) 'CENTRAL.REC))))
	     (mapc #'(lambda (subterm)
		       (incf counter)
		       (multiple-value-bind (malus rippl) (ind=term.rippling.analysis subterm ind.term)
			 (incf sum malus)
			 (cond (rippl 
				(cond ((and rec.pos (not (member counter rec.pos)) (not commutative))
				       (incf sum (cond ((uni-gterm.are.equal subterm ind.term) 100) (t 50))))
				      ((and (null rec.pos) 
					    (da-function.is (da-gterm.symbol gterm))
					    (or (da-function.is.selector (da-gterm.symbol gterm))
						(da-function.is.constructor (da-gterm.symbol gterm))))
				       (incf sum 200))
				      ((null rec.pos) (incf sum 30)))))
			 (setq glob.rippl (or glob.rippl rippl))))
		   (da-gterm.termlist gterm))
	     (values sum (and (null central.rippl) glob.rippl))))))


;;;;;=========================================================================================
;;;;;
;;;;; Chapter 2b
;;;;; ----------
;;;;;
;;;;; functions to instantiate an well-founded ordering
;;;;;
;;;;;=========================================================================================



(DEFUN IND-WFO.IS.APPLICABLE (WFO ACTUAL.REC.PARS &optional ind.terms)

  ;;; Input  : an induction \verb$WFO$ and the actual recursion parameters
  ;;; Effect : tests, whether the \verb$WFO$ is applicable on the given parameters, e.g. whether
  ;;;          \begin{itemize}
  ;;;          \item each actual recursion parameter is either a skolem-constant or in an unchangeable position
  ;;;          \item  each skolem constant in an changeable position occurs only once
  ;;;          \end{itemize}
  ;;; Value  : T, iff the check is fulfilled.

  (LET (UNCH.SKOLEMS CH.SKOLEMS)
    (COND ((EVERY #'(LAMBDA (FORM.PAR ACT.REC.PAR)
		      (OR (NOT (MEMBER FORM.PAR (DA-WFO.CHANGEABLES WFO)))
			  (COND (IND.TERMS
				 (MEMBER ACT.REC.PAR IND.TERMS :TEST #'UNI-GTERM.ARE.EQUAL))
				(T (DA-SYMBOL.SKOLEM.CONSTANT.IS (DA-TERM.SYMBOL ACT.REC.PAR))))))
		  (DA-WFO.PARAMETERS WFO) ACTUAL.REC.PARS)
	   (MAPC #'(LAMBDA (FORM.PAR ACT.REC.PAR)
			(COND ((MEMBER FORM.PAR (DA-WFO.CHANGEABLES WFO))
			       (SETQ CH.SKOLEMS (UNION CH.SKOLEMS (DA-GTERM.FUNCTIONS ACT.REC.PAR 'SKOLEM))))
			      (T (SETQ UNCH.SKOLEMS (UNION UNCH.SKOLEMS (DA-GTERM.FUNCTIONS ACT.REC.PAR 'SKOLEM))))))
		 (DA-WFO.PARAMETERS WFO) ACTUAL.REC.PARS)
	   (NULL (INTERSECTION CH.SKOLEMS UNCH.SKOLEMS))))))



;;;;;=======================================================================================
;;;;;
;;;;; Chapter 2b
;;;;; ----------
;;;;;
;;;;; functions to instantiate an well-founded ordering
;;;;;
;;;;;========================================================================================


(DEFUN IND=WFO.INSTANTIATE (WFO ACTUAL.PARS ACTUAL.CASE.PARS ATTRIBUTES conditions)

  ;;; input  : an well-founded ordering and a list of all actual recursion parameters.
  ;;; effect : creates an instance of WFO in regard to the actual.rec.pars. This instantiated WFO
  ;;;          is minimized, e.g. all superfluous nodes are removed.
  ;;; value  : the instantiated WFO.

  (LET (TREE)
    (COND ((and (setq TREE (IND=WFO.TREE.INSTANTIATE (DA-WFO.TREE WFO)
						     (UNI-TERMSUBST.CREATE.PARALLEL (APPEND (DA-WFO.PARAMETERS WFO)
											    (DA-WFO.CASE.PARAMETERS WFO))
										    (APPEND ACTUAL.PARS ACTUAL.CASE.PARS))
						     conditions
						     (ind=merge.add.match.lits
						      conditions
						      (mapcar #'(lambda (x) (cons (da-term.create x) nil))
							      (DA-GTERM.CONSTANTS (Da-gterm.create 'and ACTUAL.PARS)
										  'SKOLEM))
						      t)))
		(not (ind=wfo.tree.contains.variables.in.case.conditions tree)))
	   (setq tree (ind=wfo.restructure.tree tree nil (mapcar #'(lambda (x) (cons (da-term.create x) nil))
							     (DA-GTERM.CONSTANTS (Da-gterm.create 'and ACTUAL.PARS)
										 'SKOLEM))))
	   (DA-WFO.CREATE ACTUAL.PARS TREE ATTRIBUTES NIL ACTUAL.CASE.PARS)))))


(defun ind=wfo.tree.contains.variables.in.case.conditions (tree)

  ;;; Input  : a wfo tree
  ;;; Effect : looks up for case conditions containing variables
  ;;; Value  : an sexpression =/= nil if some case condition has been found; otherwise NIL

  (cond ((da-wfo.tree.is.leaf tree) nil)
	(T (or (some #'(lambda (subnode)
			 (some #'(lambda (lit) 
				   (da-gterm.variables lit))
			       (cdr subnode)))
		     (da-wfo.tree.subnodes tree))
	       (some  #'(lambda (subnode)
			  (ind=wfo.tree.contains.variables.in.case.conditions (car subnode)))
		     (da-wfo.tree.subnodes tree))))))
			     


(DEFUN IND=WFO.TREE.INSTANTIATE (WFO.TREE TERM.SUBST &OPTIONAL CONDITIONS PAR.BOUND.TERMS)

  ;;; Input:   a tree of a wfo (see. DA) and two lists of terms
  ;;; Effect:  instantiates wfo.term by replacing FORM.PARS by ACTUAL.PARS. In case of 
  ;;;          induction on terms additional case analyses are inserted.
  ;;; Value:   the instantiated wfo-tree.
  
  (LET (NEW.CASES REPR.CASE CONDS)
    (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	   (IND=WFO.TREE.LEAF.INSTANTIATE WFO.TREE TERM.SUBST CONDITIONS PAR.BOUND.TERMS))
	  (T (SETQ NEW.CASES
		   (MAPCAN #'(LAMBDA (CASE)
			       (SETQ CONDS (MAPCAR #'(LAMBDA (LIT)
						       (IND=SIMPLIFY.CONDITION.1 
							CONDITIONS
							(UNI-TERMSUBST.APPLY TERM.SUBST LIT)
							PAR.BOUND.TERMS))
						   (CDR CASE)))
			       (COND ((NOT (SOME #'(lambda (lit) (da-formula.is.true lit)) CONDS))
				      (setq conds (REMOVE-IF #'(LAMBDA (X) 
								 (DA-FORMULA.IS.FALSE X))
							     CONDS))
				      (LIST (CONS (IND=WFO.TREE.INSTANTIATE 
						   (CAR CASE) TERM.SUBST (Append CONDITIONS CONDS)
						   (IND=MERGE.ADD.MATCH.LITS 
						    CONDS PAR.BOUND.TERMS T))
						  CONDS)))))
			   (DA-WFO.TREE.SUBNODES WFO.TREE)))
	   (COND ((SETQ REPR.CASE (FIND-IF #'(LAMBDA (CASE) (NULL (CDR CASE))) NEW.CASES))
		  (CAR REPR.CASE))
		 (T (DA-WFO.TREE.CREATE NEW.CASES)))))))


(defun ind=wfo.restructure.tree (wfo.tree conditions par.bound.terms)

  (cond ((DA-WFO.TREE.IS.LEAF WFO.TREE) wfo.tree)
	(t (let (subtree)
	     (cond ((setq subtree (some #'(lambda (par.bound.term)
					    (ind=wfo.search.for.match.case wfo.tree par.bound.term))
					(ind=bound.terms.in.case.analysis wfo.tree par.bound.terms)))
		    (ind=wfo.restructure.tree (ind=wfo.restructure.tree.1 wfo.tree subtree conditions par.bound.terms)
					      conditions par.bound.terms))
		   (t (mapc #'(lambda (case)
				(setf (car case)
				      (ind=wfo.restructure.tree (car case) (append conditions (CDR CASE))
								(IND=MERGE.ADD.MATCH.LITS (CDR CASE) PAR.BOUND.TERMS T))))
			    (DA-WFO.TREE.SUBNODES WFO.TREE))
		      wfo.tree))))))


(defun ind=wfo.restructure.tree.1 (wfo.tree sub.tree conditions par.bound.terms)

  (da-wfo.tree.create (mapcar #'(lambda (sub.tree.case)
				  (cons (ind=wfo.tree.copy.and.replace 
					 wfo.tree sub.tree (car sub.tree.case)
					 (append conditions (cdr sub.tree.case))
					 (ind=merge.add.match.lits (cdr sub.tree.case) par.bound.terms t))
					(cdr sub.tree.case)))
			      (DA-WFO.TREE.SUBNODES sub.tree))))



(defun ind=wfo.tree.copy.and.replace (wfo.tree old.tree new.tree conditions par.bound.terms)

  (cond ((da-wfo.tree.is.leaf wfo.tree)
	 (da-wfo.tree.pred.set.create (da-wfo.tree.pred.set wfo.tree)))
	((neq wfo.tree old.tree)
	 (let (new.cases repr.case CONDS)
	   (setq new.cases (MAPCAN #'(LAMBDA (CASE)
				       (SETQ CONDS (MAPCAN #'(LAMBDA (LIT)
							       (let ((result (IND=SIMPLIFY.CONDITION.1 CONDITIONS LIT PAR.BOUND.TERMS)))
								 (cond ((DA-FORMULA.IS.FALSE result) nil)
								       (t (list (eg-eval lit))))))
							   (CDR CASE)))
				       (COND ((NOT (SOME #'(lambda (lit) (da-formula.is.true lit)) CONDS))
					      (LIST (CONS (ind=wfo.tree.copy.and.replace
							   (CAR CASE) old.tree new.tree
							   (Append CONDITIONS CONDS)
							   (IND=MERGE.ADD.MATCH.LITS CONDS PAR.BOUND.TERMS T))
							  conds)))))
				   (DA-WFO.TREE.SUBNODES WFO.TREE)))
	   (cond ((setq repr.case (find-if #'(lambda (case) (null (cdr case))) new.cases)) (car repr.case))
		 (t (da-wfo.tree.create new.cases)))))
	(t new.tree)))


(defun ind=wfo.search.for.match.case (wfo.tree term)
 
  (let (new.term)
    (cond ((da-wfo.tree.is.leaf wfo.tree) nil)
	  ((and (setq new.term (da-literal.is.normalized.match (second (car (DA-WFO.TREE.SUBNODES WFO.TREE))) (da-sign.minus)))
		(uni-gterm.are.equal new.term term))
	   wfo.tree)
	  (t (some #'(lambda (case)
		       (ind=wfo.search.for.match.case (car case) term))
		   (DA-WFO.TREE.SUBNODES WFO.TREE))))))


(defun ind=bound.terms.in.case.analysis (wfo.tree par.bound.terms)

  ;;; Input:  a wfo.tree and a list of all parameter bound terms
  ;;; Value:  a list of parameter bound terms that occur inside some (non-match-literal) condition.

  (let (terms term)
    (mapc #'(lambda (case)
	      (mapc #'(lambda (lit)
			(cond ((and (setq term (da-literal.is.normalized.match lit (da-sign.minus)))
				    (assoc term par.bound.terms :test 'uni-gterm.are.equal)))
			      (t (setq terms (remove-if-not #'(lambda (par.bound.term)
								(or (member par.bound.term terms)
								    (da-gterm.occurs.in.gterm (car par.bound.term) lit)))
							  par.bound.terms)))))
		  (cdr case)))
	(DA-WFO.TREE.SUBNODES WFO.TREE))
    (mapcar #'car terms)))
  
			     


(DEFUN IND=WFO.TREE.LEAF.INSTANTIATE (LEAF TERM.SUBST CONDITIONS PAR.BOUND.TERMS)

  ;;; Input  :  a leaf of a wfo.tree, and a term substitution
  ;;; Effect :  instantiates the predecessor-set
  ;;; Value  :  the instantiated predecessor-set

  (LET (PRED.SETS)
    (SETQ PRED.SETS (MAPCAR #'(LAMBDA (SUBST)
				(MAPCAR #'(LAMBDA (TERM)
					    (LET ((NEW.TERM (UNI-TERMSUBST.APPLY TERM.SUBST TERM)))
					      (SETF (GETF (DA-TERM.ATTRIBUTES NEW.TERM) 'REC)
						    (GETF (DA-TERM.ATTRIBUTES TERM) 'REC))
					      NEW.TERM))
					SUBST))
			    (DA-WFO.TREE.PRED.SET LEAF)))
    (IND=WFO.ANALYSIS.FOR.CASE.ANALYSIS PRED.SETS CONDITIONS PAR.BOUND.TERMS)))



(DEFUN IND=WFO.ANALYSIS.FOR.CASE.ANALYSIS (PRED.SETS CONDITIONS PAR.BOUND.TERMS)

  (LET (CASE.ANALYSIS list new.symb)
    (setq pred.sets (remove-if #'(lambda (pred.set)
				   (SOMEF #'(LAMBDA (ACTUAL.PAR REPLACEMENT)
					      (setq new.symb (da-gterm.symbol  (ind=simplify.gterm REPLACEMENT PAR.BOUND.TERMS)))
					      (and (neq (da-gterm.symbol ACTUAL.PAR) new.symb)
						  (da-function.is (da-gterm.symbol ACTUAL.PAR))
						  (da-function.is new.symb)
						  (da-function.is.constructor (da-gterm.symbol ACTUAL.PAR))
						  (da-function.is.constructor new.symb)))
					 PRED.SET))
			      PRED.SETS))							      
    (COND ((SOME #'(LAMBDA (PRED.SET)
		     (SOMEF #'(LAMBDA (ACTUAL.PAR REPLACEMENT)
				(setq list (IND=WFO.REPLACEMENT.IS.INSTANCE 
					    ACTUAL.PAR (ind=simplify.gterm REPLACEMENT PAR.BOUND.TERMS)))
				(COND ((and (eq (car list) 'fail) (null (cdr list))))
				      ((eq (car list) 'fail)
				       (SETQ CASE.ANALYSIS
					     (IND=WFO.CREATE.CASE.ANALYSIS 
					      pred.sets CONDITIONS PAR.BOUND.TERMS list PRED.SET)))))
			    PRED.SET))
		 PRED.SETS)
	   (cond (CASE.ANALYSIS) (t (da-wfo.tree.pred.set.create nil))))
	  (T (da-wfo.tree.pred.set.create PRED.SETS)))))



(DEFUN IND=WFO.REPLACEMENT.IS.INSTANCE (ACTUAL.PAR REPLACEMENT &OPTIONAL ASSOC.LIST)

  ;;; Input:  actual.par is a term constructed from skolem constants and constructors
  ;;;         replacement is it predecessor with respect to the underlying ordering
  ;;; Effect: checks whether actual.par is an instance of replacement keeping in mind
  ;;;         that additional case analysis of some term may be necessary

  (let (ENTRY)
  (COND ((DA-SYMBOL.SKOLEM.CONSTANT.IS (DA-GTERM.SYMBOL ACTUAL.PAR))
	 (COND ((SETQ ENTRY (ASSOC (DA-GTERM.SYMBOL ACTUAL.PAR) ASSOC.LIST))
		(COND ((UNI-GTERM.ARE.EQUAL REPLACEMENT (CDR ENTRY))
		       ASSOC.LIST)
		      (T (LIST 'FAIL))))
	       (T (CONS (CONS (DA-GTERM.SYMBOL ACTUAL.PAR) REPLACEMENT) ASSOC.LIST))))
	((EQ (DA-GTERM.SYMBOL ACTUAL.PAR) (DA-GTERM.SYMBOL REPLACEMENT))
	 (EVERY #'(LAMBDA (TERM1 TERM2)
		    (SETQ ASSOC.LIST (IND=WFO.REPLACEMENT.IS.INSTANCE TERM1 TERM2 ASSOC.LIST))
		    (NEQ (CAR ASSOC.LIST) 'FAIL))
		(DA-GTERM.TERMLIST ACTUAL.PAR) (DA-GTERM.TERMLIST REPLACEMENT))
	 ASSOC.LIST)
	((and (da-function.is (DA-GTERM.SYMBOL REPLACEMENT))
	      (da-function.is.constructor (DA-GTERM.SYMBOL REPLACEMENT)))
	 (list 'fail))
	(T (LIST 'FAIL ACTUAL.PAR REPLACEMENT)))))


(DEFUN IND=WFO.CREATE.CASE.ANALYSIS (pred.sets CONDITIONS PAR.BOUND.TERMS FAILURE.LIST PRED.SET)

  (let (lit)
    (da-wfo.tree.create
     (mapcar #'(lambda (cons.term)
		 (setq lit (da-literal.create (da-sign.minus) (da-predicate.equality)
					      (list (da-gterm.copy (third failure.list))
						    (da-gterm.copy cons.term))))
		 (list (ind=wfo.analysis.for.case.analysis
			(cond ((eq (da-gterm.symbol (second failure.list)) (da-gterm.symbol cons.term))
			       pred.sets)
			      (t (remove pred.set pred.sets)))
			conditions 
			(ind=merge.add.match.lits (list lit) (cons (cons (da-gterm.copy (third failure.list)) nil)
								   PAR.BOUND.TERMS)))
		       lit))
	     (DA-SORT.CREATE.ALL.STRUCTURE.TERMS (third failure.list) nil)))))


;;;;;====================================================================================================
;;;;;
;;;;; Chapter 3.
;;;;; ----------
;;;;;
;;;;; Functions to generate all induction cases.
;;;;;
;;;;;====================================================================================================



(DEFUN IND=WFO.CREATE.HYPOTHESES (WFO.TREE REPLACEMENT &optional CONDITIONS)

  ;;; Input:   a well-founded ordering and a subtree of its tree, a formula and a list of literals
  ;;; Effect:  Steps through WFO.TREE and generates for each leaf a formula denoting the 
  ;;;          induction hypothesis and its govering conditions.
  ;;; Value:   a list of cases, thereby each case is tupel containing: clauses denoting the specific case,
  ;;;          clauses denoting the induction hypotheses, some information for protocol and a possibly empty 
  ;;;          termsubstitution
  ;;;          denoting an adequate instantiation for variables.

  (LET (RESULT)
    (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	   (SETQ RESULT 
		 (IND=WFO.CREATE.HYPOTHESIS REPLACEMENT CONDITIONS 
					    (DA-WFO.TREE.PRED.SET WFO.TREE) (DA-WFO.TREE.PRED.SET.INSTANTIATIONS WFO.TREE)))
	   (COND (RESULT (LIST RESULT))))
	  (T  (MAPCAN #'(LAMBDA (CASE)
			  (IND=WFO.CREATE.HYPOTHESES (CAR CASE) REPLACEMENT
						     (APPEND CONDITIONS (CDR CASE))))
		      (DA-WFO.TREE.SUBNODES WFO.TREE))))))


(DEFUN IND=WFO.CREATE.HYPOTHESIS (REPLACEMENT CONDITIONS PRED.SET INSTANTIATIONS)

  ;;; Input:   a replacement, a list of literals, a list of terms denoting the parameter of the wfo and
  ;;;          a set of termlists denoting the predecessors.
  ;;; Effect:  creates for each member of pred.set an instantiation of gterm.
  ;;; Value:   A list of two elements: a list of literals describing the actual case and a list of the
  ;;;          replacements describing the hypotheses.

    (LET ((VAR.REPLACEMENT (SUBSETF #'(LAMBDA (X Y) (DECLARE (IGNORE Y)) (DA-VARIABLE.IS X)) REPLACEMENT))
	  (FCT.REPLACEMENT (SUBSETF #'(LAMBDA (X Y) (DECLARE (IGNORE Y)) (DA-FUNCTION.IS X)) REPLACEMENT))
	  NEW.FCT.REPLACEMENT)
      (LIST (MAPCAR #'(LAMBDA (FOR) (NORM-NORMALIZATION (DA-FORMULA.NEGATE FOR))) CONDITIONS)
	    (COND ((LISTP PRED.SET)
		   (MAPCAR #'(LAMBDA (PRED.LIST)
			       (SETQ NEW.FCT.REPLACEMENT FCT.REPLACEMENT)
			       (SOMEF #'(LAMBDA (TERM1 TERM2)
					  (COND ((DA-VARIABLE.IS (DA-TERM.SYMBOL TERM2))
						 (PUSH TERM2 NEW.FCT.REPLACEMENT)
						 (PUSH (DA-TERM.SYMBOL TERM1) NEW.FCT.REPLACEMENT))))
				      PRED.LIST)
			       (LIST (SUBSETF #'(LAMBDA (X Y) (DECLARE (IGNORE X))
						  (NOT (DA-VARIABLE.IS (DA-TERM.SYMBOL Y)))) PRED.LIST)
				     NEW.FCT.REPLACEMENT
				     VAR.REPLACEMENT))
			   PRED.SET)))
	    NIL
	    INSTANTIATIONS)))


;;;;;===================================================================================================
;;;;;
;;;;;   Chapter x
;;;;;   -------
;;;;;
;;;;;   Computation of partial induction orderings based on existencially quantified variables .
;;;;;
;;;;;===================================================================================================



(defun ind=merge.with.partial.orderings (gterm wfo)
  
  (let ((case.analysis (ind=gterm.partial.orderings gterm)))
    (cond (case.analysis (IND=WFO.ADD.PARTIAL.WFO WFO CASE.analysis))
	  (t wfo))))


(DEFUN IND=GTERM.PARTIAL.ORDERINGS (GTERM)

  ;;; Input  : a \verb$GTERM$
  ;;; Value  : a case analysis composed of conditions of an incomplete case analysis with additional instantiation
  ;;;          information for the variables in GTERM

  (LET (RESULT remove.once max.preFUNS)
    (SETQ max.preFUNS (REMOVE-IF #'(LAMBDA (PREFUN)
					(EVERY #'(LAMBDA (TAF)
						   (DA-GTERM.VARIABLES (DA-ACCESS TAF GTERM)))
					       (DA-SYMBOL.OCCURS.IN.GTERM PREFUN GTERM)))
				    (DA-PREFUN.INDEPENDENT.SYMBOLS (DA-GTERM.PREFUNS GTERM))))
    (SETQ RESULT
	  (MAPCAN #'(LAMBDA (TAF)
		      (IND=GTERM.PARTIAL.CASE.ANALYSIS GTERM TAF max.prefuns))
		  (IND=GTERM.VAR.TAFS.IN.REC.POS GTERM)))
    (remove-if #'(lambda (substs.lits1)
		   (some #'(lambda (substs.lits2)
			     (cond ((and (neq substs.lits1 substs.lits2)
					 (not (member substs.lits2 remove.once))
					 (subsetp (cddr substs.lits2) (cddr substs.lits1)
						  :test 'uni-gterm.are.equal))
				    (push substs.lits1 remove.once))))
			 RESULT))
	       result)))


(DEFUN IND=GTERM.VAR.TAFS.IN.REC.POS (GTERM)

  ;;; Input  : a gterm
  ;;; Value  : a list of all tafs to variables of GTERM occuring in recursive positions of some prefun.

  (LET (ALL.TAFS SUBTERM)
    (MAPC #'(LAMBDA (VAR)
	      (MAPC #'(LAMBDA (TAF)
			(SETQ SUBTERM (DA-ACCESS (CDR TAF) GTERM))
			(COND ((MEMBER (CAR TAF) (DA-PREFUN.REC.POSITIONS (DA-GTERM.SYMBOL SUBTERM)))
			       (PUSH TAF ALL.TAFS))))
		    (DA-SYMBOL.OCCURS.IN.GTERM VAR GTERM)))    
	  (DA-GTERM.VARIABLES GTERM))
    ALL.TAFS))


(DEFUN IND=GTERM.PARTIAL.CASE.ANALYSIS (GTERM TAF max.prefuns)

  ;;; Input  : a gterm (i.e. the negated theorem), a variable of this gterm and a taf to an 
  ;;;          occurrence of this variable in GTERM in a recursive position.
  ;;; Effect : using the base.case conditions of the prefun having this occurence of VARIABLE
  ;;;          in a recursive position two find adequate instantiations of the variable to 
  ;;;          evaluate the prefun. Then tries to simplify the resulting formula.
  ;;; Value  : a case.analysis, which is a dotted pair:
  ;;;            (subst_1 ... subst_n) . (OR condition_1 ... condition_n)
  ;;;          where subst_i is an adequate instantiation of the variables of GTERM, when 
  ;;;          trying to refute GTERM under condition condition_i.

  (LET ((vars (da-gterm.variables gterm)) new.gterm subst cases rec.substs)
    (multiple-value-setq (cases rec.substs) (IND=GTERM.SIMPLE.EVALUATION.CONDITIONS GTERM TAF))
    (MAPCAN #'(LAMBDA (subst.CONDITION)
		(multiple-value-setq (new.gterm subst)
		   (Sel-Gterm.Simplify
		    (da-formula.junction.closure 
		     'and
		     (append (mapcar #'(lambda (for)
					 (da-formula.negate for))
				     (cdr subst.CONDITION))
			     (list (uni-termsubst.apply (car subst.condition) (da-gterm.copy gterm)))))
		    (car subst.CONDITION)))
		(ind=gterm.case.analysis.extract.substs.and.cases new.gterm subst max.prefuns vars rec.substs))
	    cases)))


(DEFUN IND=GTERM.SIMPLE.EVALUATION.CONDITIONS (GTERM TAF)

  ;;; Input  : a gterm and a taf denoting a recursive position of some prefun
  ;;; Effect : computes out from the definition of the denoted prefun a formula in DNF,
  ;;;          denoting all base case conditons of the prefun.
  ;;; Value  : the computed formula

  (LET ((SUBGTERM (DA-ACCESS (DA-TAF.SUPER.TAF TAF) GTERM))
	SYMBOL subst)
    (SETQ SYMBOL (DA-GTERM.SYMBOL SUBGTERM))
    (COND ((and (da-prefun.is symbol) (DA-PREFUN.DEFINITION SYMBOL))
	   (setq subst (UNI-TERMSUBST.CREATE.PARALLEL 
			(MAPCAR #'(LAMBDA (VARIABLE) (DA-TERM.CREATE VARIABLE))
				(DA-PREFUN.FORMAL.PARAMETERS SYMBOL))
			(DA-GTERM.TERMLIST SUBGTERM)))
	   (IND=PREFUN.SIMPLE.EVALUATION.CONDITIONS SYMBOL subst)))))


(DEFUN IND=PREFUN.SIMPLE.EVALUATION.CONDITIONS (PREFUN subst)
 
  ;;; Input  : a prefun
  ;;; Value  : the list of conditions of all base.cases in the definition of prefun.

  (LET (CONDS NEW.SUBST result rec.substs)
    (setq result (DA-GTERM.DEF.MAPCAN.WITH.CONDS 
		  (DA-PREFUN.DEFINITION PREFUN)
		  #'(LAMBDA (DEFINITION CONDITIONS)
		      (SETQ CONDS (MAPCAR #'(LAMBDA (FOR)
					      (UNI-TERMSUBST.APPLY SUBST (DA-GTERM.COPY FOR)))
					  CONDITIONS))
		      (SETQ NEW.SUBST (DA-GTERM.COMPUTE.MATCH.BINDING 
				       (DA-FORMULA.JUNCTION.CLOSURE 'OR CONDS) 'NONE))
		      (COND ((NOT (IND=GTERM.IS.RECURSIVE.FOR.FUNCTION DEFINITION PREFUN))
			     (LIST (CONS NEW.SUBST
					 (MAPCAN #'(LAMBDA (FOR)
						     (SETQ FOR (EG-EVAL (UNI-TERMSUBST.APPLY NEW.SUBST FOR)))
						     (COND ((NOT (DA-GTERM.IS.FALSE FOR)) (LIST FOR))))
						 CONDS))))
			    (t (push new.subst rec.substs)
			       nil)))))
    (values result rec.substs)))
  

(DEFUN IND=GTERM.IS.RECURSIVE.FOR.FUNCTION (GTERM FUNCTION)

  ;;; See IND=PREFUN.SIMPLE.EVALUATION.CONDITIONS

  (LET (RIGHTSIDE)
    (COND ((EQUALP FUNCTION (DA-GTERM.SYMBOL (CAR (DA-GTERM.TERMLIST GTERM))))
	   (SETQ RIGHTSIDE (CADR (DA-GTERM.TERMLIST GTERM))))
	  (T (SETQ RIGHTSIDE (CAR (DA-GTERM.TERMLIST GTERM)))))
    (COND ((DA-SYMBOL.OCCURS.IN.GTERM FUNCTION RIGHTSIDE) T))))



(DEFUN IND=GTERM.CASE.ANALYSIS.EXTRACT.SUBSTS.AND.CASES (GTERM SUBST MAX.PREFUNS VARS rec.substs)

  (LET (FOR)
    (COND ((SETQ FOR (MAPCAN #'(LAMBDA (CONJUNCT) 
				 (COND ((AND (NULL (DA-GTERM.VARIABLES CONJUNCT))
					     (NOT (INTERSECTION MAX.PREFUNS 
								(DA-PREFUN.INDEPENDENT.SYMBOLS
								 (DA-GTERM.PREFUNS CONJUNCT))))
					     (DA-LITERAL.IS CONJUNCT))
					(LIST (DA-FORMULA.NEGATE CONJUNCT)))))
			     (DA-FORMULA.JUNCTION.OPEN 'AND GTERM)))
	   (LIST (CONS (UNI-TERMSUBST.RESTRICTION SUBST #'(LAMBDA (DOM) (MEMBER (DA-GTERM.SYMBOL DOM) VARS)))
		       (cons rec.substs FOR)))))))




;;;;;===================================================================================================
;;;;;
;;;;;   Chapter x
;;;;;   -------
;;;;;
;;;;;   Elimination of subsumed wfo's .
;;;;;
;;;;;===================================================================================================



(DEFUN IND=WFO.DELETE.SUBSUMED.WFOS (WFOS)
  
  ;;; Input:   a list well-founded orderings
  ;;; Effect:  removes all well-founded ordering which are subsumed by others.
  ;;; Value:   a set of not-subsumed wfo's
  ;;; Notice:  this algorithm is adapted from BM and has to be adjusted to Walter92!

  (let (deleted.wfos)
    (REMOVE-IF #'(LAMBDA (WFO1)
		   (SOME #'(LAMBDA (WFO2)
			     (COND ((AND (NEQ WFO1 WFO2)
					 (not (member wfo2 deleted.wfos))
					 (IND=WFO.SUBSUMES.WFO WFO1 WFO2))
				    (push wfo1 deleted.wfos)
				    (setf (DA-WFO.ATTRIBUTES WFO2)
					  (IND=WFO.MERGE.ATTRIBUTES (DA-WFO.ATTRIBUTES WFO2)
								    (DA-WFO.ATTRIBUTES WFO1)))
				    T)))
			 WFOS))
	       WFOS)))


(DEFUN IND=WFO.SUBSUMES.WFO (WFO1 WFO2)

  ;;; Input:  two well-founded orderings
  ;;; Effect: Computes whether WFO1 is subsumed by WFO2
  ;;;         i.e. the variables of WFO1 are an subset of those of WFO2
  ;;;              and the case analysis of WFO1 is part of those of WFO2.

  (AND (SUBSETP (DA-WFO.PARAMETERS WFO1) (DA-WFO.PARAMETERS WFO2) :TEST #'UNI-TERM.ARE.EQUAL)
       (IND=WFO.TREE.SUBSUMES.TREE (DA-WFO.TREE WFO1) (DA-WFO.TREE WFO2))))


(DEFUN IND=WFO.TREE.SUBSUMES.TREE (WFO.TREE1 WFO.TREE2)

  ;;; Input:  NO1, NO2  - two node numbers
  ;;;         TREE1, TREE2 - two case analysis trees
  ;;; Effect: Computes whether TREE1 is a subtree of TREE2

    (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE1)
	   (IND=WFO.TREE.PRED.SET.IS.IN.LEAVES WFO.TREE2 (DA-WFO.TREE.PRED.SET WFO.TREE1)))
	  ((DA-WFO.TREE.IS.LEAF WFO.TREE2) NIL)
	  ((EVERY #'(LAMBDA (CASE1 CASE2)
		      (COND ((UNI-LITERAL.ARE.EQUAL (CAR (CDR CASE1)) (CAR (CDR CASE2)))
			     (IND=WFO.TREE.SUBSUMES.TREE (CAR CASE1) (CAR CASE2)))))
		  (DA-WFO.TREE.SUBNODES WFO.TREE1) (DA-WFO.TREE.SUBNODES WFO.TREE2)))
	  (T (SOME #'(LAMBDA (CASE)
		       (IND=WFO.TREE.SUBSUMES.TREE WFO.TREE1 (CAR CASE)))
		   (DA-WFO.TREE.SUBNODES WFO.TREE2)))))


(DEFUN IND=WFO.TREE.PRED.SET.IS.IN.LEAVES (WFO.TREE PRED.SET)

  ;;; Input  :  a edge which is a leaf and a second edge, a tree and a recursion substitution

    (COND ((NULL PRED.SET) T)
	  ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	   (cond ((Null  (DA-WFO.TREE.PRED.SET WFO.TREE)) t)
		 (T (IND=PRED.SET.SUBSUMES (DA-WFO.TREE.PRED.SET WFO.TREE) PRED.SET))))
	  (T (SOME #'(LAMBDA (CASE)
			(IND=WFO.TREE.PRED.SET.IS.IN.LEAVES (CAR CASE) PRED.SET))
		    (DA-WFO.TREE.SUBNODES WFO.TREE)))))


(DEFUN IND=PRED.SET.SUBSUMES (PRED.SET.1 PRED.SET.2)

  ;;; Input:   two sets of predecessor substitutions
  ;;; Effect:  computes whether the first set subsumes the second
  ;;;          i.e. each substitution1 of PRED.SET.1 corresponds to a substitution2 in PRED.SET.2
  ;;;          such that each pair old -> new in substitution has a corresponding pair old -> new'
  ;;;          in substitution1 and new occurs in new'.
  ;;; Value:   T if PRED.SET.1 subsumes PRED.SET.2
  
  (COND ((NULL PRED.SET.2) T)
	((< (LENGTH PRED.SET.2) (LENGTH PRED.SET.1)) NIL)
	(T (EVERY #'(LAMBDA (TERM.SUBST.2)
			    (SOME #'(LAMBDA (TERM.SUBST.1)
					    (EVERYF #'(LAMBDA (OLD.2 NEW.2)
							      (SOMEF #'(LAMBDA (OLD.1 NEW.1)
									       (AND (UNI-TERM.ARE.EQUAL OLD.1 OLD.2)
										    (INSIDE NEW.2 NEW.1 :TEST #'UNI-TERM.ARE.EQUAL)))
								     TERM.SUBST.1))
						    TERM.SUBST.2))
				  PRED.SET.1))
		  PRED.SET.2))))


;;;;;===================================================================================================
;;;;;
;;;;;   Chapter n
;;;;;   -------
;;;;;
;;;;;   Merge of compatible wfos
;;;;;
;;;;;===================================================================================================


(DEFUN IND=MERGE.COMPATIBLE.WFOS (WFOS)

  ;;; Input:  a list of well-founded orderings
  ;;; Effect: tries to merge as most wfos as possible.
  ;;; Value:  a reduced list of wfo's

  (setq wfos (sort wfos '> :key #'(lambda (wfo) (ind=wfo.tree.size (da-wfo.tree wfo)))))
  (LET ((WFO (CAR WFOS)))
    (MAPC #'(LAMBDA (OTHER.WFO)
	      (SETQ WFO (COND ((IND=MERGE.TWO.COMPATIBLE.WFOS WFO OTHER.WFO))
			      (T WFO))))
	  (CDR WFOS))
    (LIST WFO)))


(defun ind=wfo.tree.size (wfo)

  (let ((counter 0))
    (cond ((da-wfo.tree.is.leaf wfo) 1)
	  (t (mapc #'(lambda (case)
		       (incf counter (ind=wfo.tree.size (car case))))
		   (da-wfo.tree.subnodes wfo))
	     counter))))


(DEFUN IND=MERGE.TWO.COMPATIBLE.WFOS (WFO1 WFO2)

  ;;; Input:  two well-founded orderings
  ;;; Effect: merges both orderings (in the sense of merging their case analyses and recursive calls
  ;;; Value:  the new well-founded ordering
  
  (let (NEW.TREE)
    (COND ((AND (NULL (SET-DIFFERENCE (DA-WFO.PARAMETERS WFO1) (DA-WFO.PARAMETERS WFO2) :TEST 'UNI-GTERM.ARE.EQUAL))
		(NULL (SET-DIFFERENCE (DA-WFO.PARAMETERS WFO2) (DA-WFO.PARAMETERS WFO1) :TEST 'UNI-GTERM.ARE.EQUAL))
		(SETQ NEW.TREE (IND=MERGE.CASE.TREE (DA-WFO.TREE WFO1) (DA-WFO.TREE WFO2) nil 
						    (MAPCAR #'(LAMBDA (X) (CONS (da-term.create X) NIL))
							    (DA-GTERM.CONSTANTS (Da-gterm.create 'and (DA-WFO.PARAMETERS WFO1))
										'SKOLEM)))))
	   (DA-WFO.CREATE (DA-WFO.PARAMETERS WFO1) NEW.TREE
			  (IND=WFO.MERGE.ATTRIBUTES (da-wfo.attributes WFO1) (da-wfo.attributes WFO2)))))))


(DEFUN IND=MERGE.CASE.TREE (TREE1 TREE2 &OPTIONAL NEG.CONDS PAR.BOUND.TERMS)

  ;;; Input:  two wfo.trees 
  ;;; Effect:  creates a common wfo.tree if both trees agree on their common case analyses
  ;;; Value:  the new wfo.tree
  
  (let (ALL.SUB.TREES SUB.TREE)
  (COND ((DA-WFO.TREE.IS.LEAF TREE1) (IND=MERGE.INSERT.TREE TREE2 TREE1 NEG.CONDS PAR.BOUND.TERMS))
	((DA-WFO.TREE.IS.LEAF TREE2) (IND=MERGE.INSERT.TREE TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS))
	((EVERY #'(LAMBDA (IF.CASE1 IF.CASE2)
		    (IND=MERGE.CASE.DISJUNCTION.ARE.EQUAL (cdr IF.CASE1) (cdr IF.CASE2)))
		(DA-WFO.TREE.SUBNODES TREE1) (DA-WFO.TREE.SUBNODES TREE2))
	 (COND ((EVERY #'(LAMBDA (IF.CASE1 IF.CASE2)
			   (COND ((SETQ SUB.TREE (IND=MERGE.CASE.TREE (car IF.CASE1) (car IF.CASE2)
								      (APPEND (cdr IF.CASE1) NEG.CONDS)
								      (IND=MERGE.ADD.MATCH.LITS (cdr IF.CASE1) PAR.BOUND.TERMS)))
				  (SETQ ALL.SUB.TREES (NCONC ALL.SUB.TREES (LIST SUB.TREE))))))
		       (DA-WFO.TREE.SUBNODES TREE1) (DA-WFO.TREE.SUBNODES TREE2))
		(DA-WFO.TREE.CREATE (MAPCAR #'(LAMBDA (CASE SUB.TREE)
						(cons SUB.TREE (cdr CASE)))
					    (DA-WFO.TREE.SUBNODES TREE1) ALL.SUB.TREES)))))
	(T (IND=MERGE.NON.COMMON.CASES TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS)))))


(DEFUN IND=MERGE.ADD.MATCH.LITS (LITS PAR.BOUND.TERMS &optional insert.always)

  (let (TERM ENTRY)
    (MAPC #'(LAMBDA (LIT)
	      (COND ((AND (SETQ TERM (DA-LITERAL.IS.NORMALIZED.MATCH LIT (DA-SIGN.MINUS)))
			  (cond ((SETQ ENTRY (ASSOC TERM PAR.BOUND.TERMS :TEST 'UNI-GTERM.ARE.EQUAL)))
				(insert.always (setq entry (car (push (cons term nil) PAR.BOUND.TERMS)))))
			  (NULL (CDR ENTRY)))
		     (setq par.bound.terms (copy-tree PAR.BOUND.TERMS))
		     (SETF (CDR (ASSOC TERM PAR.BOUND.TERMS :TEST 'UNI-GTERM.ARE.EQUAL))
			   (second (da-literal.termlist lit)))
		     (mapc #'(lambda (subterm)
			       (push (cons subterm nil) PAR.BOUND.TERMS))
			   (da-term.termlist (second (da-literal.termlist lit)))))))
	  LITS)
    PAR.BOUND.TERMS))


(DEFUN IND=MERGE.TERM.IS.PAR.BOUND (TERM PAR.BOUND.TERMS)

  (ASSOC TERM PAR.BOUND.TERMS :TEST 'UNI-GTERM.ARE.EQUAL))


(DEFUN IND=MERGE.NON.COMMON.CASES (TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS)

  (let ((first.case2 (car (DA-WFO.TREE.SUBNODES tree2)))
	(first.case1 (car (DA-WFO.TREE.SUBNODES tree1)))
	TERM)
    (cond ((AND (SETQ TERM (DA-LITERAL.IS.NORMALIZED.MATCH (car (cdr first.case1)) (da-sign.minus)))
		(IND=MERGE.TERM.IS.PAR.BOUND TERM PAR.BOUND.TERMS))
	   (IND=MERGE.NON.COMMON.CASES.1 TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS))
	  ((AND (SETQ TERM (DA-LITERAL.IS.NORMALIZED.MATCH (car (cdr first.case2)) (da-sign.minus)))
		(IND=MERGE.TERM.IS.PAR.BOUND TERM PAR.BOUND.TERMS))
	   (IND=MERGE.NON.COMMON.CASES.1 TREE2 TREE1 NEG.CONDS PAR.BOUND.TERMS))
	  ((SUBSETP (DA-GTERM.FUNCTIONS (car (cdr first.case1)) 'SKOLEM)
		    (DA-GTERM.FUNCTIONS (car (cdr first.case2)) 'SKOLEM))
	   (IND=MERGE.NON.COMMON.CASES.1 TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS))
	  (T (IND=MERGE.NON.COMMON.CASES.1 TREE2 TREE1 NEG.CONDS PAR.BOUND.TERMS)))))


(DEFUN IND=MERGE.NON.COMMON.CASES.1 (TREE1 TREE2 NEG.CONDS PAR.BOUND.TERMS)

  (LET (ALL.RESULT RESULT)
    (COND ((EVERY #'(LAMBDA (CASE1)
		     (PUSH (CONS (COND ((SETQ RESULT (FIND-IF #'(LAMBDA (CASE2)
								  (IND=wfo.CASE.IS.IMPLIED
								   (APPEND (CDR CASE1) NEG.CONDS)
								   (second CASE2)
								   (IND=MERGE.ADD.MATCH.LITS (cdr CASE1) PAR.BOUND.TERMS)))
							      (DA-WFO.TREE.SUBNODES TREE2)))
					(IND=MERGE.case.tree (CAR CASE1) (car RESULT) 
							     (append (cdr case1) neg.conds)
							     (IND=MERGE.ADD.MATCH.LITS (cdr CASE1) PAR.BOUND.TERMS)))
				       ((ind=merge.case.tree (CAR CASE1) TREE2 (APPEND (CDR CASE1) NEG.CONDS)
							     (IND=MERGE.ADD.MATCH.LITS (cdr CASE1) PAR.BOUND.TERMS))))
				 (CDR CASE1))
			   ALL.RESULT)
		     (CAAR ALL.RESULT))
		  (DA-WFO.TREE.SUBNODES TREE1))
	   (DA-WFO.TREE.CREATE (REVERSE ALL.RESULT))))))
					     

(DEFUN IND=MERGE.CASE.DISJUNCTION.ARE.EQUAL (gterms1 gterms2)

  (every #'(lambda (gterm1 gterm2)
	     (uni-gterm.are.equal gterm1 gterm2))
	 gterms1 gterms2))


(DEFUN IND=MERGE.INSERT.TREE (WFO.TREE PRED.SET NEG.CONDS PAR.BOUND.TERMS)

  (LET (RESULT SIMPL.CONDS repr.case)
    (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	   (IND=MERGE.pred.sets WFO.TREE PRED.SET))
	  ((AND (NULL (DA-WFO.TREE.PRED.SET PRED.SET))       ; do not make a case analysis for a base case
		(ind=wfo.contains.only.pred.sets wfo.tree))  ; if it allows only opening up recursively defined cases.
	   pred.set)
	  ((EVERY #'(LAMBDA (CASE)
		      (SETQ SIMPL.CONDS (remove-if #'(lambda (for) (da-formula.is.false for))
						   (MAPCAR #'(lambda (x) (ind=simplify.condition neg.conds x PAR.BOUND.TERMS)) (cdr CASE))))
		      (cond ((some #'(lambda (for) (da-formula.is.true for)) simpl.conds))
			    (t (PUSH (CONS (IND=MERGE.INSERT.TREE (car CASE) PRED.SET (APPEND SIMPL.CONDS NEG.CONDS)
								  (IND=MERGE.ADD.MATCH.LITS SIMPL.CONDS PAR.BOUND.TERMS))
					   SIMPL.CONDS)
				     RESULT)
			       (CAAR RESULT))))
		  (DA-WFO.TREE.SUBNODES WFO.TREE))
	   (cond ((setq repr.case (find-if #'(lambda (case) (null (cdr case))) result))
		  (car repr.case))
		 (t (DA-WFO.TREE.CREATE (REVERSE RESULT))))))))


(defun ind=wfo.contains.only.pred.sets (wfo.tree)

  (cond ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	 (DA-WFO.TREE.PRED.SET WFO.TREE))
	(t (every #'(lambda (if.clause)
		      (ind=wfo.contains.only.pred.sets (car if.clause)))
		  (DA-WFO.TREE.SUBNODES WFO.TREE)))))


(DEFUN IND=MERGE.pred.sets (PRED.SET1 PRED.SET2)

  (LET (merged.pred.set)
    (COND ((or (null (DA-WFO.TREE.PRED.SET PRED.SET1))
	       (null (DA-WFO.TREE.PRED.SET PRED.SET2)))
	   (DA-WFO.TREE.PRED.SET.CREATE nil (append (da-wfo.tree.pred.set.instantiations PRED.SET1)
						    (da-wfo.tree.pred.set.instantiations PRED.SET2))))
	  ((setq merged.pred.set (remove-if-not #'(lambda (pred1)
						    (some #'(lambda (pred2)
							      (ind=merge.preds.are.equal PRED1 PRED2))
							  (DA-WFO.TREE.PRED.SET PRED.SET2)))
						(DA-WFO.TREE.PRED.SET PRED.SET1)))
	   (cond ((some #'(lambda (pred) 
			    (somef #'(lambda (old term)
				        (not (eq (getf (da-term.attributes term) 'rec) 'cond)))
				   pred))
			merged.pred.set)
		  (DA-WFO.TREE.PRED.SET.CREATE merged.pred.set
					       (append (da-wfo.tree.pred.set.instantiations PRED.SET1)
						       (da-wfo.tree.pred.set.instantiations PRED.SET2)))))))))
  

(DEFUN ind=merge.preds.are.equal (PRED1 PRED2)

  (EVERY #'(LAMBDA (GTERM1 GTERM2) (UNI-GTERM.ARE.EQUAL GTERM1 GTERM2))
	 PRED1 PRED2))


;;;;;===================================================================================================
;;;;;
;;;;;   Chapter n
;;;;;   -------
;;;;;
;;;;;   Merge of partial wfos
;;;;;
;;;;;===================================================================================================


(DEFUN IND=WFO.ADD.PARTIAL.WFO (WFO CASES)

  (let ((tree (DA-WFO.TREE WFO)))
    (MAPC #'(lambda (case)
	      (setq tree (IND=WFO.TREE.ADD.PARTIAL.case tree case)))
	  cases)
    (SETF (DA-WFO.TREE WFO) tree)
    WFO))


(DEFUN IND=WFO.TREE.ADD.PARTIAL.case (WFO.TREE case &optional conds)

  (let (subtree) 
    (cond ((null (cddr case)) 
	   (ind=wfo.propagate.instance wfo.tree nil (car (second case))))
	  ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	   (cond ((ind=wfo.case.is.implied conds (third case))
		  (ind=wfo.propagate.instance wfo.tree nil (car case)))
		 ((ind=wfo.case.is.excluded conds (third case))
		  wfo.tree)
		 (t (setq wfo.tree (ind=wfo.tree.add.case.analysis WFO.TREE (third case) (car case)))
		    (some #'(lambda (if.case)
			      (cond ((uni-gterm.are.equal (second if.case) (third case))
				     (setf (car if.case)
					   (IND=WFO.TREE.ADD.PARTIAL.case (car if.case) 
									  (cons (car case) (cons (second case)
												 (cdddr case)))
									  conds)))))
			  (da-wfo.tree.subnodes wfo.tree))
		    wfo.tree)))
	  ((setq subtree (find-if #'(lambda (if.case)
				      (member (second if.case) (cddr case) :test 'uni-gterm.are.equal))
				  (da-wfo.tree.subnodes wfo.tree)))
	   (ind=wfo.propagate.instance wfo.tree subtree (car case))
	   (setf (cddr case) (remove (second subtree) (cddr case) :test 'uni-gterm.are.equal))
	   (setf (car subtree) (ind=wfo.tree.add.partial.case (car subtree) case (append (cdr subtree) conds)))
	   wfo.tree)
	  (t (mapc #'(lambda (if.case)
		       (setf (car if.case)
			     (IND=WFO.TREE.ADD.PARTIAL.case (car if.case) case (append (cdr if.case) conds))))
		   (da-wfo.tree.subnodes wfo.tree))
	     wfo.tree))))


(defun ind=wfo.propagate.instance (wfo.tree exeption subst)
  
  (cond ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	 (da-wfo.tree.pred.set.create (da-wfo.tree.pred.set wfo.tree) subst))
	(t (mapc #'(lambda (if.case)
		     (cond ((not (eq if.case exeption))
			    (setf (car if.case)
				  (ind=wfo.propagate.instance (car if.case) nil subst)))))
		 (da-wfo.tree.subnodes wfo.tree))
	   wfo.tree)))


(defun ind=wfo.tree.add.case.analysis (WFO.TREE lit subst)

  (da-wfo.tree.create 
   (mapcar #'(lambda (new.lit)
	       (cond ((uni-gterm.are.equal new.lit lit)
		      (list wfo.tree lit))
		     (t (list (da-wfo.tree.pred.set.create nil subst) new.lit))))
	   (cond ((da-literal.is.normalized.match lit (da-sign.minus))
		  (MAPCAR #'(LAMBDA (STRUC.TERM)
			      (DA-LITERAL.CREATE (DA-SIGN.MINUS)
						 (DA-PREDICATE.EQUALITY)
						 (LIST (DA-TERM.COPY (car (da-gterm.termlist lit)))
						       STRUC.TERM)))
			   (DA-SORT.CREATE.ALL.STRUCTURE.TERMS (car (da-literal.termlist lit)) NIL)))
		 (t (list lit (da-formula.negate (da-gterm.copy lit))))))))

	
(DEFUN IND=WFO.CASES.TREE.MERGE (TREE1 TREE2)

  ;;; Input:  two wfo.trees and a substitution which maps the parameters to variables.
  ;;; Effect: creates a wfo.tree for the lexicographical ordering of both.
  ;;; Value:  the new wfo.tree
  
  (COND ((DA-WFO.TREE.IS.LEAF TREE2)
	 (COND ((AND (DA-WFO.TREE.PRED.SET TREE2)
		     (NOT (EQ (DA-WFO.TREE.PRED.SET TREE2) 'INDUCTION.STEP)))
		(IND=WFO.CASES.INSERT.PRED.SET TREE1 (DA-WFO.TREE.PRED.SET TREE2) (DA-WFO.TREE.PRED.SET.INSTANTIATIONS TREE2)))
	       ((EQ (DA-WFO.TREE.PRED.SET TREE2) 'INDUCTION.STEP)
		TREE1)
	       (T (IND=WFO.CASES.INSERT.PRED.SET TREE1 NIL (DA-WFO.TREE.PRED.SET.INSTANTIATIONS TREE2)))))
	(T (DA-WFO.TREE.CREATE
	    (MAPCAR #'(LAMBDA (CASE)
			(CONS (IND=WFO.CASES.TREE.MERGE TREE1 (CAR CASE))
			      (CDR CASE)))
		    (DA-WFO.TREE.SUBNODES TREE2))))))


(DEFUN IND=WFO.CASES.INSERT.PRED.SET (TREE PRED.SET &OPTIONAL INSTANTIATIONS)

  (COND ((DA-WFO.TREE.IS.LEAF TREE)
	 (DA-WFO.TREE.PRED.SET.CREATE
	  (COND ((AND (DA-WFO.TREE.PRED.SET TREE)
		      (NEQ (DA-WFO.TREE.PRED.SET TREE) 'INDUCTION.STEP))
		 (MAPCAR #'(LAMBDA (TERMSUBST)
			     (MAPCAR #'(LAMBDA (X) (DA-TERM.COPY X)) TERMSUBST))
			 PRED.SET))
		((NULL (DA-WFO.TREE.PRED.SET TREE)) NIL)
		(T PRED.SET))
	  (APPEND
	   INSTANTIATIONS
	   (DA-WFO.TREE.PRED.SET.INSTANTIATIONS TREE))))
	(T (DA-WFO.TREE.CREATE
		 (MAPCAR #'(LAMBDA (SUBTREE.CONDITION)
			     (CONS (IND=WFO.CASES.INSERT.PRED.SET (CAR SUBTREE.CONDITION) PRED.SET INSTANTIATIONS)
				   (MAPCAR #'(LAMBDA (FOR) (DA-GTERM.COPY FOR)) (CDR SUBTREE.CONDITION))))
			 (CDR TREE))))))


;;;;;=======================================================================================
;;;;;
;;;;;   Chapter n
;;;;;   -------
;;;;;
;;;;;   Compatibility-check of cases and simplification of cases
;;;;;
;;;;;=======================================================================================


(defun ind=wfo.case.is.excluded (conds neg.lit &optional par.bound.terms)

  ;;; Input:   a list of literals $L_1,..., L_n$, the conjunction of their negations denote a case and a literal $K$
  ;;; Effect:   tests whether $\neg L_1 \vee,.., \vee L_n \to K$ holds.
  ;;; Value:   T, if the implication holds.

  (let (result)
    (rl-with.problem (sel-gterm.simplify 
		      (da-gterm.create
		       'and (cons (da-formula.negate neg.lit)
				  (mapcar #'(lambda (lit) (da-formula.negate lit)) conds)))
		      nil)
		     'gterm
		     #'(lambda (occ)
			 (sel=simpl.gterm occ)
			 (setq result (da-literal.is.false (rl-object occ)))))
     result))


(defun ind=wfo.case.is.implied (neg.conds neg.lit &optional par.bound.terms)

  ;;; Input:   a list of literals $L_1,..., L_n$, the conjunction of their negations denote a case and a literal $K$
  ;;; Effect:   tests whether $\neg L_1 \vee,.., \vee L_n \to \neg K$ holds.
  ;;; Value:   T, if the implication holds.
  
  (let (result)
    (mapc #'(lambda (term.replacement)
	      (cond ((cdr term.replacement)
		     (setq neg.lit (eg-eval (uni-termsubst.apply (uni-termsubst.create nil (car term.replacement) 
										       (cdr term.replacement))
								 neg.lit))))))
	  (reverse par.bound.terms))									      
    (rl-with.problem (sel-gterm.simplify
		      (da-gterm.create 'and
				       (reverse (cons neg.lit
						      (mapcar #'(lambda (lit) (da-formula.negate lit)) neg.conds))))
		      nil)
		     'gterm
		     #'(lambda (occ)
			 (sel=simpl.gterm occ)
			 (setq result (da-literal.is.false (rl-object occ)))))
     result))


(defun ind=simplify.condition (neg.conds neg.lit par.bound.terms)

  (let (result)
    (mapc #'(lambda (term.replacement)
	      (cond ((cdr term.replacement)
		     (setq neg.lit (eg-eval (uni-termsubst.apply (uni-termsubst.create nil (car term.replacement) 
										       (cdr term.replacement))
								 neg.lit))))))
	  (reverse par.bound.terms))
    (DB-WITH.GTERMS.INSERTED (mapcar #'(lambda (x) (da-formula.negate x)) neg.conds)
			     'theorem nil
			     (rl-with.problem neg.lit 'gterm
					      #'(lambda (occ)
						  (sel=simpl.gterm occ)
						  (setq result (rl-object occ)))))
    (cond ((da-literal.is result) result)
	  (t neg.lit))))


(defun ind=simplify.condition.1 (neg.conds neg.lit par.bound.terms)

  (setq neg.lit (norm-normalize.gterm (eg-eval neg.lit)))
  (mapc #'(lambda (term.replacement)
	    (cond ((cdr term.replacement)
		   (setq neg.lit (norm-normalize.gterm (eg-eval (uni-termsubst.apply
								 (uni-termsubst.create nil (car term.replacement) 
										       (cdr term.replacement))
								 neg.lit)))))))
	(reverse par.bound.terms))
  (cond ((some #'(lambda (neg.cond) (uni-gterm.are.equal (norm-normalize.gterm neg.cond) neg.lit)) neg.conds) 
	 (da-literal.false))   ;;; B or B is equal B or False
	((some #'(lambda (neg.cond) (uni-gterm.are.equal (norm-normalize.gterm neg.cond) neg.lit nil 'opposite)) neg.conds) 
	 (da-literal.true))    ;;; B or not B is equal True
	(t neg.lit)))


(defun ind=simplify.gterm (gterm par.bound.terms)

  (mapc #'(lambda (term.replacement)
	    (cond ((cdr term.replacement)
		   (setq gterm (eg-eval (uni-termsubst.apply (uni-termsubst.create nil (car term.replacement) 
										   (cdr term.replacement))
								 gterm))))))
	(reverse par.bound.terms))
    (eg-eval gterm))

;;;;;====================================================================================================================
;;;;;
;;;;;  Functions to handle attributes of well-founded orderings
;;;;;
;;;;;====================================================================================================================



(DEFUN IND=WFO.ATTRIBUTE.CREATE (GTERM LITERALS FORMAL.PARS ACTUAL.PARS)

  ;;; Input:  a gterm
  ;;: Value:  the attributes for the wfo suggested by GTERM

  (LET ((SUBST (UNI-TERMSUBST.CREATE.PARALLEL FORMAL.PARS ACTUAL.PARS)))
    (LIST 'FCTS.SUGGESTED (LIST (DA-GTERM.SYMBOL GTERM))
	  'GTERMS.SUGGESTED (LIST GTERM)
	  'ADD.CASES (MAPCAR #'(LAMBDA (LIT)
				 (UNI-TERMSUBST.APPLY SUBST LIT))
			     LITERALS))))


(DEFUN IND=WFO.MERGE.ATTRIBUTES (ATTRIBUTES1 ATTRIBUTES2)

  ;;; Input:  two attribute-lists of wfos
  ;;; Value:  the merge of both
  
  (LIST 'FCTS.SUGGESTED (UNION (GETF ATTRIBUTES1 'FCTS.SUGGESTED)
			       (GETF ATTRIBUTES2 'FCTS.SUGGESTED))
	'GTERMS.SUGGESTED (UNION (GETF ATTRIBUTES1 'GTERMS.SUGGESTED)
				 (GETF ATTRIBUTES2 'GTERMS.SUGGESTED))
	'ADD.CASES (UNION (GETF ATTRIBUTES1 'ADD.CASES)
			  (GETF ATTRIBUTES2 'ADD.CASES))))


;;;;;====================================================================================================
;;;;;
;;;;;
;;;;;     Others
;;;;;
;;;;;====================================================================================================


(DEFUN IND=GET.ACTUAL.REC.PARMS (POSITIONS ACTUAL.PARMS)

  ;;; Input:  a list of positions and gtermlist
  ;;; Value:  the list of all gterms of ACTUAL.PARMS corresponding to the denoted positions
  
  (MAPCAR #'(LAMBDA (ARGPOS)
	      (NTH (1- ARGPOS) ACTUAL.PARMS))
	  POSITIONS))


(DEFUN IND=GTERMLIST.SKOLEM.CONSTANTS (GTERMLIST)

  ;;; Input:   a list of Gterms
  ;;; Value:   a list of all skolem-constants occuring in GTERMLIST

  (LET (CONSTANTS)
       (MAPC #'(LAMBDA (GTERM)
		       (SETQ CONSTANTS (UNION CONSTANTS (DA-GTERM.CONSTANTS GTERM 'SKOLEM))))
	     GTERMLIST)
       CONSTANTS))
