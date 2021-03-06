;;; -*- Package: INKA; Syntax: Common-lisp -*-


(IN-PACKAGE :INKA)


(DEFVAR REC*ENVIRONMENT (UNI-ENVIRONMENT (CONS 'KEY 'RECURSION)))


(DEFVAR REC*ORDERINGS 0)

(DEFVAR REC*FAILED.PROOFS NIL)


(DEFUN REC-DEFINITION.ANALYZE (DEFINITION)

  ;;; Edited:   21-Jan-87 by DH
  ;;; Input:    A definition-task as specified by the deduction-module.
  ;;; Effect:   It is determined, whether \verb$DEFINITION$ terminates according to some specified 
  ;;;           well-ordering. Also a function definition is checked for limited argument positions.
  ;;; Value:    the original task, with some if-then-cases changed for efficency
  ;;;           or NIL, if some definition doesn't terminate.

  (LET (AXIOMS DELTA.DIFFS NEW.DEFINITION)
    (SETQ REC*FAILED.PROOFS NIL)
    (MULTIPLE-VALUE-BIND (DEF.CLAUSE SYMBOL PARAMETERS) (VALUES-LIST DEFINITION)
      (MULTIPLE-VALUE-SETQ (NEW.DEFINITION DELTA.DIFFS AXIOMS)
	(REC=ANALYSE.SYMBOL DEF.CLAUSE SYMBOL PARAMETERS))      
      (VALUES NEW.DEFINITION DELTA.DIFFS AXIOMS))))


(DEFUN REC-DECL.DEFINITION.ANALYZE (SYMBOL INPUT VALUE)

  ;;; edited : 19.03.93 by CS
  ;;; input  : a function or predicate symbol 
  ;;; effect : it is determined whether the symbol is recursively defined, if so the
  ;;;          corresponding structural induction orderings are generated
  ;;; value  : none

  (LET (FORMAL.PARAMETERS REC.PARAMS
	(REC.POSITIONS (SET-DIFFERENCE (REC=REC.POSITIONS.FROM.DECL.DEF SYMBOL INPUT VALUE)
				       (DA-PREFUN.REC.POSITIONS SYMBOL))))
    (COND ((NULL (DA-PREFUN.FORMAL.PARAMETERS SYMBOL))
	   (SETF (DA-PREFUN.FORMAL.PARAMETERS SYMBOL)
		 (MAPCAR #'DA-VARIABLE.CREATE (DA-PREFUN.DOMAIN.SORTS SYMBOL)))))
    (SETQ FORMAL.PARAMETERS (DA-PREFUN.FORMAL.PARAMETERS SYMBOL))
    (COND (REC.POSITIONS
	   (SETF (DA-PREFUN.REC.POSITIONS SYMBOL) (UNION REC.POSITIONS (DA-PREFUN.REC.POSITIONS SYMBOL)))
	   (MAPC #'(LAMBDA (REC.POS)
		     (LET ((VARIABLE (NTH (1- REC.POS) FORMAL.PARAMETERS)))
		       (SETQ REC.PARAMS (da-term.create VARIABLE))
		       (PUSH (DA-WFO.SUGGESTED.CREATE (LIST REC.POS) NIL
						      (DA-WFO.CREATE (LIST REC.PARAMS)
								     (REC=WFO.STRUCTURAL.TREE.CREATE VARIABLE)
								     NIL (LIST REC.PARAMS)))
			     (DA-PREFUN.WFO.SUGGESTED SYMBOL))))
		 REC.POSITIONS)))))


(DEFUN REC-INDUCTION.ANALYZE (PARAMETERS DEFINITION SYMBOL)

  ;;; Input  :   a list of induction variables (skolem constants) and a tree 
  ;;; Effect :   proves the correctness of the scheme and generates the induction scheme
  ;;; Value :   the induction scheme if it is sound.

  (SETQ REC*FAILED.PROOFS NIL)
  (setq rec*orderings 0)
  (COND ((REC=SEARCH.ORDERING DEFINITION SYMBOL PARAMETERS)
	 (LIST (REC=WFO.IND.CREATE DEFINITION SYMBOL PARAMETERS)))))


(DEFUN REC-INSERT.SORT (SORT)

  ;;; Input:  a sort
  ;;; Effect: creates the delta-difference predicates for all reflexive selectors of \verb$SORT$ and
  ;;;         updates the corresponding function slots of the selectors.
  ;;; Value:  a list of all generated delta-difference definitions

  (LET (COUNTER)
    (NCONC (MAPCAN #'(LAMBDA (CONSTRUCTOR SELECTORS)
		       (SETQ COUNTER 0)
		       (MAPCAN #'(LAMBDA (SELECTOR)
				   (INCF COUNTER)
				   (COND ((EQ (DA-SYMBOL.SORT SELECTOR) (DA-SYMBOL.SORT CONSTRUCTOR))
					  (LIST (REC=DELTA.CREATE.SELECTOR.DIFFERENCE.PREDICATE CONSTRUCTOR SELECTOR COUNTER)))))
			       SELECTORS))
		   (DA-SORT.CONSTRUCTOR.FCTS SORT) (DA-SORT.SELECTOR.FCTS SORT))
	   (MAPCAR #'(LAMBDA (INDEX.FCT)
		       (REC=DELTA.CREATE.INDEX.DIFFERENCE.PREDICATE INDEX.FCT))
		   (DA-SORT.INDEX.FCTS SORT)))))

(DEFUN REC=ANALYSE.SYMBOL (DEFINITION SYMBOL PARAMETERS)

  ;;; Input  :   a tree and its leaves, a symbol and its formal parameters
  ;;; Effect :   1. proves the termination of SYMBOL
  ;;;            2. checks whether it is argument limited
  ;;;                and if so, generates a difference predicate.
  ;;;            3. induction schemes for SYMBOL are generated
  ;;; Values :   a multiple value:
  ;;;            a flag, which is T, if the definition tress has to be rebuild,
  ;;;            a list of definitions (as used in EXP) and a list of axioms.

  (LET (DELTA.PREDS MIN.PROJECTIONS OK? AXIOMS TYPE ERROR COND.REC)
    (setq rec*orderings 0)
    (MULTIPLE-VALUE-SETQ (OK? MIN.PROJECTIONS TYPE COND.REC)
      (REC=SEARCH.ORDERING DEFINITION SYMBOL PARAMETERS))
    (COND (OK? (COND ((AND (DA-FUNCTION.IS SYMBOL)
			   (NULL COND.REC)
			   (EQ TYPE 'COUNT.ORDER)
			   (NULL (REC=RED.UNSPEC.CASES DEFINITION)))
		      (MULTIPLE-VALUE-SETQ (DELTA.PREDS AXIOMS)
			(REC=GAMMA.CRITERION DEFINITION SYMBOL PARAMETERS MIN.PROJECTIONS))))
	       (SETQ DEFINITION (REC=RED.CASE.MERGE DEFINITION SYMBOL PARAMETERS))
	       (REC=WFO.CREATE DEFINITION SYMBOL PARAMETERS MIN.PROJECTIONS)
	       (VALUES (LIST DEFINITION SYMBOL PARAMETERS) DELTA.PREDS AXIOMS))
	  (T (SETQ ERROR (REC=PROTOCOL.FAILURE SYMBOL PARAMETERS))
	     (win-io.FORMAT.string (win-window 'proof) ERROR)
	     (VALUES NIL (LIST 0 0 ERROR NIL))))))




(DEFUN REC=PROTOCOL.FAILURE (SYMBOL PARAMETERS)

  (LET (TESTS)
    ;(MAPCF #'(LAMBDA (ORDERING FORMULAS)
; 	       (PUSH (FORMAT NIL "Using ~A as a measure we would need lemma(ta): ~%~%~{~A~%~}"
;			     (FORMAT NIL "[ ~{~A ~}]" (MAPCAR #'(LAMBDA (ORD)
;								  (COND ((CDR ORD) (CAR (PR-PRINT.TERM (CDR ORD))))
;									(T (format nil "~A" (CAR ORD)))))
;							      ORDERING))
;			     (MAPCAR #'(LAMBDA (FORMULA)
;					 (FORMAT NIL "~{    ~A~%~}~%" (PR-PRINT.LITLIST FORMULA)))
;				     FORMULAS))
;		     TESTS))
;	   REC*FAILED.PROOFS)
    (FORMAT NIL "~%Can't find a wellfounded order for ~A. Hence the definition is refused.~%~%~{~A~}"
	    (CAR (PR-PRINT.TERM (DA-TERM.CREATE SYMBOL (MAPCAR #'(LAMBDA (VAR) (DA-TERM.CREATE VAR)) PARAMETERS))))
	    TESTS)))

;;;;; =======================================================================================================
;;;;; Chapter 1.
;;;;; ----------
;;;;;
;;;;; Termination of the given definition.
;;;;; =======================================================================================================


(DEFUN REC=SEARCH.ORDERING (DEFINITION SYMBOL FORMAL.PARAMETERS)

  ;;; Input:   a function / predicate definition, the symbol to be defined and the formal parameter
  ;;; Effect:  searches for an ordering, such that each recursive call of symbol in definition descreases
  ;;;          according to this ordering.
  ;;; Value:   T, iff such an ordering has been found

  (LET (CALL.MATRIX OLD.CALL.MATRIX CONDITIONS RECURSIVE.CALLS OK? MIN.PROJECTIONS
	CONDITION.WITHOUT.RECURSIONS COND.REC)
    (DA-GTERM.DEF.MAP.WITH.CONDS 
     DEFINITION
     #'(LAMBDA (VALUE CONDITION)
	 (MAPC #'(LAMBDA (RECURSIVE.CALL)
		   (PUSH CONDITION CONDITIONS)
		   (PUSH (DA-GTERM.TERMLIST RECURSIVE.CALL) RECURSIVE.CALLS))			       
	       (REC=DETERMINE.RECURSIVE.CALLS VALUE SYMBOL))
	 (SETQ CONDITION.WITHOUT.RECURSIONS 
	       (REMOVE-IF #'(LAMBDA (GTERM) 
			      (COND ((DA-SYMBOL.OCCURS.IN.GTERM SYMBOL GTERM) (SETQ COND.REC T))))
			  CONDITION))
	 (COND (COND.REC
		(MAPC #'(LAMBDA (GTERM)
			  (MAPC #'(LAMBDA (RECURSIVE.CALL)
				    (PUSH CONDITION.WITHOUT.RECURSIONS CONDITIONS)
				    (PUSH (DA-GTERM.TERMLIST RECURSIVE.CALL) RECURSIVE.CALLS))			       
				(REC=DETERMINE.RECURSIVE.CALLS GTERM SYMBOL)))
		      (SET-DIFFERENCE CONDITION CONDITION.WITHOUT.RECURSIONS))))))	       
    (SETQ CALL.MATRIX (REC=COUNT.ORDER FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS))
    (COND ((MULTIPLE-VALUE-SETQ (OK? MIN.PROJECTIONS)
	     (REC=TERM.COMPUTE.MINIMAL.PROJECTIONS CONDITIONS CALL.MATRIX))
	   (VALUES OK? MIN.PROJECTIONS 'COUNT.ORDER COND.REC))
	  (T (SETQ OLD.CALL.MATRIX (REMOVE-IF-NOT #'(LAMBDA (MEASURE) (MEMBER 'DOWN (CDR MEASURE))) CALL.MATRIX))
	     (SETQ CALL.MATRIX (REC=LEX.ORDER FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS CALL.MATRIX))
	     (COND ((MULTIPLE-VALUE-SETQ (OK? MIN.PROJECTIONS)
		      (REC=TERM.COMPUTE.MINIMAL.PROJECTIONS CONDITIONS CALL.MATRIX))
		    (VALUES OK? MIN.PROJECTIONS 'LEX.ORDER COND.REC))
		   (T (SETQ CALL.MATRIX (REC=TERM.MEASURE.ORDER FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS))
		      (MULTIPLE-VALUE-SETQ (OK? MIN.PROJECTIONS)
			(REC=TERM.COMPUTE.MINIMAL.PROJECTIONS CONDITIONS (APPEND CALL.MATRIX OLD.CALL.MATRIX)))
		      (VALUES OK? MIN.PROJECTIONS 'MEASURE.FCT COND.REC)))))))



(DEFUN REC=COUNT.ORDER (FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS)
  
  ;;; Input:   a list of formal parameters and lists of recursive calls and their conditions
  ;;; Effect:  Determines whether the actual parameters are less or equal than the formal parameters according to the
  ;;;          count-ordering.
  ;;; Value:   a list of lists (order s1 ... sn) where order is an item for an ordering, and s(i) are either
  ;;;          EQ, DOWN, UP or a list of literals (denoting the difference equivalent) denoting whether the
  ;;;          i-th actual parameter is equal, less or greater than the i-th formal parameter

  (LET (ORDERING (ARG -1))
    (MAPCAR #'(LAMBDA (FORMAL.PARAMETER)
		(INCF ARG)
		(SETQ ORDERING (REC=CREATE.ORDER (DA-TERM.CREATE FORMAL.PARAMETER)))
		(CONS (LIST ORDERING) (MAPCAR #'(LAMBDA (RECURSIVE.CALL CONDITION)
						  (REC=COUNT.ORDER.ANALYZE FORMAL.PARAMETER (NTH ARG RECURSIVE.CALL)
									   CONDITION ORDERING))
					      RECURSIVE.CALLS CONDITIONS)))
	    FORMAL.PARAMETERS)))


(DEFUN REC=COUNT.ORDER.ANALYZE (FORMAL.PARAMETER ACTUAL.PARAMETER CONDITIONS ORDERING)

  ;;; Edited: 22-Mar-89 by PB
  ;;; Input:  FORMAL.PARAMETER:  a variable-symbol, denoting a formal parameter of SYMBOL  
  ;;;         ACTUAL.PARAMETER:  a term, denoting the corresponding actual parameter of a recursive call
  ;;;         CONDITION:         the condition of the considered definition case.
  ;;; Effect: the actual parameter is compared with the corresponding formal parameter
  ;;; Value:  either 'UP , 'DOWN , 'EQ  or a list (ordering . difference literals).

  (LET (DIFFERENCE.EQUIVALENT)
    (COND ((SETQ DIFFERENCE.EQUIVALENT (cond ((REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT ACTUAL.PARAMETER (DA-TERM.CREATE FORMAL.PARAMETER)))
					     ((REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT ACTUAL.PARAMETER
											(REC=TERM.INCORPORATE.MATCH.LITS 
											 (DA-TERM.CREATE FORMAL.PARAMETER) CONDITIONS)))))
	   (COND ((AND (NULL (CDR DIFFERENCE.EQUIVALENT))
		       (DA-LITERAL.IS.FALSE (CAR DIFFERENCE.EQUIVALENT))) 'EQ)
		 ((REC=PROVE.DISJUNCTION (APPEND CONDITIONS DIFFERENCE.EQUIVALENT) (LIST ORDERING))
		  'DOWN)
		 (T (CONS (LIST ORDERING) DIFFERENCE.EQUIVALENT))))
	  (T 'UP))))


(DEFUN REC=LEX.ORDER (FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS CALL.MATRIX)

  (LET (SUCCESS POSITION ORDERING NEW.TERM ACT.LINE MATCH.SUBSTS FORMAL.PAR.TERM)
    (SETQ MATCH.SUBSTS (MAPCAR #'(LAMBDA (COND) (DA-LITERALS.MATCH.SUBST COND)) CONDITIONS))
    (MAPCAN #'(LAMBDA (MATRIX.LINE)
		(SETQ FORMAL.PAR.TERM (CDR (CAAR MATRIX.LINE)))
		(SETQ POSITION (POSITION (DA-TERM.SYMBOL FORMAL.PAR.TERM) FORMAL.PARAMETERS))
		(SETQ ACT.LINE (MAPCAR #'(LAMBDA (REC.CALL SUBST ENTRY)
					   (COND ((EQ SUCCESS 'FAIL) NIL)
						 ((AND (SETQ NEW.TERM (DA-TERM.APPLY.MATCH.SUBST
								       (NTH POSITION REC.CALL) SUBST))
						       (REC=LEX.TERM.IS.STRUCTURE NEW.TERM))
						  (COND ((NEQ ENTRY 'DOWN) (SETQ SUCCESS T)))
						  NEW.TERM)
						 ((EQ ENTRY 'DOWN) (SETQ SUCCESS 'FAIL))))					   
				       RECURSIVE.CALLS MATCH.SUBSTS (CDR MATRIX.LINE)))		
		(COND ((EQ T SUCCESS)
		       (SETQ ORDERING (REC=CREATE.ORDER FORMAL.PAR.TERM))
		       (MAPC #'(LAMBDA (CONDS)
				 (REC=LEX.INSERT.ORDERING.TO.CONDS FORMAL.PAR.TERM CONDS (LIST ORDERING)))
			     CONDITIONS)
		       (LIST (CONS (LIST ORDERING) (REC=LEX.FIND.LEX.ORDERING ACT.LINE
									      (MAPCAR #'(LAMBDA (SUBST)
											  (DA-TERM.APPLY.MATCH.SUBST
											   FORMAL.PAR.TERM SUBST))
										      MATCH.SUBSTS)
									      (CDR MATRIX.LINE)))))))
	    CALL.MATRIX)))
	    

(DEFUN REC=LEX.TERM.IS.STRUCTURE (TERM)

  (LET ((SYMBOL (DA-TERM.SYMBOL TERM)))
    (COND ((DA-VARIABLE.IS SYMBOL))
	  ((AND (DA-FUNCTION.IS.CONSTRUCTOR SYMBOL)
		(DA-SYMBOL.HAS.ATTRIBUTE (DA-FUNCTION.SORT SYMBOL) 'FREE.STRUCTURE))
	   (EVERY #'(LAMBDA (SUB.TERM)
		      (REC=LEX.TERM.IS.STRUCTURE SUB.TERM))
		  (DA-TERM.TERMLIST TERM))))))


(DEFUN REC=LEX.FIND.LEX.ORDERING (ACTUAL.PARAMETERS FORMAL.PARAMETERS COUNT.ORDER.RESULT)

  (LET ((PERMUTATION (REC=LEX.ARGUMENT.PERMUTATION ACTUAL.PARAMETERS FORMAL.PARAMETERS COUNT.ORDER.RESULT)))
    (MAPCAR #'(LAMBDA (ACT.PAR FOR.PAR)
		(COND (ACT.PAR (COND ((REC=LEX.GRAPH.GREATER.EQUAL FOR.PAR ACT.PAR NIL PERMUTATION)
				      (COND ((REC=LEX.GRAPH.EQUAL FOR.PAR ACT.PAR NIL PERMUTATION) 'EQ)
					    (T 'DOWN)))
				     (T 'UP)))
		      (T 'UP)))
	    ACTUAL.PARAMETERS FORMAL.PARAMETERS)))

     
(DEFUN REC=LEX.ARGUMENT.PERMUTATION (ACTUAL.PARAMETERS FORMAL.PARAMETERS COUNT.ORDER.RESULT)

  ;;; Input:   a list of recursive calls, a list of formal parameters and a list of the
  ;;;          behaviour of both wrt. the count ordering
  ;;; Value:   a property-list indicating those arguments of the constructors which have to
  ;;;          be the first ones wrt. the lex. ordering.

  (LET (ALL.REMOVE.POS REMOVE.POS GTERM NEW.ARGS ENTRY)
    (MAPC #'(LAMBDA (ACT.PAR FOR.PAR COUNT.RES)
	      (COND ((EQ COUNT.RES 'DOWN)
		     (MAPC #'(LAMBDA (VAR)
			       (MAPC #'(LAMBDA (TAF)
					 (COND (TAF
						(SETQ GTERM (DA-ACCESS (CDR TAF) FOR.PAR))
						(SETF (GETF REMOVE.POS (DA-TERM.SYMBOL GTERM))
						      (ADJOIN (CAR TAF) (GETF REMOVE.POS (DA-TERM.SYMBOL GTERM)))))))
				     (DA-SYMBOL.OCCURS.IN.GTERM VAR FOR.PAR)))
			   (SET-DIFFERENCE (UNION (DA-GTERM.VARIABLES FOR.PAR) (DA-GTERM.FUNCTIONS FOR.PAR))
					   (UNION (DA-GTERM.VARIABLES ACT.PAR) (DA-GTERM.FUNCTIONS ACT.PAR))))
		     (MAPCF #'(LAMBDA (SYMBOL ARGS)
			       (COND ((SETQ ENTRY (GETF ALL.REMOVE.POS SYMBOL))
				      (SETF (GETF ALL.REMOVE.POS SYMBOL) (INTERSECTION ARGS ENTRY)))
				     (T (SETF (GETF ALL.REMOVE.POS SYMBOL) ARGS))))
			   REMOVE.POS)
		     (SETQ REMOVE.POS NIL))))
	  ACTUAL.PARAMETERS FORMAL.PARAMETERS COUNT.ORDER.RESULT)
    (MAPCF #'(LAMBDA (SYMBOL ARGS)
	       (SETQ ARGS (SORT ARGS #'<))
	       (DOTIMES (I (DA-FUNCTION.ARITY SYMBOL))
			(COND ((NOT (MEMBER (1+ I) ARGS))
			       (PUSH (1+ I) NEW.ARGS))))
	       (SETF (GETF ALL.REMOVE.POS SYMBOL) (NCONC ARGS NEW.ARGS)))
	   ALL.REMOVE.POS)
    ALL.REMOVE.POS))



(DEFUN REC=LEX.GRAPH.GREATER.EQUAL (TERM1 TERM2 SYMBOL.ORDERING PERMUTATION)

  ;;; Input:  two terms and a list of function symbols
  ;;; Value:  T, if term1 is greater or equal to term2 according to the lexicographical term
  ;;;         ordering

  (OR (SOME #'(LAMBDA (SUB.TERM.1)
		(REC=LEX.GRAPH.GREATER.EQUAL SUB.TERM.1 TERM2 SYMBOL.ORDERING PERMUTATION))
	    (DA-TERM.TERMLIST TERM1))
      (AND (OR (REC=LEX.FCT.GREATER (DA-TERM.SYMBOL TERM1) (DA-TERM.SYMBOL TERM2) SYMBOL.ORDERING)
	       (AND (REC=LEX.FCT.EQUAL (DA-TERM.SYMBOL TERM1) (DA-TERM.SYMBOL TERM2) SYMBOL.ORDERING)
		    (NEQ 'FAIL (SOME #'(LAMBDA (SUB.TERM1 SUB.TERM2)
					 (COND ((REC=LEX.GRAPH.GREATER SUB.TERM1 SUB.TERM2 SYMBOL.ORDERING PERMUTATION) T)
					       ((NOT (REC=LEX.GRAPH.EQUAL SUB.TERM1 SUB.TERM2 SYMBOL.ORDERING PERMUTATION)) 'FAIL)))
				     (REC=LEX.PERMUTE.TERMLIST (DA-TERM.SYMBOL TERM1) (DA-TERM.TERMLIST TERM1) PERMUTATION)
				     (REC=LEX.PERMUTE.TERMLIST (DA-TERM.SYMBOL TERM2) (DA-TERM.TERMLIST TERM2) PERMUTATION)))))
	   (EVERY #'(LAMBDA (SUB.TERM2)
		      (REC=LEX.GRAPH.GREATER TERM1 SUB.TERM2 SYMBOL.ORDERING PERMUTATION))
		  (DA-TERM.TERMLIST TERM2)))))


(DEFUN REC=LEX.GRAPH.EQUAL (TERM1 TERM2 SYMBOL.ORDERING PERMUTATION)

  (AND (REC=LEX.FCT.EQUAL (DA-TERM.SYMBOL TERM1) (DA-TERM.SYMBOL TERM2) SYMBOL.ORDERING)
       (EVERY #'(LAMBDA (SUB.TERM1 SUB.TERM2)
		  (REC=LEX.GRAPH.EQUAL SUB.TERM1 SUB.TERM2 SYMBOL.ORDERING PERMUTATION))
	      (REC=LEX.PERMUTE.TERMLIST (DA-TERM.SYMBOL TERM1) (DA-TERM.TERMLIST TERM1) PERMUTATION)
	      (REC=LEX.PERMUTE.TERMLIST (DA-TERM.SYMBOL TERM2) (DA-TERM.TERMLIST TERM2) PERMUTATION))))


(DEFUN REC=LEX.GRAPH.GREATER (TERM1 TERM2 SYMBOL.ORDERING PERMUTATION)

  (AND (NOT (REC=LEX.GRAPH.EQUAL TERM1 TERM2 SYMBOL.ORDERING PERMUTATION))
       (REC=LEX.GRAPH.GREATER.EQUAL TERM1 TERM2 SYMBOL.ORDERING PERMUTATION)))


(DEFUN REC=LEX.FCT.GREATER (SYMBOL1 SYMBOL2 SYMBOL.ORDERING)
  
  (MEMBER SYMBOL2 (CDR (MEMBER SYMBOL1 SYMBOL.ORDERING))))


(DEFUN REC=LEX.FCT.EQUAL (SYMBOL1 SYMBOL2 SYMBOL.ORDERING)

  (DECLARE (IGNORE SYMBOL.ORDERING))
  (EQ SYMBOL1 SYMBOL2))


(DEFUN REC=LEX.PERMUTE.TERMLIST (SYMBOL TERMLIST PERMUTATION)

  (LET ((ENTRY (GETF PERMUTATION SYMBOL)))
    (COND (ENTRY (MAPCAR #'(LAMBDA (ARG) (NTH (1- ARG) TERMLIST)) ENTRY))
	  (T TERMLIST))))


(DEFUN REC=TERM.MEASURE.ORDER (FORMAL.PARAMETERS RECURSIVE.CALLS CONDITIONS)
  
  ;;; Input:   A list of formal parameters a list of lists of actual parameter
  ;;;          and a list of case conditions.
  ;;; Effect:  searches for measurement-function and analyzes each recursiv call
  ;;;          according to this measurement-function
  ;;; Value:   a matrix denoting the behaviour of each actual parameter wrt the
  ;;;          synthesized measures.

  (LET (CALL.MATRIX MEASURE.FCTS NEW.MEASURE.FCTS NEW.LINE.ENTRIES LINE ANALYZED.CONDS ANALYZED.REC.CALLS)
    (MAPC #'(LAMBDA (RECURSIVE.CALL CONDITION)
	      (SETQ RECURSIVE.CALL (REC=MSR.COLOURIZE RECURSIVE.CALL))
	      (MAPC #'(LAMBDA (CALL.LINE)
			(NCONC1 CALL.LINE (REC=MSR.ANALYZE.EXISTING.MEASURE (CAR CALL.LINE) FORMAL.PARAMETERS
									    RECURSIVE.CALL CONDITION)))
		    CALL.MATRIX)
	      (COND ((MULTIPLE-VALUE-SETQ (NEW.MEASURE.FCTS NEW.LINE.ENTRIES)
		       (REC=MSR.SYNTHESIZE.MEASURE MEASURE.FCTS RECURSIVE.CALL FORMAL.PARAMETERS CONDITION))
		     (MAPC #'(LAMBDA (NEW.MEASURE.FCT ENTRY)
			       (SETQ LINE (LIST ENTRY))
			       (MAPC #'(LAMBDA (REC.CALL COND)
					 (PUSH (REC=MSR.ANALYZE.EXISTING.MEASURE
						NEW.MEASURE.FCT FORMAL.PARAMETERS REC.CALL COND)
					       LINE))
				     ANALYZED.REC.CALLS ANALYZED.CONDS)
			       (PUSH (CONS (list NEW.MEASURE.FCT) LINE) CALL.MATRIX))
			   NEW.MEASURE.FCTS NEW.LINE.ENTRIES)))
	      (SETQ MEASURE.FCTS (NCONC MEASURE.FCTS NEW.MEASURE.FCTS))
	      (PUSH RECURSIVE.CALL ANALYZED.REC.CALLS)
	      (PUSH CONDITION ANALYZED.CONDS))
	  RECURSIVE.CALLS CONDITIONS)
    CALL.MATRIX))


(DEFUN REC=MSR.ANALYZE.EXISTING.MEASURE (MEASURE.FCT FORMAL.PARAMETERS ACTUAL.PARAMETERS CONDITION)

  ;;; Input:   a dotted pair (indicator . measure-term), the list of formal parameters
  ;;;          the list of actual parameters and a list of literals denoting the conditions of the case
  ;;; Effect:  analyzes whether the actual call (given by actual.parameters and condition) is less or
  ;;;          equal to the formal parameters wrt. the given measure function.
  ;;; Value:   an atom, UP, EQ, DOWN (the n-th argument of this list corresponds to the n-th
  ;;;          argument of MEASURE.FCTS).

  (LET ((GTERM (DA-GTERM.COPY (CDR (CAR MEASURE.FCT)) T (LIST 'RECURSION 'REC))) DIFF.EQ SUB.TERM)
    (MAPC #'(LAMBDA (VAR ACTUAL.PAR)
	      (MAPC #'(LAMBDA (TAF)
			(SETQ SUB.TERM (DA-TERM.COPY ACTUAL.PAR T (LIST 'RECURSION (DA-COLOUR.FADED))))
			(MAPC #'(LAMBDA (SUB.TAF)
				  (DA-GTERM.COLOURIZE (DA-ACCESS SUB.TAF SUB.TERM) 'REC 'RECURSION))
			      (DA-SYMBOL.OCCURS.IN.GTERM VAR SUB.TERM))
			(SETQ GTERM (DA-REPLACE TAF GTERM SUB.TERM)))
		    (DA-SYMBOL.OCCURS.IN.GTERM VAR GTERM)))
	  FORMAL.PARAMETERS ACTUAL.PARAMETERS)
    (COND ((MULTIPLE-VALUE-SETQ (GTERM DIFF.EQ)
	     (REC=MSR.MOVE.UP GTERM NIL CONDITION (CAR MEASURE.FCT)))
	   (COND ((REC=PROVE.DISJUNCTION (APPEND CONDITION DIFF.EQ) MEASURE.FCT) 'DOWN)
		 (T 'EQ)))
	  (T 'UP))))


(DEFUN REC=MSR.COLOURIZE (ACTUAL.PARAMETERS)

  ;;; Input:   a list of actual parameters, denoting a recursive call, and the list of formal parameters
  ;;; Effect:  creates coloured versions of FORMAL.PARAMETERS.
  ;;; Value:   a list of coloured actual parameters and nil's (if a parameter cannot be colourized).
  
  (MAPCAR #'(LAMBDA (ACT.PAR)
	      (DA-GTERM.COLOURIZE (DA-GTERM.COPY ACT.PAR) (DA-COLOUR.FADED) 'RECURSION))
	  ACTUAL.PARAMETERS))



(DEFUN REC=MSR.SYNTHESIZE.MEASURE (MEASURE.FCTS ACTUAL.PARAMETERS FORMAL.PARAMETERS CONDITION)

  ;;; Input:   a list of dotted pairs (indicator . measure-term), the list of coloured actual
  ;;;          parameters and the case-condition
  ;;; Effect:  synthesizes new measure-functions in order to prove that the given recursive call
  ;;;          decreases according to them.
  ;;; Value:   a list of new dotted pairs (indicator . measure-term), denoting new measure-functions,
  ;;;          and a list of EQ, DOWN depending whether the recursive call decreases or stays equal
  ;;;          wrt. the corresponding measure-function.

  (LET (USED.MODIFIERS NEW.ROW.ENTRIES NEW.MEASURE.FCTS N.MEASURE.FCTS N.ROW.ENTRIES)
    (MAPC #'(LAMBDA (ACTUAL.PARAMETER FORMAL.PARAMETER)
	      (COND ((AND ACTUAL.PARAMETER
			  (NOT (DA-VARIABLE.IS (DA-TERM.SYMBOL ACTUAL.PARAMETER))))
		     (MAPC #'(LAMBDA (TAF)
			       (DA-GTERM.COLOURIZE ACTUAL.PARAMETER (DA-COLOUR.FADED) 'RECURSION)
			       (DA-GTERM.COLOURIZE (DA-ACCESS TAF ACTUAL.PARAMETER) 'REC 'RECURSION)
			       (COND ((MULTIPLE-VALUE-SETQ (N.MEASURE.FCTS N.ROW.ENTRIES USED.MODIFIERS)
					(REC=MSR.SYNTHESIZE.MEASURE.BY.MOVING ACTUAL.PARAMETER ACTUAL.PARAMETERS
									      CONDITION USED.MODIFIERS MEASURE.FCTS))
				      (SETQ NEW.MEASURE.FCTS (NCONC NEW.MEASURE.FCTS N.MEASURE.FCTS))
				      (SETQ NEW.ROW.ENTRIES (NCONC NEW.ROW.ENTRIES N.ROW.ENTRIES))))
			       (COND ((MULTIPLE-VALUE-SETQ (N.MEASURE.FCTS N.ROW.ENTRIES)
					(REC=MSR.SYNTHESIZE.MEASURE.BY.TAUT ACTUAL.PARAMETER CONDITION
									    (REC=CREATE.ORDER FORMAL.PARAMETER)))
				      (SETQ NEW.MEASURE.FCTS (NCONC NEW.MEASURE.FCTS N.MEASURE.FCTS))
				      (SETQ NEW.ROW.ENTRIES (NCONC NEW.ROW.ENTRIES N.ROW.ENTRIES)))))
			   (DA-SYMBOL.OCCURS.IN.GTERM FORMAL.PARAMETER ACTUAL.PARAMETER)))))
	  ACTUAL.PARAMETERS FORMAL.PARAMETERS)
    (VALUES NEW.MEASURE.FCTS NEW.ROW.ENTRIES)))



(DEFUN REC=MSR.SYNTHESIZE.MEASURE.BY.MOVING (ACTUAL.PARAMETER REC.CALL CONDITION USED.MODIFIERS USED.MEASURE.FCTS)

  (LET (D.E NEW.MEASURE.FCT NEW.MEASURE.FCTS NEW.ROW ROW.ENTRIES)
    (DB-MODIFIER.COLLECTION
     ACTUAL.PARAMETER 'MOVE.UP NIL
     #'(LAMBDA (MODIFIER)
	 (COND ((AND (SETQ D.E (GETF (DA-MODIFIER.ATTRIBUTES MODIFIER) 'ARG.LIMITED))
		     (NOT (MEMBER MODIFIER USED.MODIFIERS)))
		(PUSH MODIFIER USED.MODIFIERS)
		(MAPC #'(LAMBDA (NO.SUBST)
			  (COND ((MULTIPLE-VALUE-SETQ (NEW.MEASURE.FCT NEW.ROW)
				   (REC=MSR.ESTABLISH.ORDER NO.SUBST MODIFIER
							    (REC=MSR.INST.DIFF.EQ D.E (CDR NO.SUBST))
							    CONDITION))
				 (PUSH NEW.ROW ROW.ENTRIES)
				 (SETF (CDR (CAR NO.SUBST)) NEW.MEASURE.FCT)
				 (PUSH (CAR NO.SUBST) NEW.MEASURE.FCTS))))
		      (REC=MSR.SYNTHESIZE.ARGLIST USED.MEASURE.FCTS MODIFIER REC.CALL CONDITION))))
	 NIL))
    (VALUES NEW.MEASURE.FCTS ROW.ENTRIES nil)))


(DEFUN REC=MSR.SYNTHESIZE.MEASURE.BY.TAUT (ACTUAL.PARAMETER CONDITION ORDERING)

  (LET ((TAF (CAR (DA-GTERM.MAX.COLOURED.GTERMS ACTUAL.PARAMETER 'RECURSION)))
        NEXT.GTERM GTERM SUBSTS ROW.ENTRIES NEW.MEASURE.FCTS)
    (COND ((MULTIPLE-VALUE-SETQ (NEW.MEASURE.FCTS ROW.ENTRIES)
	     (REC=MSR.CALL.IS.ARG.LIMITED ACTUAL.PARAMETER TAF CONDITION ORDERING))
	   (VALUES NEW.MEASURE.FCTS ROW.ENTRIES))
	  (TAF (DA-GTERM.COLOURIZE (DA-ACCESS (DA-TAF.SUPER.TAF TAF) ACTUAL.PARAMETER) 'REC 'RECURSION)
	       (SETQ GTERM (DA-REPLACE (list (CAR TAF))
				       (DA-TERM.COPY (DA-ACCESS (DA-TAF.SUPER.TAF TAF) ACTUAL.PARAMETER)
						     T (LIST 'RECURSION (DA-COLOUR.FADED)))
				       ACTUAL.PARAMETER))
	       (COND ((DB-MODIFIER.SELECTION
		       GTERM 'REMOVE NIL
		       #'(LAMBDA (MODIFIER)
			   (COND ((AND (DA-TAF.ARE.EQUAL NIL (DA-MODIFIER.INPUT.TAF MODIFIER))
				       (MULTIPLE-VALUE-SETQ (SUBSTS NEXT.GTERM)
					 (REC=MSR.MODIFIER.TEST MODIFIER GTERM NIL 'RECURSION CONDITION ORDERING)))
				  (MULTIPLE-VALUE-SETQ (NEW.MEASURE.FCTS ROW.ENTRIES)
				    (REC=MSR.SYNTHESIZE.MEASURE.BY.TAUT NEXT.GTERM CONDITION ORDERING))))))
		      (VALUES NEW.MEASURE.FCTS ROW.ENTRIES)))))))


(DEFUN REC=MSR.CALL.IS.ARG.LIMITED (GTERM TAF CASE.CONDITION &OPTIONAL ORDERING)

  (LET ((ACT.GTERM GTERM))
    (COND ((EVERY #'(LAMBDA (ARG)
		      (PROG1 (ASSOC ARG (DA-FUNCTION.ARG.LIMITED (DA-GTERM.SYMBOL ACT.GTERM)))
			(SETQ ACT.GTERM (NTH (1- ARG) (DA-GTERM.TERMLIST ACT.GTERM)))))
		  (REVERSE TAF))
	   (SETQ ACT.GTERM GTERM)
	   (COND ((AND (NOT (DA-VARIABLE.IS (DA-TERM.SYMBOL (DA-ACCESS TAF GTERM))))
		       (REC=PROVE.DISJUNCTION
			(APPEND CASE.CONDITION
				(MAPCAR #'(LAMBDA (ARG)
					    (DA-LITERAL.CREATE
					     (DA-SIGN.PLUS)
					     (SECOND (ASSOC ARG (DA-FUNCTION.ARG.LIMITED (DA-GTERM.SYMBOL ACT.GTERM))))
					     (MAPCAR #'DA-TERM.COPY (DA-GTERM.TERMLIST ACT.GTERM))))
					(REVERSE TAF)))
			(LIST ORDERING)))
		  (SETF (CDR ORDERING) (DA-ACCESS TAF GTERM))
		  (VALUES (LIST ORDERING) (LIST 'DOWN))))))))


(DEFUN REC=MSR.ESTABLISH.ORDER (NO.SUBST MODIFIER DIFF.EQ CASE.CONDITION)

  ;;; Input:   a dotted pair (indicator . substitution), a modifier, a list of literals and the case
  ;;;          conditions
  ;;; Effect:  tests, whether the instantiated right-hand side of modifier is less or equal than
  ;;;          its skeleton wrt. the count-ordering.
  ;;; Value:   a multiple-value: first, the new measure-term and second, either DOWN (less) or EQ (equal).
  ;;;          In case the modifier is not proved to be less or equal than its skeleton: NIL.

  (LET ((GTERM (UNI-SUBST.APPLY (CDR NO.SUBST) (DA-MODIFIER.VALUE MODIFIER)
				NIL (UNI-ENVIRONMENT
				     (CONS 'KEY (DA-CMODIFIER.SOLUTION MODIFIER)))
				'RECURSION)))
    (REC=MSR.GTERM.COLOURIZE GTERM)
    (COND ((MULTIPLE-VALUE-SETQ (GTERM DIFF.EQ) (REC=MSR.MOVE.UP GTERM DIFF.EQ CASE.CONDITION))
	   (VALUES (DA-ACCESS (CAR (DA-GTERM.MAX.COLOURED.GTERMS GTERM 'RECURSION)) GTERM)
		   (COND ((REC=PROVE.DISJUNCTION (APPEND CASE.CONDITION DIFF.EQ) (LIST (CAR NO.SUBST))) 'DOWN)
			 (T 'EQ)))))))


(DEFUN REC=MSR.GTERM.COLOURIZE (GTERM)

  ;;; Input:  a gterm
  ;;; Value:  the gterm, where all coloured parts are redyed by the atom 'rec.
  
  (COND ((NOT (DA-COLOUR.IS.FADE (DA-GTERM.COLOUR GTERM 'RECURSION)))
	 (SETF (GETF (DA-GTERM.COLOURS GTERM) 'RECURSION) 'REC)))
  (MAPC #'(LAMBDA (SUBTERM)
	    (REC=MSR.GTERM.COLOURIZE SUBTERM))
	(DA-GTERM.TERMLIST GTERM)))

  

(DEFUN REC=MSR.SYNTHESIZE.ARGLIST (MEASURE.FCTS MODIFIER REC.CALL CONDITION)

  ;;; Input:   a list of dotted pairs (indicator . measure-term), a modifier, the list of coloured actual
  ;;;          parameters and the case-condition
  ;;; Effect:  relates the actual parameters to the context-terms of the modifier in order
  ;;;          to obtain a measure-function.
  ;;; Value:   a list of dotted pairs (indicator . sigma), where sigma is used to instantiate the modifier.

  (LET* ((GTERM (DA-MODIFIER.INPUT MODIFIER))
	 (ACT.VARS (REMOVE-IF #'(LAMBDA (ACT.PAR) (NOT (DA-VARIABLE.IS (DA-TERM.SYMBOL ACT.PAR))))
			     REC.CALL))
	 (VARS (DA-GTERM.VARIABLES GTERM))
	 SUBSTS)
    (SETQ SUBSTS (MAPCAN #'(LAMBDA (SUBST)
			     (COND ((MAPCAN #'(LAMBDA (VAR)
						(MAPCAN #'(LAMBDA (ACT.VAR)
							    (UNI-MATCHER.MERGE SUBST (CAR (UNI-TERM.MATCH
											 (DA-TERM.CREATE VAR NIL (LIST 'RECURSION 'REC))
											 ACT.VAR T))))
							ACT.VARS))
					    (SET-DIFFERENCE VARS (UNI-SUBST.DOMAIN SUBST))))
				   (T (LIST SUBST))))
			 (REC=MSR.SYNTHESIZE.ARGLIST.1
			  GTERM (GETF (DA-MODIFIER.ATTRIBUTES MODIFIER) 'TAFS)
			  REC.CALL (DA-CMODIFIER.SOLUTION MODIFIER) (LIST NIL))))
    (REC=MSR.ELIMINATE.INVALID.SUBSTS SUBSTS MEASURE.FCTS CONDITION MODIFIER)))


(DEFUN REC=MSR.ELIMINATE.INVALID.SUBSTS (SUBSTS MEASURE.FCTS CASE.CONDITION MODIFIER)

  ;;; Input:  a list of substitutions, a list of dotted pairs (indicator . measure-term),
  ;;;         the case-conditions and the modifier
  ;;; Effect: removes all substitutions from substs which either denote a measure function
  ;;;         already in MEASURE.FCTS or which do not allow to prove the instantiated conditions
  ;;;         of the modifier.
  ;;; Value:   a list of dotted pairs (indicator . substitution).
  
  (LET ((GTERM (DA-GTERM.SOME.SKELETON (DA-MODIFIER.INPUT MODIFIER)
				       (DA-CMODIFIER.SOLUTION MODIFIER)))
	SUBST.GTERM ORDER)
    (MAPCAN #'(LAMBDA (SUBST)
		(SETQ ORDER (REC=CREATE.ORDER subst.gterm))
		(SETQ SUBST.GTERM (UNI-SUBST.APPLY SUBST GTERM
						   NIL (UNI-ENVIRONMENT (CONS 'KEY (DA-CMODIFIER.SOLUTION MODIFIER)))))
		(COND ((AND (EVERY #'(LAMBDA (MEASURE.FCT)
				       (NOT (UNI-GTERM.ARE.EQUAL SUBST.GTERM (CDR MEASURE.FCT))))
				   MEASURE.FCTS)
			    (EVERY #'(LAMBDA (LIT)
				       (AND (DA-LITERAL.IS LIT)
					    (REC=PROVE.DISJUNCTION (CONS (DA-LITERAL.NEGATE (UNI-SUBST.APPLY SUBST LIT))
									 CASE.CONDITION)
								   (LIST ORDER))))
				   (DA-MODIFIER.CONDITION MODIFIER)))
		       (LIST (CONS ORDER SUBST)))))
	    SUBSTS)))


(DEFUN REC=MSR.SYNTHESIZE.ARGLIST.1 (GTERM TAF.LIST REC.CALL COLOUR.KEY SUBSTS)

  ;;; Input:   a gterm, a list of term-access functions, a list of coloured parameters, a colour indicator
  ;;;          and a list of substitutions
  ;;; Effect:  relates each subterm of GTERM, specified by a member of TAF.LIST, to some actual
  ;;;          parameter such that both terms matches.
  ;;; Value:   a list of substitutions, such that each instantiated subterm of gterm (wrt. TAF.LIST) is
  ;;;          a subset of the actual parameters.

  (LET (SUB.TERM NEW.SUBSTS)
    (COND ((NULL TAF.LIST) SUBSTS)
	  (T (SETQ SUB.TERM (DA-ACCESS (CAR TAF.LIST) GTERM))
	     (MAPCAN #'(LAMBDA (ACTUAL.PARAMETER)
			 (COND ((AND (SETQ NEW.SUBSTS (UNI-TERM.MATCH SUB.TERM ACTUAL.PARAMETER T
								      (UNI-ENVIRONMENT (CONS 'KEY COLOUR.KEY))
								      REC*ENVIRONMENT))
				     (SETQ NEW.SUBSTS (UNI-SUBST.LIST.MERGE NEW.SUBSTS SUBSTS)))
				(REC=MSR.SYNTHESIZE.ARGLIST.1 GTERM (CDR TAF.LIST) REC.CALL COLOUR.KEY NEW.SUBSTS))))
		     REC.CALL)))))


(DEFUN REC=MSR.MOVE.UP (GTERM &OPTIONAL ALL.DIFF.EQS CASE.CONDITION ORDERING)

  ;;; Input:   a gterm, a list of literals, the case-condition, and an indicator of an ordering
  ;;; Effect:  tries to move all contexts inside gterm to top-level
  ;;; Value:   the new gterm and a list of literals the disjunction of which ensures that the new gterm
  ;;;          is less than its skeleton wrt. the count ordering.

  (LET ((TAFS (DELETE NIL (DA-GTERM.MAX.FADED.GTERMS GTERM 'RECURSION)))
	NEW.GTERM NEW.DIFF.EQS)
    (COND ((NULL TAFS) (VALUES GTERM ALL.DIFF.EQS))
	  (T (COND ((MULTIPLE-VALUE-SETQ (NEW.GTERM NEW.DIFF.EQS)
		      (REC=MSR.MOVE.UP.EQN GTERM (CAR TAFS) ALL.DIFF.EQS CASE.CONDITION ORDERING))
		    (VALUES NEW.GTERM NEW.DIFF.EQS))
		   ((MULTIPLE-VALUE-SETQ (NEW.GTERM NEW.DIFF.EQS)
		      (REC=MSR.MOVE.UP.TAUT GTERM (CAR TAFS) ALL.DIFF.EQS CASE.CONDITION ORDERING))
		    (VALUES NEW.GTERM NEW.DIFF.EQS)))))))


(DEFUN REC=MSR.MOVE.UP.EQN (GTERM TAF &OPTIONAL ALL.DIFF.EQS CASE.CONDITION ORDERING)

  (LET (D.E NEW.GTERM NEW.DIFF.EQS SUBSTS)
    (COND ((DB-MODIFIER.SELECTION
	    (DA-ACCESS TAF GTERM) 'MOVE.UP NIL
	    #'(LAMBDA (MODIFIER)
		(COND ((AND (SETQ D.E (GETF (DA-MODIFIER.ATTRIBUTES MODIFIER) 'ARG.LIMITED))
			    (MULTIPLE-VALUE-SETQ (SUBSTS NEW.GTERM)
			      (REC=MSR.MODIFIER.TEST MODIFIER GTERM TAF 'RECURSION CASE.CONDITION ORDERING)))
		       (MULTIPLE-VALUE-SETQ (NEW.GTERM NEW.DIFF.EQS)
			 (REC=MSR.MOVE.UP NEW.GTERM (APPEND (REC=MSR.INST.DIFF.EQ D.E (CAR SUBSTS)) ALL.DIFF.EQS)
					  CASE.CONDITION ORDERING))))))
	   (VALUES NEW.GTERM NEW.DIFF.EQS))
	  ((DB-MODIFIER.SELECTION
	    (DA-ACCESS TAF GTERM) 'REMOVE NIL
	    #'(LAMBDA (MODIFIER)
		(COND ((MULTIPLE-VALUE-SETQ (SUBSTS NEW.GTERM)
			 (REC=MSR.MODIFIER.TEST MODIFIER GTERM TAF 'RECURSION CASE.CONDITION ORDERING))
		       (MULTIPLE-VALUE-SETQ (NEW.GTERM NEW.DIFF.EQS)
			 (REC=MSR.MOVE.UP NEW.GTERM ALL.DIFF.EQS CASE.CONDITION ORDERING))))))
	   (VALUES NEW.GTERM NEW.DIFF.EQS))
	  ((REC=PROVE.DISJUNCTION (CONS (DA-LITERAL.CREATE '+ (DA-PREDICATE.EQUALITY)
								      (LIST GTERM (DA-GTERM.SOME.SKELETON GTERM 'RECURSION)))
					CASE.CONDITION)
				  (LIST ORDERING))
	   (VALUES (DA-GTERM.SOME.SKELETON GTERM 'RECURSION) NEW.DIFF.EQS)))))


(DEFUN REC=MSR.MOVE.UP.TAUT (GTERM TAF &OPTIONAL ALL.DIFF.EQS CASE.CONDITION ORDERING)

  ;;; Input:   a gterm, a term-access function, a list of diffence equivalents, a case condition and the actual ordering
  ;;; Effect:  tries to recolour gterm such that the skeleton moves inside and the new context can be reduced
  ;;;          by some c-equation.
  ;;; Value:   a multiple-vale: the new gterm and a list diffence equivalents.

  (LET (SUB.TERM NEW.GTERM NEW.DIFF.EQS)
    (SETQ SUB.TERM (DA-ACCESS (CDR TAF) GTERM))
    (MAPL #'(LAMBDA (SUB.COLOUR.TAF)
	      (COND ((NULL NEW.GTERM)
		     (LET ((ARGUMENT (DA-ACCESS SUB.COLOUR.TAF SUB.TERM)) (COUNTER 0))
		       (COND ((AND (EQ (DA-TERM.SYMBOL SUB.TERM)
				       (DA-TERM.SYMBOL ARGUMENT))
				   (EVERY #'(LAMBDA (ARG1 ARG2)
					      (INCF COUNTER)
					      (COND ((EQL COUNTER (CAR TAF)))
						    (T (AND (DA-GTERM.IS.FADE ARG2 'RECURSION)
							    (UNI-TERM.ARE.EQUAL ARG1 ARG2)))))
					  (DA-TERM.TERMLIST SUB.TERM)
					  (DA-TERM.TERMLIST ARGUMENT))
				   (SETQ NEW.GTERM (REC=MSR.ELIMINATE.CONTEXT GTERM (CDR TAF)
									      (REC=MSR.TAUT.RECOLOUR.TERM
									       SUB.TERM SUB.COLOUR.TAF (CAR TAF))
									      CASE.CONDITION ORDERING)))
			      (MULTIPLE-VALUE-SETQ (NEW.GTERM NEW.DIFF.EQS)
				(REC=MSR.MOVE.UP NEW.GTERM ALL.DIFF.EQS CASE.CONDITION ORDERING))))))))
	    (DA-TAF.COMMON.TAF (DA-GTERM.MAX.COLOURED.GTERMS SUB.TERM 'RECURSION)))
    (VALUES NEW.GTERM NEW.DIFF.EQS)))


(DEFUN REC=MSR.ELIMINATE.CONTEXT (GTERM TAF SUB.TERM CASE.CONDITION ORDERING)

  ;;; Input:   a gterm, a term-access function denoting sub.term, a case condition and the actual ordering
  ;;; Effect:  tests, whether sub.term can be reduced by some c-equation. In case it can the subterm of
  ;;;          gterm, denoted by taf- is replaced by the simplified sub.term.

  (LET (SUBSTS NEW.GTERM)
    (COND ((DB-MODIFIER.SELECTION
	    SUB.TERM 'REMOVE NIL
	    #'(LAMBDA (MODIFIER)
		(AND (NULL (DA-MODIFIER.INPUT.TAF MODIFIER))
		     (MULTIPLE-VALUE-SETQ (SUBSTS NEW.GTERM)
		       (REC=MSR.MODIFIER.TEST MODIFIER SUB.TERM NIL 'RECURSION CASE.CONDITION ORDERING)))))
	   (DA-REPLACE TAF GTERM NEW.GTERM)))))


(DEFUN REC=MSR.TAUT.RECOLOUR.TERM (TERM TAF POS)
  
  (LET ((SUB.TERM (DA-ACCESS TAF TERM))
	(COUNTER1 0) (COUNTER2 0))
    (DA-TERM.CREATE (DA-TERM.SYMBOL TERM)
		    (MAPCAR #'(LAMBDA (ARG2)
				(INCF COUNTER1)
				(COND ((EQL COUNTER1 POS)
				       (DA-REPLACE (BUTLAST TAF) (DA-TERM.COPY ARG2)
						   (DA-TERM.CREATE (DA-TERM.SYMBOL TERM)
								   (MAPCAR #'(LAMBDA (ARG1 ARG2)
									       (INCF COUNTER2)
									       (COND ((EQL COUNTER2 POS) ARG2)
										     (T (DA-GTERM.COPY ARG1))))
									   (DA-TERM.TERMLIST TERM)
									   (DA-TERM.TERMLIST SUB.TERM))
								   (LIST 'RECURSION (DA-GTERM.COLOUR TERM 'RECURSION)))))
				      (T (DA-GTERM.COPY ARG2))))
			    (DA-TERM.TERMLIST SUB.TERM))
		    (LIST 'RECURSION (DA-GTERM.COLOUR SUB.TERM 'RECURSION)))))


(DEFUN REC=MSR.MODIFIER.TEST (MODIFIER GTERM TAF COLOUR.KEY CASE.CONDITION ORDERING)

  ;;; Input:   a modifier, a gterm, a term-access function, the colour key for the modifier, the case conditions and
  ;;;          an indicator of an ordering
  ;;; Effect:  tests whether modifier is applicable, the conditions of modifier are instances of the case conditions
  ;;; Value:   a list of substitutions, and the modified gterm (by application of modifier) in case the modifier is
  ;;;          applicable and nil else.

  (LET* ((ADJUSTMENT.TAF (DA-MODIFIER.INPUT.TAF MODIFIER))
	 (APPLY.TAF (DA-TAF.SUPER.TAF TAF (DA-TAF.LENGTH ADJUSTMENT.TAF)))
	 APPLY.GTERM SUBSTS)
    (COND ((>= (DA-TAF.LENGTH TAF) (DA-TAF.LENGTH ADJUSTMENT.TAF))
	   (SETQ APPLY.GTERM (DA-ACCESS APPLY.TAF GTERM))
	   (COND ((AND (SETQ SUBSTS (UNI-TERM.MATCH (DA-MODIFIER.INPUT MODIFIER)
						    APPLY.GTERM T
						    (UNI-ENVIRONMENT (CONS 'KEY (DA-CMODIFIER.SOLUTION MODIFIER)))
						    (UNI-ENVIRONMENT (CONS 'KEY COLOUR.KEY))
						    (LIST (CONS ADJUSTMENT.TAF (SUBSEQ TAF 0 (LENGTH ADJUSTMENT.TAF))))))
		       (EVERY #'(LAMBDA (LIT)
				(AND (DA-LITERAL.IS LIT)
				     (REC=PROVE.DISJUNCTION (CONS (DA-LITERAL.NEGATE (UNI-SUBST.APPLY (CAR SUBSTS) LIT))
								  CASE.CONDITION)
							    (LIST ORDERING))))
			      (DA-MODIFIER.CONDITION MODIFIER)))
		  (SETQ GTERM (DA-TERM.COPY GTERM))
		  (VALUES SUBSTS (DA-REPLACE APPLY.TAF GTERM
					     (UNI-SUBST.APPLY (CAR SUBSTS) (DA-MODIFIER.VALUE MODIFIER)
							      NIL
							      (UNI-ENVIRONMENT (CONS 'KEY (DA-CMODIFIER.SOLUTION MODIFIER)))
							      'RECURSION)))))))))


(DEFUN REC=MSR.INST.DIFF.EQ (DIFF.EQ SUBST)

  ;;; Input:   a list of literal-lists
  ;;; Effect:  instantiates DIFF.EQ by the substitution
  ;;; Value:   the instantiated and concatenated list.
  
  (MAPCAN #'(LAMBDA (LITS)
	      (MAPCAR #'(LAMBDA (LIT)
			  (UNI-SUBST.APPLY SUBST LIT))
		      LITS))
	  DIFF.EQ))


;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 1.1
;;;;; -----------
;;;;;
;;;;; Computation recursive calls
;;;;;--------------------------------------------------------------------------------------------------------

(DEFUN REC=DETERMINE.RECURSIVE.CALLS (VALUE SYMBOL)

  ;; Input:  a term and a function or predicate symbol
  ;; Value:  lists the termlists of the calls of SYMBOL in VALUE.
  
  (LET (CALLS)
    (MAPC #'(LAMBDA (TAF)
	      (SETQ CALLS (ADJOIN (DA-ACCESS TAF VALUE) CALLS :TEST
				  #'(LAMBDA (X Y) (UNI-TERMLIST.ARE.EQUAL (DA-GTERM.TERMLIST X) (DA-GTERM.TERMLIST Y))))))
	  (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL VALUE))
    CALLS))


(DEFUN REC=REC.POSITIONS.FROM.DECL.DEF (SYMBOL INPUT VALUE)
  ;;; edited : 23.03.93 by CS
  ;;; input  : a function or predicate symbol
  ;;; value  : a list of recursive positions of the formal parameters of symbol

  (REC=REC.POSITIONS.FROM.DECL.DEF.ARGUMENTS
   (DA-GTERM.TERMLIST INPUT)
   (MAPCAR #'(LAMBDA (TAF)
	       (DA-GTERM.TERMLIST (DA-ACCESS TAF VALUE)))
	   (DA-SYMBOL.OCCURS.IN.GTERM symbol VALUE))))


(DEFUN REC=REC.POSITIONS.FROM.DECL.DEF.ARGUMENTS (FORMAL.PARAMETERS LIST.OF.ACTUAL.PARAMETERS)
  ;;; edited : 23.03.93 by CS
  ;;; input  : a list of formal parameters, and a list of lists, containing the actual calls,
  ;;;          that is the actual parameters
  ;;; value  : a list of recursive positions of the formal parameters

  (LET (RESULT)
    (MAPC #'(LAMBDA (ACTUAL.PARAMETERS)
	      (LET ((COUNTER 0))
		(MAPC #'(LAMBDA (FORMAL ACTUAL)
			  (INCF COUNTER)
			  (COND ((MEMBER COUNTER RESULT))
				((UNI-TERM.ARE.EQUAL FORMAL ACTUAL))
				((DA-SYMBOL.IS.STRUCTURE (DA-TERM.SYMBOL FORMAL))
				 (SETQ RESULT (CONS COUNTER RESULT)))
				((AND (DA-VARIABLE.IS (DA-TERM.SYMBOL FORMAL))
				      (DA-FUNCTION.IS (DA-TERM.SYMBOL ACTUAL))
				      (OR (DA-FUNCTION.IS.SELECTOR (DA-TERM.SYMBOL ACTUAL))
					  (DA-FUNCTION.IS.INDEX (DA-TERM.SYMBOL ACTUAL)))
				      (DA-GTERM.OCCURS.IN.GTERM FORMAL ACTUAL))
				 (SETQ RESULT (CONS COUNTER RESULT)))))
		      FORMAL.PARAMETERS ACTUAL.PARAMETERS)))
	  LIST.OF.ACTUAL.PARAMETERS)
    RESULT))


;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 1.2
;;;;; -----------
;;;;;
;;;;; Computation of the difference equivalent
;;;;;--------------------------------------------------------------------------------------------------------



(DEFUN REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT (TERM1 TERM2)

  ;;; Edited: 21-Jan-87 by DH
  ;;; Input:  TERM1, TERM2: two terms denoting q and r
  ;;; Effect: the gamma-difference-equivalent of TERM1 and TERM2 is computed.
  ;;; Value:  a list of literals whose disjunction denotes the gamma-difference-equivalent including 
  ;;;         the literal false if both terms are equal.
  ;;; Note:   Currently only one differnce clause is computed, since no non-artificial examples necessitating
  ;;;         the difference equivalent are known.

  (LET ((DIFF.EQ (REC=GAMMA.DIFF.OR.EQ.EQUIVALENT TERM1 TERM2)))
    (COND ((CDR DIFF.EQ) (DELETE-IF #'DA-LITERAL.IS.FALSE DIFF.EQ))
	  (T DIFF.EQ))))



(DEFUN REC=GAMMA.DIFF.OR.EQ.EQUIVALENT (TERM1 TERM2)

  ;;; Edited: 21-Jan-87 by DH, revised 02.09.93 by CS
  ;;; Input:  TERM1, TERM2: two terms denoting q and r.
  ;;; Effect: the gamma-difference-equivalent of TERM1 and TERM2 is computed. e.g. g-d-e -> TERM1 < TERM2
  ;;; Value:  a list of literals whose disjunction denotes the gamma-difference-equivalent including 
  ;;;         the literal false if both terms are equal.
  ;;; new:    the E-calculus is extended to handle also subtypes and non free data structures

  (LET* ((SORT1 (DA-TERM.SORT TERM1)) (SORT2 (DA-TERM.SORT TERM2))
	 (SYMBOL1 (DA-TERM.SYMBOL TERM1)) (SYMBOL2 (DA-TERM.SYMBOL TERM2))
	 (CONSTRUCTOR1 (AND (DA-FUNCTION.IS SYMBOL1) (DA-FUNCTION.IS.CONSTRUCTOR SYMBOL1)))
	 (CONSTRUCTOR2 (AND (DA-FUNCTION.IS SYMBOL2) (DA-FUNCTION.IS.CONSTRUCTOR SYMBOL2)))
	 ABSTRACTION.FUNCTION NEW.LITS RESULT REFLEXIVE.POSITIONS)
    (COND
     ((NULL (DELETE (DP-SORT.TOP.LEVEL.SORT)
		    (INTERSECTION (DA-SORT.ALL.SUPERSORTS SORT1) (DA-SORT.ALL.SUPERSORTS SORT2))))
      (LIST (DA-LITERAL.FALSE)))
      ; a. "identy axiom"
      ((UNI-TERM.ARE.EQUAL TERM1 TERM2)
       (LIST (DA-LITERAL.FALSE)))

      ; b. "equality axiom"
      ((AND CONSTRUCTOR1
	    CONSTRUCTOR2
	    (or (not (da-sort.is.ENUMERATE.STRUCTURE sort1))
		(not (eq sort1 sort2)))
	    (NOT (DA-FUNCTION.IS.REFLEXIVE SYMBOL1))
	    (NOT (DA-FUNCTION.IS.REFLEXIVE SYMBOL2)))
       (LIST (DA-LITERAL.FALSE)))

      ((AND (da-sort.is.ENUMERATE.STRUCTURE sort1)
	    CONSTRUCTOR1
	    CONSTRUCTOR2
	    (eq sort1 sort2)
	    (member symbol2 (member symbol1 (da-sort.constructor.fcts sort1))))
       (LIST (DA-LITERAL.TRUE)))

      ; c. "strong estimation axiom"
      ((AND CONSTRUCTOR1
	    CONSTRUCTOR2              
	    (NOT (DA-FUNCTION.IS.REFLEXIVE SYMBOL1))
	    (DA-FUNCTION.IS.REFLEXIVE SYMBOL2)
	    (DA-FUNCTION.HAS.DISJUNCT.RANGE SYMBOL2))
       (LIST (DA-LITERAL.TRUE)))

      ; d1. "strong embedding rule for free constructors"
      ((AND CONSTRUCTOR2                        
	    (SETQ REFLEXIVE.POSITIONS (DA-FUNCTION.IS.REFLEXIVE SYMBOL2))
	    (DA-FUNCTION.HAS.DISJUNCT.RANGE SYMBOL2)
	    (EVERY #'(LAMBDA (POSITION)
		       (DA-FUNCTION.IS.INJECTIVE SYMBOL2 POSITION))
		   REFLEXIVE.POSITIONS)
	    (SOME #'(LAMBDA (POSITION)
		      (REC=GAMMA.DIFF.OR.EQ.EQUIVALENT TERM1 (NTH (1- POSITION) (DA-TERM.TERMLIST TERM2))))
		  REFLEXIVE.POSITIONS))
       (LIST (DA-LITERAL.TRUE)))

      ; d2. "strong embedding rule for monotonic constructors"
      ((AND CONSTRUCTOR2                        
	    (SETQ REFLEXIVE.POSITIONS (DA-FUNCTION.IS.REFLEXIVE SYMBOL2))
	    (DA-FUNCTION.HAS.DISJUNCT.RANGE SYMBOL2)
	    (DA-FUNCTION.IS.MONOTONIC SYMBOL2)
	    (MAPCAN #'(LAMBDA (POSITION)
			(COND ((SETQ NEW.LITS
				 (REC=GAMMA.DIFF.OR.EQ.EQUIVALENT TERM1 (NTH (1- POSITION) (DA-TERM.TERMLIST TERM2))))
			       (CONS (DA-LITERAL.CREATE
				      (DA-SIGN.MINUS) (DA-PREDICATE.EQUALITY)
				      (COND ((SETQ ABSTRACTION.FUNCTION
						   (GETF (DA-FUNCTION.ATTRIBUTES SYMBOL2) 'ABSTRACTION.FUNCTION))
					     (LIST (DA-TERM.CREATE ABSTRACTION.FUNCTION (LIST (DA-TERM.COPY TERM2)))
						   (DA-TERM.CREATE
						    ABSTRACTION.FUNCTION
						    (LIST (DA-TERM.COPY (NTH (1- POSITION) (DA-TERM.TERMLIST TERM2)))))))
					    (T (LIST (DA-TERM.COPY TERM2)
						     (DA-TERM.COPY (NTH (1- POSITION) (DA-TERM.TERMLIST TERM2)))))))
				     NEW.LITS))))
		    REFLEXIVE.POSITIONS)))
      
      ; e. "weak embedding rule free constructors"
      ((AND CONSTRUCTOR1
	    (SETQ REFLEXIVE.POSITIONS (DA-FUNCTION.IS.REFLEXIVE SYMBOL1))   
	    (EQ SYMBOL1 SYMBOL2)
	    (DA-FUNCTION.HAS.DISJUNCT.RANGE SYMBOL1)
	    (EVERY #'(LAMBDA (POSITION)
		       (DA-FUNCTION.IS.INJECTIVE SYMBOL1 POSITION))
		   REFLEXIVE.POSITIONS)
	    (progn (SETQ RESULT NIL)
		   (EVERY #'(LAMBDA (POSITION)
			      (COND ((SETQ NEW.LITS (REC=GAMMA.DIFF.OR.EQ.EQUIVALENT
						     (NTH (1- POSITION) (DA-TERM.TERMLIST TERM1))
						     (NTH (1- POSITION) (DA-TERM.TERMLIST TERM1))))
				     (SETQ RESULT (NCONC RESULT NEW.LITS)))))
			  REFLEXIVE.POSITIONS)))
       RESULT)
      
      ; f. "minimum axiom"
      ((AND CONSTRUCTOR1 
	    (NOT (da-sort.is.ENUMERATE.STRUCTURE sort1))
	    (NOT (DA-FUNCTION.IS.REFLEXIVE SYMBOL1)))
       (CONS (DA-LITERAL.FALSE)
	     (MAPCAN #'(LAMBDA (TERM)
			 (LIST (DA-LITERAL.CREATE (DA-SIGN.PLUS) (DA-PREDICATE.EQUALITY)
						  (LIST (DA-TERM.COPY TERM2) TERM))))
		     (REC=REFLEXIVE.CONSTRUCTOR.TERMS.WITH.DISJUNCT.RANGE TERM2))))
       
      ; g. "argument estimation rule"
      ((AND (DA-FUNCTION.IS SYMBOL1)
	    (MAPCAN #'(LAMBDA (POSITION)
			(COND ((SETQ NEW.LITS (REC=GAMMA.DIFF.OR.EQ.EQUIVALENT
					       (NTH (1- (CAR POSITION)) (DA-TERM.TERMLIST TERM1)) TERM2))
			       (CONS (DA-LITERAL.CREATE (DA-SIGN.PLUS) (SECOND POSITION)
							(MAPCAR #'DA-TERM.COPY (DA-TERM.TERMLIST TERM1)))
				     NEW.LITS))))
		    (DA-FUNCTION.ARG.LIMITED SYMBOL1)))))))


(DEFUN REC=REFLEXIVE.CONSTRUCTOR.TERMS.WITH.DISJUNCT.RANGE (TERM)
  ;;; EDITED : 02.09.93 BY CS
  ;;; INPUT  : A TERM
  ;;; VALUE  : A LIST OF ALL STRUCTURE TERMS OF THE TERM WHERE THE CONSTRUCTOR
  ;;;          FUNCTION IS REFLEXIVE AND HAS DISJUNCT RANGE, NOTE THAT IN CASE
  ;;;          THE STRUCTURE TERM IS BUILT BY AN INDEX FUNCTION THIS FUNCTION
  ;;;          IS CALLED RECURSIVELY

  (MAPCAN #'(LAMBDA (STRUCTURE.TERM)
	      (LET ((SYMBOL (DA-TERM.SYMBOL STRUCTURE.TERM)))
		(COND ((AND (DA-FUNCTION.IS.CONSTRUCTOR SYMBOL)
			    (DA-FUNCTION.IS.REFLEXIVE SYMBOL)
			    (DA-FUNCTION.HAS.DISJUNCT.RANGE SYMBOL))
		       (LIST STRUCTURE.TERM))
		      ((DA-FUNCTION.IS.INDEX SYMBOL)
		       (REC=REFLEXIVE.CONSTRUCTOR.TERMS.WITH.DISJUNCT.RANGE STRUCTURE.TERM)))))
	  (DA-SORT.CREATE.ALL.STRUCTURE.TERMS TERM NIL)))


;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 1.3
;;;;; -----------
;;;;;
;;;;; Computation of the minimal projections.
;;;;;--------------------------------------------------------------------------------------------------------


(DEFUN REC=TERM.COMPUTE.MINIMAL.PROJECTIONS (CASES COLUMNS)
  
  ;;; Edited:   21-Mar-89 by PB
  ;;; Input:    ANALYZED.CALLS a list of analyzed all recursive calls of a definition.
  ;;;           
  ;;; Effect:   Determines all minimal lexicographical positions of the recursive calls.
  ;;;           If, for a set of argument positions, the disjunction of the difference predicates can 
  ;;;           be proved under the condition of the case, these positions are merged.
  ;;;           
  ;;; Value:    A multiple value : T if the function/predicate terminates and
  ;;;           a list of the minimal positions, that are representated as a sets (lists) of natural 
  ;;;           numbers denoting the argument positions, where 1 denotes the first argument position.
  ;;;           
  ;;; Remark:   This and all following functions dealing with minimal positions use an data
  ;;;           structure called COLUMN:
  ;;;           If we write the argument lists of all recursive calls of the function (or predicate) under
  ;;;           consideration one beneath the other and substitiute each argument with a token denoting the 
  ;;;           relation of the argument (i.e. the actual parameter of the recursive call) to the formal 
  ;;;           parameter, then a COLUMN of this matrix consists of a list containing the column number
  ;;;           and the list of the argument tokens.
  ;;;           The tokens (generated by REC=TERM.CHECK.ACTUAL.CALL) are:
  ;;;             DOWN    , denoting that the actual parameter is strictly less than the formal parameter
  ;;;             EQ      , denoting that the actual and formal parameter are equal
  ;;;             UP      , denoting that neither DOWN nor EQ could be proved
  ;;;             a list  , that contains the difference literals of the actual parameter of the recusive 
  ;;;                       call as cdr and the argument position number(s) as car.
  ;;;           Example:
  ;;;             If the argument token-lists of the recursive calls of a functions were
  ;;;                (EQ DOWN) and (((1) Pred1) ((2) Pred2))
  ;;;             then COLUMNS would be:
  ;;;                (((1) EQ ((1) Pred1)) ((2) DOWN ((2) Pred2)))
  ;;;           For further explanations, see the functions below.
  ;;;           
  ;;;           A (harder) test example is:
  ;;;             If the function under consideration has the following recursive calls (argument tokens
  ;;;             as above):
  ;;;           
  ;;;                      (DOWN      DOWN      DOWN      DOWN      DOWN      DOWN    )
  ;;;                      (DOWN      UP        EQ        DOWN      EQ        UP      )
  ;;;                      (((1) L1)  UP        DOWN      UP        ((5) L2)  ((6) L3))
  ;;;                      (UP        ((2) L4)  ((3) L5)  EQ        DOWN      UP      )
  ;;;           
  ;;;             and minimalty (L1 L2 L3) resp. (L4 L5) can be proved under the condition of the 3. 
  ;;;             resp. 4. case, then all possible minimal positions are:
  ;;;             
  ;;;                      (3 4 5), (3 5 1), (5 1 6), (3 4 2)
  ;;;           
  ;;;             (The 1. and 2. solution can be obtained without merging, the 3. in merging literals 
  ;;;              of positions 1, 5 and 6, the 4. in merging positions 2 and 3)
  
  (COND
   (CASES
    (LET* (RESULT
	   (NUMBER.OF.RECURSIVE.CALLS (LENGTH CASES))
	   (INIT.COLUMN (CONS NIL (MAKE-LIST NUMBER.OF.RECURSIVE.CALLS :INITIAL-ELEMENT 'EQ)))
	   (MERGEABLE.LITS (MAKE-LIST NUMBER.OF.RECURSIVE.CALLS :INITIAL-ELEMENT NIL))
	   (NOT.MERGEABLE.LITS (MAKE-LIST NUMBER.OF.RECURSIVE.CALLS :INITIAL-ELEMENT NIL))
	   (MINIMAL.POSITIONS.WITHOUT.MERGING       ;; First calculate minimal positions without merging
	    (REC=MINIMAL.LEXICOGRAPHIC.POSITIONS    ;; to avoid not minimal mergings later.
	     INIT.COLUMN COLUMNS NIL CASES
	     MERGEABLE.LITS NOT.MERGEABLE.LITS NIL NIL)))
      (SETQ RESULT (REC=MINIMAL.LEXICOGRAPHIC.POSITIONS
		    INIT.COLUMN COLUMNS NIL CASES
		    MERGEABLE.LITS NOT.MERGEABLE.LITS T MINIMAL.POSITIONS.WITHOUT.MERGING))
      (VALUES RESULT RESULT)))
   (T (VALUES T NIL))))


(DEFUN REC=MINIMAL.LEXICOGRAPHIC.POSITIONS (RESULT.COLUMN COLUMNS COLUMNS.USE.LATER CONDS
					    MERGEABLE.LITS NOT.MERGEABLE.LITS ENABLE.MERGING
					    CURRENT.POSITIONS)

  ;;; Edited:   10-Mar-89 by PB
  ;;; Input:    RESULT.COLUMN:      Initially a list (NIL EQ EQ ... EQ), the number of EQs equals the 
  ;;;                               number of the recursive calls of the funcion under consideration.
  ;;;           COLUMNS:            Initially all columns that have to be considered (for a definition
  ;;;                               of a COLUMN see above)
  ;;;           COLUMNS.USE.LATER:  Initially NIL.
  ;;;           CONDS               A list of conditions belonging to the rows.
  ;;;           MERGEABLE.LITS:     Initially a list (NIL ... NIL), length equals number of recursive calls.
  ;;;           NOT.MERGEABLE.LITS: Same as MERGEABLE.LITS.
  ;;;           ENABLE.MERGING:     T, if merging should be tried, else NIL.
  ;;;           CURRENT.POSITIONS:  Initially NIL.
  ;;;           
  ;;; Effect:   The algorithm recursively calculates all minimal sets of argument positions that satisfy 
  ;;;           the following condition: A permutation of the positions can be found that is a 
  ;;;           lexicographical order for the termination of the function under consideration.
  ;;;           
  ;;; Value:    A list of lists (i.e. sets) of natural numbers. (See: 'Effect')
  ;;;           
  ;;; Remark:   The algorithm works as follows:
  ;;;           The algorithm takes subsequently each COLUMN that is suitable for the result, i.e., 
  ;;;           that contains a DOWN in a row, where RESULT.COLUMN doesn't, and contains no UP where 
  ;;;           RESULT.COLUMN has anything other than DOWN. If such a COLUMN can be found, the function 
  ;;;           is recursively called with this COLUMN added to RESULT.COLUMN and the remainig COLUMNS
  ;;;           as new candidates (The CAR of RESULT.COLUMN accumulates the position numbers). 
  ;;;           The optimization step is, that the position lists have to be treated as sets, 
  ;;;           i.e. permutating solutions should be avoided. Thus only the remaining columns 
  ;;;           right of a suitable COLUMN have to be regarded in therecursion step. The only 
  ;;;           exception is, that a COLUMN has a 'new' DOWN, but it is not suitable because 
  ;;;           of an UP elsewhere. This columns are candiates in a later recursion step, but
  ;;;           only, if any other suitable COLUMN can be found on the right! These columns 
  ;;;           are remembered in NEW.COLUMNS.USE.LATER. COLUMNS.USE.LATER are those columns 
  ;;;           of a previous step and have to be regarded as candidates second. CURRENT.POSITIONS 
  ;;;           serves as accumulator of the resulting positions so far. An extension of the 
  ;;;           lexicographic order is to regard sets of COLUMNS, contain difference literals
  ;;;           in the sme row (i.e. in the argument list of a specific recursive call of the 
  ;;;           function under consideration). If the disjunctionof the literals can be proved 
  ;;;           under the condition of the according CONDS.IF.THEN.CASES, this list of literals
  ;;;           can be treated as DOWN. Therefore, if the ENABLE.MERGING switch is T, also COLUMNS 
  ;;;           are suitable as candidates (see above), that contain difference literals in a row 
  ;;;           instead of an explicit DOWN. The merging procedure and optimizations, as avoiding 
  ;;;           useless proofs, are explained below in the function REC=MINIMAL.POS.GET.NEW.RESULT.COLUMN.

  (LET (RESULT NEW.COLUMNS.USE.LATER)
    (COND ((EVERY #'(LAMBDA (ROW) (EQ ROW 'DOWN)) (CDR RESULT.COLUMN))       ;; All rows contain DOWN.
	   (SETQ RESULT (CAR RESULT.COLUMN))
	   (COND ((NOTANY #'(LAMBDA (CURRENT.POSITION)                       ;; Test the minimality.
			      (SUBSETP CURRENT.POSITION RESULT :TEST #'EQL))
			  CURRENT.POSITIONS)
		  (SETQ CURRENT.POSITIONS (CONS RESULT
						(DELETE-IF #'(LAMBDA (CURRENT.POSITION)
							       (SUBSETP RESULT CURRENT.POSITION :TEST #'EQL))
							   CURRENT.POSITIONS))))))
	  (T (MULTIPLE-VALUE-SETQ (CURRENT.POSITIONS NEW.COLUMNS.USE.LATER)
	       (REC=MINIMAL.POS.TRY.ALL.CANDIDATES
		RESULT.COLUMN COLUMNS           COLUMNS.USE.LATER   CONDS
		MERGEABLE.LITS NOT.MERGEABLE.LITS ENABLE.MERGING CURRENT.POSITIONS))
	     (MULTIPLE-VALUE-SETQ (CURRENT.POSITIONS NEW.COLUMNS.USE.LATER)
	       (REC=MINIMAL.POS.TRY.ALL.CANDIDATES
		RESULT.COLUMN COLUMNS.USE.LATER NEW.COLUMNS.USE.LATER CONDS
		MERGEABLE.LITS NOT.MERGEABLE.LITS ENABLE.MERGING CURRENT.POSITIONS))))
    CURRENT.POSITIONS))


(DEFUN REC=MINIMAL.POS.TRY.ALL.CANDIDATES
       (RESULT.COLUMN CANDIATE.COLUMNS COLUMNS.USE.LATER CONDS
	MERGEABLE.LITS NOT.MERGEABLE.LITS ENABLE.MERGING CURRENT.POSITIONS)

  ;;; Edited:   10-Mar-89 by PB
  ;;; Input:    RESULT.COLUMN:      The COLUMN accumulated so far.
  ;;;           CANDIDATE.COLUMNS:  All COLUMNS that have to be tested for suitability.
  ;;;           COLUMNS.USE.LATER:  COLUMNS that that are candidates for the next recursion step.
  ;;;           CONDS             : A list of conditions belonging to the rows.
  ;;;           MERGEABLE.LITS:     A bag for difference literals, that could be poved at a previous time.
  ;;;           NOT.MERGEABLE.LITS: A bag for difference literals, that could not be proved at a previous
  ;;;                               time.
  ;;;           ENABLE.MERGING:     T, if merging should be tried, else NIL.
  ;;;           CURRENT.POSITIONS:  The list of minimal positions calculated so far.
  ;;;           
  ;;; Effect:   This function contains the iteration over a given list of candidate columns for the function 
  ;;;           REC=MINIMAL.LEXICOGRAPHIC.POSITIONS and also contains the recursive call of
  ;;;           REC=MINIMAL.LEXICOGRAPHIC.POSITIONS 
  ;;;           (Think of this function as spread into the definition of the function!).
  ;;;           See REC=MINIMAL.LEXICOGRAPHIC.POSITIONS for a description of the algorithm.
  ;;;           
  ;;; Value:    Two values: The list of minimal positions calculated now and those COLUMNS that 
  ;;;                       introduced a new DOWN but also at least one new UP and have to be
  ;;;                       remembered for a later use.
  
  (LET ((NEW.COLUMNS.USE.LATER NIL) ACTUAL.COLUMN NEW.RESULT.COLUMN)
    (MAPL
     #'(LAMBDA (CANDIDATE.LIST)
	 (SETQ ACTUAL.COLUMN (CAR CANDIDATE.LIST))
	 (COND
	   ;; Take ACTUAL.COLUMN as candidate only, if it contains at least one new DOWN,
	   ;; or a list of difference literals, if merging is enabled.
	   ((SOME #'(LAMBDA (RESULT.ROW ACTUAL.ROW)            
		      (AND (NOT (EQ RESULT.ROW 'DOWN))          
			    (OR (EQ ACTUAL.ROW 'DOWN)           
				(AND ENABLE.MERGING             
				     (CONSP ACTUAL.ROW)))))
		   (CDR RESULT.COLUMN) (CDR ACTUAL.COLUMN))
	     (COND
	       ;; Don't take it, if it would introduce a new UP. In this case, store it in
	       ;; NEW.COLUMNS.USE.LATER for later use in the next recursion step (below).
	       ((NOTANY #'(LAMBDA (RESULT.ROW ACTUAL.ROW)       
			    (AND (NOT (EQ RESULT.ROW 'DOWN))    
				 (EQ ACTUAL.ROW 'UP)))          
			(CDR RESULT.COLUMN) (CDR ACTUAL.COLUMN))
		(COND
		  ((SETQ NEW.RESULT.COLUMN                      ;; If new RESULT.COLUMN is not yet a superset
			 (REC=MINIMAL.POS.GET.NEW.RESULT.COLUMN ;;  of a solution calculated so far
			   RESULT.COLUMN ACTUAL.COLUMN CONDS
			   MERGEABLE.LITS NOT.MERGEABLE.LITS
			   ENABLE.MERGING CURRENT.POSITIONS))   ;; (CURRENT.POSITIONS),
		   (SETQ CURRENT.POSITIONS                      ;; recurse with the new RESULT.COLUMN and 
			 (REC=MINIMAL.LEXICOGRAPHIC.POSITIONS   ;; the columns as new candidates.
			   NEW.RESULT.COLUMN (CDR CANDIDATE.LIST)
			   (APPEND NEW.COLUMNS.USE.LATER        ;; Now NEW.COLUMNS.USE.LATER may contain 
				   COLUMNS.USE.LATER)           ;; suitable candidates, thus supply them 
			   CONDS MERGEABLE.LITS                 ;; for the next recursion step.
			   NOT.MERGEABLE.LITS ENABLE.MERGING CURRENT.POSITIONS)))))
	       (T (PUSH ACTUAL.COLUMN NEW.COLUMNS.USE.LATER))))))
      CANDIATE.COLUMNS)
    (VALUES CURRENT.POSITIONS NEW.COLUMNS.USE.LATER)))


(DEFUN REC=MINIMAL.POS.GET.NEW.RESULT.COLUMN
       (RESULT.COLUMN ACTUAL.COLUMN CONDS MERGEABLE.LITS NOT.MERGEABLE.LITS
	ENABLE.MERGING CURRENT.POSITIONS)

  ;;; Edited:   21-Mar-89 by PB
  ;;; Input:    RESULT.COLUMN:      The COLUMN accumulated so far.
  ;;;           ACTUAL.COLUMN:      The COLUMN, that should be added on the right of RESULT.COLUMN.
  ;;;           CONDS:              A list of conditions belonging to the rows.
  ;;;           MERGEABLE.LITS:     A bag for difference literals, that could be poved at a previous time.
  ;;;           NOT.MERGEABLE.LITS: A bag for difference literals, that could not be poved at a
  ;;;                               previous time.
  ;;;           ENABLE.MERGING:     T, if merging should be tried, else NIL.
  ;;;           CURRENT.POSITIONS:  The list of minimal positions calculated so far.
  ;;;           
  ;;; Effect:   This function returns the new RESULT.COLUMN adding the ACTUAL.COLUMN on the right of 
  ;;;           RESULT.COLUMN in the way of left-lexicographic ordering. If ENABLE.MERGING is T and 
  ;;;           a list of difference listerals of ACTUAL.COLUMN has to be added to a list of difference 
  ;;;           listerals of RESULT.COLUMN, the disjunction of the literals of both lists is tried to 
  ;;;           be proved under the condtion of the according CONDS. If the proof is
  ;;;           successful, the literals are stored in MERGEABLE.LITS, else in NOT.MERGEABLE.LITS. 
  ;;;           These lists are searched every time before any proving effort is invested to avoid
  ;;;           frequent proofs of the same formula.
  ;;;           
  ;;; Value:    The new RESULT.COLUMN, or NIL, if the positions are yet a solution.

  (LET ((NEW.POSITION (APPEND (CAR RESULT.COLUMN) (CAR ACTUAL.COLUMN)))
	DIFFERENCE.LITERALS RESULT.ROW ACTUAL.ROW)
    (COND
      ((OR (NOT ENABLE.MERGING)                                             ;; If merging is enabled, test 
	   (NOTANY #'(LAMBDA (CURRENT.POSITION)                             ;; first, if the new RESULT.COLUMN
		       (SUBSETP CURRENT.POSITION NEW.POSITION :TEST #'EQL)) ;; is not yet solution, to avoid 
		   CURRENT.POSITIONS))                                      ;; useless proving effort.
       (CONS
	 NEW.POSITION
	 (MAPLIST
	   #'(LAMBDA (RESULT.ROWS ACTUAL.ROWS CONDS.LIST
		      MERGEABLE.LITLIST NOT.MERGEABLE.LITLIST)
	       (SETQ RESULT.ROW (CAR RESULT.ROWS)
		     ACTUAL.ROW (CAR ACTUAL.ROWS))
	       (COND
		 ((EQ RESULT.ROW 'DOWN)                          ;; If RESULT.ROW is DOWN, ACTUAL.ROW is not
		  'DOWN)                                         ;; of interest (due to left-lexicogr. order)
		 ((OR (NOT ENABLE.MERGING) (EQ ACTUAL.ROW 'DOWN));; If merging is disabled, take ACTUAL.ROW 
		  ACTUAL.ROW)                                    ;; (that can't be UP) in all cases.
		 ((EQ RESULT.ROW 'EQ)
		  ACTUAL.ROW)
		 ((EQ ACTUAL.ROW 'EQ)
		  RESULT.ROW)
		 (T (SETQ DIFFERENCE.LITERALS
			  ;; If both rows contain listeral-lists, get actual set of DIFFERENCE.LITERALS in substitution
 			  ;; appending the position-lists and literal-lists.
			  (CONS (APPEND (CAR RESULT.ROW) (CAR ACTUAL.ROW))
				(APPEND (CDR RESULT.ROW) (CDR ACTUAL.ROW))))
		    (COND                                                  
		      ((FIND-IF
			 #'(LAMBDA (MERGEABLE.LITERALS)      ;; If a subset of DIFFERENCE.LITERALS has been
			     (SUBSETP                        ;; proved at a previous time, DOWN can be
			       (CDR MERGEABLE.LITERALS) (CDR DIFFERENCE.LITERALS)   ;; substituted.
				      :TEST #'EQ))
			 (CAR MERGEABLE.LITLIST))
		       'DOWN)
		      ((FIND-IF                                ;; If a superset of DIFFERENCE.LITERALS can be
			 #'(LAMBDA (NOT.MERGEABLE.LITERALS)    ;; found, that could not be proved at a prev.
			     (SUBSETP (CDR DIFFERENCE.LITERALS);; time, DIFFERENCE.LITERALS can't be proved
				      (CDR NOT.MERGEABLE.LITERALS)   ;; either and is returned for later use.
				      :TEST #'EQ))
			 (CAR NOT.MERGEABLE.LITLIST))
		       DIFFERENCE.LITERALS)
		      (T (COND
			   ((REC=PROVE.DISJUNCTION                   ;; Start the prover.
			      (APPEND (CAR CONDS.LIST) (CDR DIFFERENCE.LITERALS))
			      (CAR DIFFERENCE.LITERALS))              ;; This are the according argument pos.
			    (PUSH DIFFERENCE.LITERALS (CAR MERGEABLE.LITLIST))
			    ;; If proof was successful, save information and return 'DOWN.
			    'DOWN)                                                  
			   (T
			    (PUSH DIFFERENCE.LITERALS (CAR NOT.MERGEABLE.LITLIST))
			    ;; Else remember literals not provable and return them for later use.
			    DIFFERENCE.LITERALS)))))))                              
	   (CDR RESULT.COLUMN) (CDR ACTUAL.COLUMN) CONDS
	   MERGEABLE.LITS NOT.MERGEABLE.LITS))))))



;;;;; =======================================================================================================
;;;;; Chapter Two:
;;;;; ------------
;;;;;
;;;;; Computing of the limited argument positions.
;;;;; =======================================================================================================


(DEFUN REC=GAMMA.CRITERION (DEFINITION SYMBOL FORMAL.PARAMETERS MIN.PROJECTIONS)

  ;;; Edited:  21-Jan-87 by DH
  ;;; Input:   SYMBOL:            a function symbol
  ;;;          FORMAL.PARAMETERS: the formal parameters (variables) of SYMBOL
  ;;;          IF.THEN.CASES:     all if-then cases of the definition of SYMBOL
  ;;;          TREE:              a list of nodes as specified in the information-module.
  ;;; Effect:  It is tested for which argument-positions of SYMBOL the gamma-criterion is satisfied.
  ;;;          For each argument-position which satisfies the gamma-criterion an delta-difference-predicate
  ;;;          is created.
  ;;; Value:   a list of definitions of the generated difference predicates and a list of axioms.

  (LET (DELTA.PREDICATES AXIOMS ACTUAL.PARMS TAFS)
    (COND ((SETQ ACTUAL.PARMS (REMOVE-IF-NOT #'(LAMBDA (VAR) 
						 (DA-SORT.IS.SUBSORT (DA-VARIABLE.SORT VAR)
								     (DA-FUNCTION.SORT SYMBOL)))
					     FORMAL.PARAMETERS))  ;; only reflexive positions are of interest.
	   (DA-GTERM.DEF.MAP.WITH.CONDS 
	     DEFINITION
	     #'(LAMBDA (VALUE CONDITIONS)
		 (SETF (GETF (DA-TERM.ATTRIBUTES VALUE) 'LIMITED.POSITIONS) NIL)
		 (SETQ ACTUAL.PARMS 
		       (REMOVE-IF-NOT #'(LAMBDA (PAR)
					  (COND ((SETQ TAFS (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL VALUE))
						 (REC=GAMMA.CRITERION.RECURSIVE.CASE 
						   PAR (1+ (POSITION PAR FORMAL.PARAMETERS))
						   VALUE CONDITIONS TAFS))
						(T (REC=GAMMA.CRITERION.BASE.CASE
						     PAR (1+ (POSITION PAR FORMAL.PARAMETERS)) 
						     VALUE))))
				      ACTUAL.PARMS))))
	   ;; now actual.parms contains all p-bounded parameters.
	   (MAPC #'(LAMBDA (PAR)
		     (PUSH (REC=DELTA.PRED.COMPUTE.PRED 
			     DEFINITION SYMBOL FORMAL.PARAMETERS (1+ (POSITION PAR FORMAL.PARAMETERS))
			     MIN.PROJECTIONS) DELTA.PREDICATES)
		     (PUSH (REC=DELTA.PRED.COMPUTE.EQUIVALENCE 
			     (second (CAR DELTA.PREDICATES)) SYMBOL FORMAL.PARAMETERS (1+ (POSITION PAR FORMAL.PARAMETERS)))  ;;; <<-- SA: 18.11.94 SECOND anstatt THIRD, um das Pr"adikat zu erhalten
			   AXIOMS))
		 ACTUAL.PARMS)
	   (SETF (DA-FUNCTION.ARG.LIMITED SYMBOL)
		 (MAPCAR #'(LAMBDA (DELTA.PREDICATE PAR)
			     (LIST (1+ (POSITION PAR FORMAL.PARAMETERS)) (SECOND DELTA.PREDICATE)))
			 DELTA.PREDICATES (REVERSE ACTUAL.PARMS)))
	   (VALUES DELTA.PREDICATES AXIOMS)))))


(DEFUN REC=GAMMA.CRITERION.BASE.CASE (FORMAL.PARAMETER POSITION VALUE)

  ;;; Edited:  21-Jan-87 by DH
  ;;; Input:   FORMAL.PARAMETER:  a formal parameter of SYMBOL
  ;;;          IF.THEN.CASE:      a non-recursive if-then case of the definition of SYMBOL
  ;;; Effect:  It is tested whether the gamma-criterion for the argument position of FORMAL.PARAMETER
  ;;;          is satisfied.
  ;;; Value:   NIL / non-NIL depending on test.
  ;;; Note:    cf. Definition 6.1 (1) in [Wa 88a]
  
  (LET (DIFF.EQ)
    (COND ((SETQ DIFF.EQ (REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT VALUE (DA-TERM.CREATE FORMAL.PARAMETER)))
					; a. r =< x(p)
	   (PUSH (CONS POSITION DIFF.EQ)
		 (GETF (DA-TERM.ATTRIBUTES VALUE) 'LIMITED.POSITIONS))))))



(DEFUN REC=GAMMA.CRITERION.RECURSIVE.CASE (FORMAL.PARAMETER POSITION VALUE CONDITIONS TAFS)

  ;;; Edited:  21-Jan-87 by DH
  ;;; Input:   SYMBOL:            a function symbol
  ;;;          FORMAL.PARAMETER:  a formal parameter of SYMBOL
  ;;;          POSITION:          the position of FORMAL.PARAMETER in the formal parameters.
  ;;;          IF.THEN.CASE:      a recursive if-then case of the definition of SYMBOL
  ;;; Effect:  It is tested whether the gamma-criterion for the argument position of FORMAL.PARAMETER
  ;;;          is satisfied.

  (COND ((NULL (CDR TAFS))
	 (LET* ((RECURSIVE.CALL (DA-ACCESS (CAR TAFS) VALUE))
		(DIFF.EQ1 (REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT VALUE RECURSIVE.CALL))
		DIFF.EQ2 MATCH.LITERAL)
	   (COND ((AND DIFF.EQ1
					; Def 6.1 (2)      ; r =< delta(g(x*)) and delta(x(p)) =< x(p)
		       (SETQ DIFF.EQ2 (REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT
					(NTH (1- POSITION) (DA-TERM.TERMLIST RECURSIVE.CALL)) 
					(DA-TERM.CREATE FORMAL.PARAMETER))))
		  (PUSH (CONS POSITION (NCONC DIFF.EQ2 DIFF.EQ1))
			(GETF (DA-TERM.ATTRIBUTES VALUE) 'LIMITED.POSITIONS)))
					; Def. 6.1 (3)
		 ((AND (SETQ MATCH.LITERAL (REC=FIND.MATCH.LITERAL CONDITIONS FORMAL.PARAMETER))
		       (NEQ 'FAIL MATCH.LITERAL))
                  (some #'(lambda (subterm)
			    (cond ((and (eq (da-term.sort subterm)
					    (da-term.sort (second (da-literal.termlist match.literal))))
					(SETQ DIFF.EQ2 (REC=GAMMA.CRITERION.2.2.1 MATCH.LITERAL subterm value
										  POSITION recursive.call conditions)))
				   (PUSH (CONS POSITION DIFF.EQ2)
					 (GETF (DA-term.ATTRIBUTES value) 'LIMITED.POSITIONS)))))
			(da-term.termlist (second (da-literal.termlist match.literal))))))))))


(DEFUN REC=GAMMA.CRITERION.2.2.1 (MATCH.LITERAL subterm VALUE POSITION RECURSIVE.CALL CONDITIONS)
  
  ;;; Edited:  21-Jan-87
  ;;; Input:   MATCH.LITERAL:     a literal of the form: x(p) = c(u[1] ... u[n])
  ;;;          subterm:           a subterm u[i]
  ;;;          POSITION:          arg. position p to be considered.
  ;;;          value              a value c'(t[1]...f[delta(x)]...t[n]) of the considered if-then-case
  ;;;          recursive.call:    the recursice call of the if-then-case
  ;;;          conditions:        conditions of the if-then-case
  ;;; Effect:  Checks whether the position i of MATCH.LITERAL holds:
  ;;;          c'(t[1]...f[x]...t[n]) =< c(u[1]...f[delta(x)]...t[n])
  ;;;          delta(x(p)) =< b(i)(x(p))
  ;;; Value:   The conjunction of the difference equivalents of delta(x(P)) =< b(k) x(p) and
  ;;;          r =< gdx*, iff the check is successful, NIL else.
  
  (LET (DIFF.EQ1 DIFF.EQ2)
    (COND ((and (SETQ DIFF.EQ1 (REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT
				value (rec-term.subst RECURSIVE.CALL subterm
						  (second (da-literal.termlist match.literal)))))
		(SETQ DIFF.EQ2 (REC=GAMMA.DIFFERENCE.OR.EQUAL.EQUIVALENT
				(REC=TERM.INCORPORATE.MATCH.LITS (NTH (1- POSITION) (DA-TERM.TERMLIST RECURSIVE.CALL))
								 CONDITIONS)
				(REC=TERM.INCORPORATE.MATCH.LITS SUBTERM CONDITIONS))))
	   (NCONC DIFF.EQ1 DIFF.EQ2)))))


(DEFUN REC=TERM.INCORPORATE.MATCH.LITS (TERM LITERALS)
  (LET (TERMSUBST)
    (MAPC #'(LAMBDA (LIT)
	      (COND ((AND (DA-LITERAL.IS LIT) (DA-LITERAL.IS.MATCH LIT))
		     (SETQ TERMSUBST (UNI-TERMSUBST.CREATE TERMSUBST (CAR (DA-LITERAL.TERMLIST LIT))
							   (SECOND (DA-LITERAL.TERMLIST LIT)))))))
	  LITERALS)
    (EG-EVAL (UNI-TERMSUBST.APPLY TERMSUBST TERM))))


(defun rec-term.subst (new old term)

  ;;; Input: three terms
  ;;; Value: \verb$OLD$ is replaced by \verb$NEW$ in \verb$TERM$

  (cond ((da-term.termlist term)
	 (da-term.create (da-term.symbol term)
			 (mapcan #'(lambda (subterm)
				     (cond ((equal old subterm) (list new))
					   ((not (da-term.termlist subterm)) (list subterm))
					   (t (list (rec-term.subst new old subterm)))))
				 (da-term.termlist term))))))

;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 2.1
;;;;; -----------
;;;;;
;;;;; Search for a new match literal for the sake of proving the argument limitation
;;;;;--------------------------------------------------------------------------------------------------------


(DEFUN REC=FIND.MATCH.LITERAL (LITERALS FORMAL.PARAMETER)
  
  ;;; Edited:  26-Jan-87 by DH
  ;;; Input:   LITERALS:          the literals of the condition of if-then-case
  ;;;          FORMAL.PARAMETER:  a formal parameters of the definition
  ;;; Effect:  see value.
  ;;; Value:   a match literal of the conditions of IF-THEN-CASE if its left side is equal to 
  ;;;          FORMAL.PARAMETER and the top-level-symbol of the right side is a reflexive constructor. 
  ;;;          If there is another match-literal of FORMAL.PARAMETER then 'FAIL , nil else.
  
  (SOME #'(LAMBDA (LIT)
	    (COND ((AND (DA-LITERAL.IS LIT)
			(DA-LITERAL.IS.MATCH LIT)
			(EQ (DA-TERM.SYMBOL (CAR (DA-LITERAL.TERMLIST LIT))) FORMAL.PARAMETER))
		   (COND ((and (da-symbol.is.structure
				(DA-TERM.SYMBOL (SECOND (DA-LITERAL.TERMLIST LIT))))
			       (da-function.is.reflexive
				(DA-TERM.SYMBOL (SECOND (DA-LITERAL.TERMLIST LIT)))))
			  LIT)
			 (T 'FAIL)))))
	LITERALS))


(DEFUN REC=SORT.HAS.ONLY.ONE.MINIMAL.ELEMENT (SORT)
  
  ;;; Edited:   26-Jan-93 by DH
  ;;; Input:    a sort
  ;;; Effect:   see value.
  ;;; Value:    T iff SORT has only one minimal element, e.g. only one base constants and no non-reflexive
  ;;;           constructor functions and no subsorts.

  (LET (SINGLE.MINIMAL.ELEM)
       (AND (NULL (DA-SORT.BASE.SORTS SORT))
	    (EVERY #'(LAMBDA (FUNC)
			     (OR (DA-FUNCTION.IS.REFLEXIVE FUNC)
				 (COND ((AND (NULL (DA-FUNCTION.DOMAIN.SORTS FUNC))
					     (NULL SINGLE.MINIMAL.ELEM))
					(SETQ SINGLE.MINIMAL.ELEM FUNC)))))
		   (DA-SORT.CONSTRUCTOR.FCTS SORT)))))

  
;;;;;========================================================================================================
;;;;; Chapter 3.
;;;;; ----------
;;;;; 
;;;;; Computing the difference-predicate for the n-th position of a function.
;;;;;========================================================================================================


(DEFUN REC=DELTA.CREATE.SELECTOR.DIFFERENCE.PREDICATE (CONSTRUCTOR SELECTOR POSITION)

  ;;; Input:   a constructor-function, one of its reflexive constructors and its argumentposition
  ;;; Effect:  creates a defintion for the delta-difference predicate
  ;;; Value:   the created definition

  (LET ((VAR (DA-VARIABLE.CREATE (DA-FUNCTION.SORT CONSTRUCTOR))) 
	(DELTA.SYMBOL (REC=DELTA.PRED.SYMBOL SELECTOR POSITION)))
    (SETF (DA-FUNCTION.ARG.LIMITED SELECTOR)
	  (LIST (LIST 1 DELTA.SYMBOL)))
    (LIST (DA-GTERM.DEF.VALUE.CREATE 
	    (DA-LITERAL.CREATE (DA-SIGN.PLUS) (DA-PREDICATE.EQUALITY)
			       (LIST (DA-TERM.CREATE VAR)
			       (DA-SORT.CONSTRUCTOR.TERM (DA-TERM.CREATE VAR) CONSTRUCTOR))))
	  DELTA.SYMBOL (LIST VAR))))


(DEFUN REC=DELTA.CREATE.INDEX.DIFFERENCE.PREDICATE (INDEX.FCT)

  ;;; Input:   a constructor-function, one of its reflexive constructors and its argumentposition
  ;;; Effect:  creates a defintion for the delta-difference predicate
  ;;; Value:   the created definition

  (LET ((VAR (DA-VARIABLE.CREATE (CAR (DA-FUNCTION.DOMAIN.SORTS INDEX.FCT))))
	(DELTA.SYMBOL (REC=DELTA.PRED.SYMBOL INDEX.FCT 1)))
    (SETF (DA-FUNCTION.ARG.LIMITED INDEX.FCT)
	  (LIST (LIST 1 DELTA.SYMBOL)))
    (LIST (DA-GTERM.DEF.VALUE.CREATE (DA-LITERAL.FALSE))
	  DELTA.SYMBOL (LIST VAR))))
  

(DEFUN REC=DELTA.PRED.COMPUTE.PRED (DEFINITION SYMBOL FORMAL.PARAMETERS POSITION MIN.PROJECTIONS)
  (MULTIPLE-VALUE-BIND (DELTA.DEFINITION DELTA.SYMBOL)
      (REC=DELTA.PRED.GENERATE.PRED DEFINITION SYMBOL POSITION)
    (SETQ DELTA.DEFINITION (REC=RED.ELIMINATE.RECS DELTA.DEFINITION DELTA.SYMBOL FORMAL.PARAMETERS))
    (SETQ DELTA.DEFINITION (REC=RED.CASE.MERGE DELTA.DEFINITION DELTA.SYMBOL FORMAL.PARAMETERS))
    (COND ((DA-SYMBOL.OCCURS.IN.GTERM DELTA.SYMBOL DELTA.DEFINITION)
	   (REC=WFO.CREATE DELTA.DEFINITION DELTA.SYMBOL FORMAL.PARAMETERS MIN.PROJECTIONS)))
    (win-io.FORMAT (win-window 'proof)
		   "~%~A is bounded on the ~D. argument, the difference-predicate ~A is generated~%~%"
		   SYMBOL POSITION  DELTA.SYMBOL)
    (LIST DELTA.DEFINITION DELTA.SYMBOL FORMAL.PARAMETERS)))


(DEFUN REC=DELTA.PRED.COMPUTE.EQUIVALENCE (PRED SYMBOL FORMAL.PARAMETERS POSITION)
  (DA-FORMULA.QUANTIFICATION.CLOSURE
   'ALL FORMAL.PARAMETERS
   (DA-FORMULA.CREATE 'EQV 
		      (LIST (DA-LITERAL.CREATE '+ PRED (MAPCAR #'(LAMBDA (X) (DA-TERM.CREATE X)) FORMAL.PARAMETERS))   ;;; <--- SA: 18.11.94 LIST eingefuegt
			    (DA-LITERAL.CREATE '- (DA-PREDICATE.EQUALITY)
					       (LIST (DA-TERM.CREATE SYMBOL (MAPCAR #'(LAMBDA (X) (DA-TERM.CREATE X)) FORMAL.PARAMETERS))
						     (DA-TERM.CREATE (NTH (1- POSITION) FORMAL.PARAMETERS))))))))


(DEFUN REC=DELTA.PRED.GENERATE.PRED (DEFINITION SYMBOL POSITION)
  
  ;;; Edited:  22-Jan-87 by DH
  ;;; Input:   A tree and its leaves, a function and an argument position
  ;;; Effect:  for each if-then-case of SYMBOL corresponding if-then-cases of DELTA-SYMBOL are computed which
  ;;;          define a predicate DELTA-SYMBOL which is true, iff the value of the definition of symbol
  ;;;          is less than the POSITION-th argument.
  ;;; Value:   Undefined.
  
  (LET ((DELTA.SYMBOL (REC=DELTA.PRED.SYMBOL SYMBOL POSITION)) DELTA.DEFINITION)
    (SETQ DELTA.DEFINITION 
	  (DA-GTERM.DEF.REPLACE.WITH.CONDS (DA-GTERM.COPY DEFINITION)
					    #'(LAMBDA (VALUE CONDITIONS)
						(REC=DELTA.PRED.GENERATE.LEAFS DELTA.SYMBOL SYMBOL VALUE CONDITIONS POSITION))))
    (VALUES DELTA.DEFINITION DELTA.SYMBOL)))


(DEFUN REC=DELTA.PRED.SYMBOL (SYMBOL POSITION)

  ;;; Input  :  a function symbol and a argument position
  ;;; Effect :  creates a predicate symbol and inherits the attributes of SYMBOL to it.
  ;;; Value  :  the created predicate symbol

  (LET ((PREDICATE (DA-PREDICATE.CREATE (COND ((> (DA-FUNCTION.ARITY SYMBOL) 1)
			      (FORMAT NIL "Delta-~A-~D" (DA-PNAME SYMBOL) POSITION))
			     (T (FORMAT NIL "Delta-~A" (DA-PNAME SYMBOL))))
		       (DA-FUNCTION.DOMAIN.SORTS SYMBOL))))
    (SETF (GETF (DA-PREDICATE.ATTRIBUTES PREDICATE) 'DEFINED) T)
    (DA-PREDICATE.DECLARE.AS.DELTA.PREDICATE PREDICATE SYMBOL POSITION)
    PREDICATE))


(DEFUN REC=DELTA.PRED.GENERATE.LEAFS (DELTA.SYMBOL SYMBOL VALUE CONDITIONS POSITION)
    
  ;;; edited:  22-jan-87 by dh
  ;;; input:   a tree and some of its leaves, a symbol (all for delta.symbol), a leaf of another tree 
  ;;;          and a list of literals.
  ;;; effect:  for IF.THEN.CASE corresponding if-then-cases for SYMBOL are computed which
  ;;;          define a case of the predicate symbol. Condition subsumption is directly applied.
  ;;; value:   a multiple value: tree and leaves of SYMBOL.
  
  (LET ((DIFF.EQ (CASSOC POSITION (GETF (DA-TERM.ATTRIBUTES VALUE) 'LIMITED.POSITIONS))) DELTA.VALUE TAFS)
    (SETQ DELTA.VALUE (COND ((SETQ TAFS (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL VALUE))
			     (DA-LITERAL.CREATE
				 '+ DELTA.SYMBOL (MAPCAR #'DA-TERM.COPY (DA-TERM.TERMLIST (DA-ACCESS (CAR TAFS) VALUE)))))
			    (T (DA-LITERAL.FALSE))))
    (COND ((REC=PROVE.DISJUNCTION (APPEND CONDITIONS DIFF.EQ) NIL)	        ;; phi -> delta
	   (DA-GTERM.DEF.VALUE.CREATE (DA-GTERM.COPY (DA-LITERAL.TRUE))))
	  ((REC=PROVE.DISJUNCTION (APPEND CONDITIONS                            ;; phi -> (not delta)
					  (LIST (DA-FORMULA.JUNCTION.CLOSURE 'AND (MAPCAR #'DA-FORMULA.NEGATE DIFF.EQ)))))
	   (DA-GTERM.DEF.VALUE.CREATE (DA-GTERM.COPY DELTA.VALUE)))
	  (T (REC=DELTA.PRED.SPLIT.CASE DIFF.EQ (DA-LITERAL.TRUE) DELTA.VALUE)))))



(DEFUN REC=DELTA.PRED.SPLIT.CASE (DIFF.EQ VALUE1 VALUE2)

  (MULTIPLE-VALUE-BIND (POS.CASES NEG.CASES) (REC=DELTA.SPLITTED.CASES DIFF.EQ)
    (DA-GTERM.CREATE
      'AND
      (NCONC (MAPCAR #'(LAMBDA (LITS)
			 (DA-GTERM.DEF.CREATE (DA-GTERM.DEF.VALUE.CREATE (DA-GTERM.COPY VALUE1))
					       (MAPCAR #'DA-GTERM.COPY LITS)))
		     POS.CASES)
	     (MAPCAR #'(LAMBDA (LITS)
			 (DA-GTERM.DEF.CREATE (DA-GTERM.DEF.VALUE.CREATE (DA-GTERM.COPY VALUE2))
					       (MAPCAR #'DA-GTERM.COPY LITS)))
		     NEG.CASES)))))


(DEFUN REC=DELTA.SPLITTED.CASES (LITERALS)
  (LET (POS.CASES NEG.CASES NEW.LIT)
    (SETQ LITERALS (MAPCAN #'(LAMBDA (LIT)
			       (SETQ NEW.LIT (eg-eval LIT))
			       (COND ((not (da-literal.is.FALSE new.lit)) (LIST NEW.LIT))))
			   LITERALS))
    (SETQ POS.CASES (MAPCAR #'(LAMBDA (LIT) (LIST (DA-FORMULA.NEGATE (DA-GTERM.COPY LIT)))) LITERALS))
    (SETQ NEG.CASES (LIST LITERALS))
    (VALUES POS.CASES NEG.CASES)))


;;;;;========================================================================================================
;;;;; Chapter 4.
;;;;; ----------
;;;;; 
;;;;; Simplification-algorithms for if.then.cases, like merging of cases or elimination of recursive calls.
;;;;;========================================================================================================

;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 4.1
;;;;; -----------
;;;;;
;;;;; Case Merging and Condition Reductions
;;;;;--------------------------------------------------------------------------------------------------------

(DEFUN REC=RED.CASE.MERGE (DEFINITION SYMBOL FORMAL.PARAMETERS )

  ;;; Edited: 07-feb-87 by PB
  ;;; Input:  TREE: a tree generated out of IF.THEN.CASES
  ;;; Effect: deletes all leaves of the tree, that have the same value (in recursive manner)
  ;;;         and removes all redundant literals, that belong to the leaves
  ;;; Value:  the modified tree and the modified list of IF.THEN.CASES

  (LET (VALUE)
    (COND ((NOT (DA-GTERM.DEF.IS.VALUE DEFINITION))
	   (MAPC #'(LAMBDA (DEF.TERM)
		     (SETF (DA-GTERM.DEF.VALUE DEF.TERM) 
			   (REC=RED.CASE.MERGE (DA-GTERM.DEF.VALUE DEF.TERM) SYMBOL FORMAL.PARAMETERS)))
		 (DA-GTERM.TERMLIST DEFINITION))
	   (COND ((AND (NULL (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'UNSPEC.CASES))
		       (EVERY #'(LAMBDA (TERM) (DA-GTERM.DEF.IS.VALUE (DA-GTERM.DEF.VALUE TERM)))
			      (DA-GTERM.TERMLIST DEFINITION)))
		  (SETQ VALUE (DA-GTERM.DEF.VALUE (CAR (DA-GTERM.TERMLIST DEFINITION))))
		  (COND ((EVERY #'(LAMBDA (SUB.DEF)
				    (UNI-GTERM.ARE.EQUAL VALUE (DA-GTERM.DEF.VALUE SUB.DEF)))
				(DA-GTERM.TERMLIST DEFINITION))
			 (SETQ DEFINITION VALUE))
			((DA-PREDICATE.IS SYMBOL)
			 (SETQ DEFINITION (REC=RED.CASE.INTO.CONDITION DEFINITION SYMBOL))))))))
    DEFINITION))


(DEFUN REC=RED.CASE.INTO.CONDITION (DEFINITION SYMBOL)
  (LET (VALUE CONSIDERED.CASE TRUE.VALUES FALSE.VALUES BOOL.VALUE)
    (COND ((EVERY #'(LAMBDA (DEF.TERM)
		      (SETQ VALUE (DA-GTERM.DEF.VALUE DEF.TERM))
		      (COND ((DA-GTERM.DEF.IS.VALUE VALUE)
			     (COND ((DA-LITERAL.IS.FALSE VALUE)
				    (PUSH DEF.TERM FALSE.VALUES))
				   ((DA-LITERAL.IS.TRUE VALUE)
				    (PUSH DEF.TERM TRUE.VALUES))
				   ((AND (NULL CONSIDERED.CASE)
					 (NULL (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL VALUE)))
				    (SETQ CONSIDERED.CASE DEF.TERM))))))
		  (DA-GTERM.TERMLIST DEFINITION))
	   (COND ((AND TRUE.VALUES FALSE.VALUES (NULL CONSIDERED.CASE) (NULL (CDR TRUE.VALUES)))
		  (SETQ CONSIDERED.CASE (CAR TRUE.VALUES))
		  (SETQ BOOL.VALUE (DA-LITERAL.FALSE)))
		 ((AND TRUE.VALUES FALSE.VALUES (NULL CONSIDERED.CASE) (NULL (CDR FALSE.VALUES)))
		  (SETQ CONSIDERED.CASE (CAR FALSE.VALUES))
		  (SETQ BOOL.VALUE (DA-LITERAL.TRUE)))
		 ((AND FALSE.VALUES (NULL TRUE.VALUES) CONSIDERED.CASE)
		  (SETQ BOOL.VALUE (DA-LITERAL.FALSE)))
		 ((AND TRUE.VALUES (NULL FALSE.VALUES) CONSIDERED.CASE)
		  (SETQ BOOL.VALUE (DA-LITERAL.TRUE))))
	   (COND (BOOL.VALUE
		  (SETQ DEFINITION
			(DA-GTERM.DEF.VALUE.CREATE
			  (EG-EVAL
			    (COND ((DA-LITERAL.IS.FALSE BOOL.VALUE)
				   (DA-FORMULA.JUNCTION.CLOSURE 
				     'AND (LIST (DA-GTERM.DEF.VALUE CONSIDERED.CASE)
						(DA-FORMULA.NEGATE (DA-FORMULA.JUNCTION.CLOSURE 
								     'AND (DA-GTERM.DEF.CONDITION CONSIDERED.CASE))))))
				  (T (DA-FORMULA.JUNCTION.CLOSURE 'OR (CONS (DA-GTERM.DEF.VALUE CONSIDERED.CASE) 
									    (DA-GTERM.DEF.CONDITION CONSIDERED.CASE))))))))))))
    DEFINITION))


;;;;;--------------------------------------------------------------------------------------------------------
;;;;; Chapter 4.2
;;;;; -----------
;;;;;
;;;;; Recursion Elimination
;;;;;--------------------------------------------------------------------------------------------------------


(DEFUN REC=RED.ELIMINATE.RECS (DEFINITION SYMBOL FORMAL.PARAMETERS)
  
  ;;; Edited:  8-April-1987 by Peter Borst
  ;;; Input:   a definition as described in the DA-module, the predicate to simplify,
  ;;;          and the formal parameters of the predicate
  ;;; Effect:  Eliminates the recursive call of the predicate if possible.
  ;;; Value:   undefined
  
  (LET (REC.CASES TRUE.CASES FALSE.CASES (OTHER.CASES (REC=RED.UNSPEC.CASES DEFINITION)))
    (DA-GTERM.DEF.MAP.WITH.CONDS 
      DEFINITION
      #'(LAMBDA (VALUE CONDITION)
	  (SETQ VALUE (REC=RED.SIMPLIFY.TERM CONDITION VALUE))
	  (COND ((DA-LITERAL.IS.TRUE VALUE) (PUSH CONDITION TRUE.CASES))
		((DA-LITERAL.IS.FALSE VALUE) (PUSH CONDITION FALSE.CASES))
		((AND (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL VALUE)
		      (DA-LITERAL.IS VALUE) 
		      (EQ SYMBOL (DA-LITERAL.SYMBOL VALUE)))
		 (PUSH (CONS CONDITION VALUE) REC.CASES))
		(T (PUSH CONDITION OTHER.CASES)))))
    (MAPC #'(LAMBDA (LITS.VALUE)
	      (REC=RED.ELIMINATE.SINGLE.CASE
		FORMAL.PARAMETERS LITS.VALUE TRUE.CASES FALSE.CASES OTHER.CASES REC.CASES))
	  REC.CASES)
    DEFINITION))


(DEFUN REC=RED.UNSPEC.CASES (DEFINITION &OPTIONAL CONDITIONS)

  ;;; Input:   a definition as described in the DA-module
  ;;; Effect:  see value
  ;;; Value:   a list of all conditions for which the function/predicate definition is unspecified.

  (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION) NIL)
	(T (APPEND (MAPCAR #'(LAMBDA (LITS)
			       (APPEND CONDITIONS LITS))
			   (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'UNSPEC.CASES))
		   (MAPCAN #'(LAMBDA (DEF.TERM)
			       (REC=RED.UNSPEC.CASES (DA-GTERM.DEF.VALUE DEF.TERM)
						     (APPEND CONDITIONS (DA-GTERM.DEF.CONDITION DEF.TERM))))
			   (DA-GTERM.TERMLIST DEFINITION))))))


(DEFUN REC=RED.SIMPLIFY.TERM (CONDITION VALUE)

  ;;; Edited: 17.05.89 by GR
  ;;; Input:  IF.THEN.CASE:   a if.then.case of the definition
  ;;;         CONDITION:      a list of literals (conditions of if.then.case)
  ;;; Effect: Simplifies Value and Recursive.calls of if.then.case, if possible (TERM-SIMPLIFICATION)
  ;;; Value:  Simplified IF.THEN.CASE.VALUE

  ;;; does this work correctly ????

  (LET  (SUBST  TERM TERMLIST FUNC POS PARAMETER)
    (MAPC #'(LAMBDA (LIT)
	      (COND ((AND (DA-LITERAL.IS LIT)
			  (DA-SIGN.IS.POSITIVE (DA-LITERAL.SIGN LIT)))
		     (SETQ TERMLIST (DA-LITERAL.TERMLIST LIT))
		     (COND ((MULTIPLE-VALUE-SETQ (FUNC POS)
			      (DA-PREDICATE.IS.DELTA.PREDICATE (DA-LITERAL.SYMBOL LIT)))
			    (PUSH (NTH (1- POS) TERMLIST) SUBST)
			    (PUSH (DA-TERM.CREATE FUNC TERMLIST) SUBST))
			   ((DA-LITERAL.IS.MATCH LIT)
			    ;; reflexive selectors return their argument if applied to a
			    ;; constructor, they don't belong to.
			    (SETQ TERM (SECOND TERMLIST) PARAMETER (CAR TERMLIST))
			    (MAPC #'(LAMBDA (SUBTERM)
				      (COND ((EQ (DA-TERM.SORT PARAMETER) (DA-TERM.SORT SUBTERM))
					     (PUSH PARAMETER SUBST)
					     (PUSH SUBTERM SUBST))))
				  (DA-TERM.TERMLIST TERM)))))))
	  CONDITION)
    (UNI-TERMSUBST.APPLY SUBST (eg-eval VALUE))))


(DEFUN REC=RED.ELIMINATE.SINGLE.CASE (FORMAL.PARAMETERS LITS.VALUE TRUE.CASES FALSE.CASES
							OTHER.CASES REC.CASES)
  
  ;;; Edited:  8-April-1987 by Peter Borst
  ;;; Input:   a symbol P and its formal parameter, a if.then.case and its condition, lists of conditions, 
  ;;;          specifying cases with result TRUE, with result FALSE, with result P(...), and all others.
  ;;; Effect:  tries to replace recursion from LITS.IF.THEN.CASE
  ;;; Value:   a for-literal denoting a boolean value, which replaces the value of LITS.IF.THEN.CASE
  
  (LET* ((CONDITION (CAR LITS.VALUE)) REC.CALL.SUBST)
    (MAPC #'(LAMBDA (OLD NEW) 
	      (SETQ REC.CALL.SUBST (UNI-TERMSUBST.CREATE REC.CALL.SUBST 
							 (DA-TERM.CREATE OLD) NEW)))
	  FORMAL.PARAMETERS (DA-LITERAL.TERMLIST (CDR LITS.VALUE)))
    (COND ((AND (EVERY #'(LAMBDA (REC.CASE)
			   (OR (EQ (CAR REC.CASE) CONDITION)
			       (REC=RED.ELIMINATE.CASE.IS.IMPOSSIBLE
				(CAR REC.CASE) CONDITION REC.CALL.SUBST)))
		       REC.CASES)
		(EVERY #'(LAMBDA (OTHER.CASE)
			   (REC=RED.ELIMINATE.CASE.IS.IMPOSSIBLE
			    OTHER.CASE CONDITION REC.CALL.SUBST))
		       OTHER.CASES))
	   (COND ((AND FALSE.CASES
		       (EVERY #'(LAMBDA (TRUE.CASE)
				  (REC=RED.ELIMINATE.CASE.IS.IMPOSSIBLE
				   TRUE.CASE CONDITION REC.CALL.SUBST))
			      TRUE.CASES))
		  (DA-LITERAL.FALSE))
		 ((AND TRUE.CASES
		       (EVERY #'(LAMBDA (FALSE.CASE)
				  (REC=RED.ELIMINATE.CASE.IS.IMPOSSIBLE
				   FALSE.CASE CONDITION REC.CALL.SUBST))
			      FALSE.CASES))
		  (DA-LITERAL.TRUE)))))))


(DEFUN REC=RED.ELIMINATE.CASE.IS.IMPOSSIBLE (THEOREMS ASSUMPTIONS REC.CALL.SUBST) ;;; ->change 	

  ;;; Input  :  a list of literals L1...Lk, denoting the theorem and a list of literals K1...Km,
  ;;;             denoting the negated assumptions.
  ;;;           a list of formal parameters and list of arguments of a recursive call.
  ;;; Effect :  computes, whether the assumptions exclude the instantiated theorem:
  ;;;           e.g.  (K1 and ... and Km) impl not (sigma(L1) and ...and sigma(Lk))
  ;;;           or:   (not sigma(L1) or ...or not sigma(Lk)) or (not K1 or ... or not Km)
  ;;; Value  :  T, if the property above holds true.

  (SETQ THEOREMS (mapcar #'(lambda (lit) (UNI-TERMSUBST.APPLY REC.CALL.SUBST lit)) THEOREMS))
  (MAPC #'(LAMBDA (LIT) (SETF (DA-LITERAL.ATTRIBUTES LIT) NIL)) THEOREMS)
  (REC=PROVE.DISJUNCTION (APPEND (mapcar #'(lambda (literal) (da-GTERM.copy literal)) ASSUMPTIONS)
				 THEOREMS)))



;;;;;========================================================================================================
;;;;; Chapter 5.
;;;;; ----------
;;;;;
;;;;; Functions for generating well-founded orderings.
;;;;;========================================================================================================
  

(DEFUN REC=WFO.IND.CREATE (DEFINITION SYMBOL FORMAL.PARAMETERS)
  
  ;;; Input:    a function/predicate definition, a symbol and its formal parameters
  ;;; Effect:   computes a well-founded ordering
  ;;; Value :   the well-founded ordering
  
  (LET (WFO.TREE CHANGEABLES (COUNTER 0))
    (SETQ WFO.TREE (REC=WFO.CREATE.TREE DEFINITION SYMBOL))
    (SETQ FORMAL.PARAMETERS (MAPCAR #'(LAMBDA (VAR) (DA-TERM.CREATE VAR)) FORMAL.PARAMETERS))
    (MULTIPLE-VALUE-SETQ (WFO.TREE CHANGEABLES)
		  (REC=WFO.ADJUST.SUBST.TO.PARAMS WFO.TREE FORMAL.PARAMETERS
						  (MAPCAR #'(LAMBDA (PAR) (DECLARE (IGNORE PAR))
							      (INCF COUNTER))
							  FORMAL.PARAMETERS)))
    (DA-WFO.CREATE FORMAL.PARAMETERS WFO.TREE NIL CHANGEABLES)))


(DEFUN REC=WFO.CREATE (DEFINITION SYMBOL FORMAL.PARAMETERS MIN.PROJECTIONS)
  
  ;;; Input:    a function/predicate definition, a symbol and its formal parameters and a list of minimal projections.
  ;;; Effect:   computes the well-founded orderings for each minimal projection and inserts them in the database
  ;;;           also a reference to this WFO is stored in the corresponding WFO.SUGGESTED slot of SYMBOL`s definition.
  ;;; Value :   undefined.
  
  (LET (FORM.REC.PARS FORM.CASE.PARS WFO.TREE CHANGEABLES ARGUMENTS CASE.ARGS DESCRIPTION)
    (REC=DEFINITION.COMPUTE.TERMINATION.ATTRIBUTES DEFINITION)
    (COND ((REC=WFO.DEFINITION.IS.CENTRAL.REC DEFINITION SYMBOL)
	   (SETF (GETF (DA-PREFUN.ATTRIBUTES SYMBOL) 'CENTRAL.REC) T)))
    (SETF (DA-PREFUN.WFO.SUGGESTED SYMBOL)
	  (MAPCAR #'(LAMBDA (PROJECTION)
		      (SETQ WFO.TREE (REC=WFO.CREATE.MINIMIZED.TREE DEFINITION SYMBOL PROJECTION))
		      (MULTIPLE-VALUE-SETQ (FORM.REC.PARS ARGUMENTS FORM.CASE.PARS CASE.ARGS)
					   (REC=WFO.TREE.REC.PARAMETERS WFO.TREE FORMAL.PARAMETERS PROJECTION))
		      (MULTIPLE-VALUE-SETQ (WFO.TREE CHANGEABLES)
					   (REC=WFO.ADJUST.SUBST.TO.PARAMS WFO.TREE FORM.REC.PARS ARGUMENTS))
		      (COND (projection (SETQ DESCRIPTION (REC=WFO.DESCRIBE SYMBOL FORMAL.PARAMETERS PROJECTION))))
		      (DA-WFO.SUGGESTED.CREATE
		       ARGUMENTS CASE.ARGS
		       (DA-WFO.CREATE FORM.REC.PARS WFO.TREE 
				      (LIST 'DESCRIPTION DESCRIPTION)
				      CHANGEABLES FORM.CASE.PARS)))
		  (COND (MIN.PROJECTIONS) ((NOT (DA-GTERM.DEF.IS.VALUE DEFINITION)) (LIST NIL)))))))


(DEFUN REC=WFO.DEFINITION.IS.CENTRAL.REC (DEFINITION SYMBOL)

  ;;; Input:   a definition as defined in DA and a symbol
  ;;; Value:   T, if \verb$DEFINITION$ is central recursive.

  (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION)
	 (LET ((TAFS (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL DEFINITION)))
	   (OR (NULL TAFS) (EQUAL TAFS (LIST NIL)))))
	(T (EVERY #'(LAMBDA (DEF.GTERM)
		      (REC=WFO.DEFINITION.IS.CENTRAL.REC (DA-GTERM.DEF.VALUE DEF.GTERM) SYMBOL))
		  (DA-GTERM.TERMLIST DEFINITION)))))


(DEFUN REC=WFO.DEFINITION.CASES (DEFINITION)
  
  ;;; Input :   a definition as defined in DA
  ;;; Value:    a list of all conditions of the \verb$DEFINITION$
  
  (LET (ALT.CASES)
    (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION) NIL)
	  (T (SETQ ALT.CASES (MAPCAN #'(LAMBDA (DEF.GTERM)
					 (APPEND (DA-GTERM.DEF.CONDITION DEF.GTERM)
						 (REC=WFO.DEFINITION.CASES (DA-GTERM.DEF.VALUE DEF.GTERM))))
				     (DA-GTERM.TERMLIST DEFINITION)))
	     (MAPC #'(LAMBDA (CONDITION)
		       (PUSH CONDITION ALT.CASES))
		   (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'UNSPEC.CASES))
	     ALT.CASES))))


(DEFUN REC=WFO.WFO.CASES (WFO.TREE)
  
  ;;; Input :   a definition as defined in DA
  ;;; Value:    a list of all conditions of the \verb$DEFINITION$
  
  (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE) NIL)
	(T (MAPCAN #'(LAMBDA (SUBNODE)
		       (APPEND (CDR SUBNODE)
			       (REC=WFO.WFO.CASES (CAR SUBNODE))))
		   (DA-WFO.TREE.SUBNODES WFO.TREE)))))


(DEFUN REC=WFO.DESCRIBE (SYMBOL FORMAL.PARAMETERS PROJECTION)

  ;;; Input:  a list of partial orders and a list of argument-positions
  ;;; Value:  a list of strings, describing the given ordering

  (COND ((DA-PREFUN.IS SYMBOL)
	 (LET (ORDER.TERM (HEADER (CAR (PR-PRINT.TERM (DA-TERM.CREATE SYMBOL (MAPCAR #'(LAMBDA (X) (DA-TERM.CREATE X))
										     FORMAL.PARAMETERS))))))		  
	   (COND ((NULL (CDR PROJECTION))
		  (SETQ ORDER.TERM (CDR (CAR PROJECTION)))
		  (LIST (FORMAT NIL "~A terminates since ~A  decreases wrt. the count ordering"
				HEADER (car (pr-print.term ORDER.TERM)))))
		 (T (CONS (FORMAT NIL "~A terminates according to a lexicographical ordering:" HEADER)
			  (MAPCAR #'(LAMBDA (ORDER)
				      (SETQ ORDER.TERM (CDR ORDER))
				      (FORMAT NIL "~A  decreases wrt. the count ordering" (car (pr-print.term ORDER.TERM))))
				  PROJECTION))))))
	(T (LIST ""))))


(DEFUN REC=DEFINITION.COMPUTE.TERMINATION.ATTRIBUTES (DEFINITION)

  ;;; Input:  a function/predicate definition as defined in DA
  ;;; Effect: walks throu the definition tree and marks each single case-analysis (node) by
  ;;;         the list of such argument-positions which termination proof has used that case-analysis.
  ;;; Value:  undefined

  (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION))
	(T (LET (PROJECTIONS)
	     (MAPC #'(LAMBDA (DEF.TERM)
		       (REC=DEFINITION.COMPUTE.TERMINATION.ATTRIBUTES (DA-GTERM.DEF.VALUE DEF.TERM))
		       (MAPC #'(LAMBDA (LITERAL)
				 (SETQ PROJECTIONS (UNION (GETF (DA-GTERM.ATTRIBUTES LITERAL) 'RECURSION) PROJECTIONS)))
			     (DA-GTERM.DEF.CONDITION DEF.TERM)))
		   (DA-GTERM.TERMLIST DEFINITION))
	     (DA-GTERM.DEF.MARK.TERMINATION DEFINITION PROJECTIONS)))))


(DEFUN REC=WFO.CREATE.TREE (DEFINITION SYMBOL &OPTIONAL CALL.IN.CONDS)
  
  ;;; Input :   a definition as defined in DA, a function/predicate symbol
  ;;; Effect:   creates a WFO-tree out of the definition tree
  ;;; Value:    the generated WFO-tree.
    
  (LET (SCHEMES)
    (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION)
	   (DA-WFO.TREE.PRED.SET.CREATE
	    (NCONC (MAPCAR #'(LAMBDA (TAF) 
			       (MAPCAR #'DA-TERM.COPY (DA-GTERM.TERMLIST (DA-ACCESS TAF DEFINITION))))
			   (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL DEFINITION))
		   (MAPCAR #'(LAMBDA (GTERM)
			       (MAPCAR #'(LAMBDA (X) 
					   (SETQ X (DA-TERM.COPY X))
					   (SETF (GETF (DA-TERM.ATTRIBUTES X) 'REC) 'COND)
					   X)
				       (DA-GTERM.TERMLIST GTERM)))
			   CALL.IN.CONDS))))			   
	  (T (SETQ SCHEMES (MAPCAR #'(LAMBDA (DEF.GTERM)
				       (REC=WFO.CREATE.TREE 
					(DA-GTERM.DEF.VALUE DEF.GTERM) SYMBOL
					(APPEND CALL.IN.CONDS
						(MAPCAN #'(lambda (FOR)
							    (MAPCAR #'(LAMBDA (TAF) (DA-ACCESS TAF for))
								    (DA-SYMBOL.OCCURS.IN.GTERM symbol for)))
							(DA-GTERM.DEF.CONDITION DEF.GTERM)))))
				   (DA-GTERM.TERMLIST DEFINITION)))
	     (DA-WFO.TREE.CREATE
	      (NCONC (MAPCAR #'(LAMBDA (SCHEME DEF.GTERM)
				 (CONS SCHEME (DA-GTERM.DEF.CONDITION DEF.GTERM)))
			     SCHEMES (DA-GTERM.TERMLIST DEFINITION))
		     (MAPCAR #'(LAMBDA (CONDITION)
				 (CONS (DA-WFO.TREE.PRED.SET.CREATE NIL) CONDITION))
			     (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'UNSPEC.CASES))))))))


(DEFUN REC=WFO.CREATE.MINIMIZED.TREE (DEFINITION SYMBOL PROJECTION &OPTIONAL CALL.IN.CONDS)
  
  ;;; Input :   a definition as defined in DA, a function/predicate symbol and a list of argument-positions
  ;;; Effect:   creates a WFO-tree out of the definition tree by reducing the given tree by removing all nodes,
  ;;;           that are not marked with argument positions occurring in PROJECTION.
  ;;; Value:    the generated WFO-tree.
  ;;; Notice:   this function is still incomplete in case there is a non-recursive case analysis and more than one
  ;;;           case is recursive !
  
  (LET (SCHEMES OK COMMON.PRED.SET)
    (COND ((DA-GTERM.DEF.IS.VALUE DEFINITION)
	   (DA-WFO.TREE.PRED.SET.CREATE
	    (nconc (MAPCAR #'(LAMBDA (TAF) 
			       (MAPCAR #'DA-TERM.COPY (DA-GTERM.TERMLIST (DA-ACCESS TAF DEFINITION))))
			   (DA-SYMBOL.OCCURS.IN.GTERM SYMBOL DEFINITION))
		   (MAPCAR #'(LAMBDA (GTERM)
			       (MAPCAR #'(LAMBDA (X) 
					   (SETQ X (DA-TERM.COPY X))
					   (SETF (GETF (DA-TERM.ATTRIBUTES X) 'REC) 'COND)
					   X)
				       (DA-GTERM.TERMLIST GTERM)))
			   CALL.IN.CONDS))))
	  (T (SETQ SCHEMES (MAPCAR #'(LAMBDA (DEF.GTERM)
				       (REC=WFO.CREATE.MINIMIZED.TREE
					(DA-GTERM.DEF.VALUE DEF.GTERM) SYMBOL PROJECTION
					(APPEND CALL.IN.CONDS
						(MAPCAN #'(lambda (FOR)
							    (MAPCAR #'(LAMBDA (TAF) (DA-ACCESS TAF for))
								    (DA-SYMBOL.OCCURS.IN.GTERM symbol for)))
							(DA-GTERM.DEF.CONDITION DEF.GTERM)))))
				   (DA-GTERM.TERMLIST DEFINITION)))
	     (DA-WFO.TREE.CREATE
	      (NCONC (MAPCAR #'(LAMBDA (SCHEME DEF.GTERM)
				 (CONS SCHEME (DA-GTERM.DEF.CONDITION DEF.GTERM)))
			     SCHEMES (DA-GTERM.TERMLIST DEFINITION))
		     (MAPCAR #'(LAMBDA (CONDITION)
				 (CONS (DA-WFO.TREE.PRED.SET.CREATE NIL) CONDITION))
			     (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'UNSPEC.CASES)))
	      (not (INTERSECTION PROJECTION (GETF (DA-GTERM.ATTRIBUTES DEFINITION) 'RECURSION) :test 'equal)))))))


(DEFUN REC=WFO.SCHEMES.HAVE.COMMON.PRED.SET (SCHEMES)

  (LET ((COMMON.PRED.SET 'initial))
    (COND ((EVERY #'(LAMBDA (SCHEME)
		      (COND ((EQUAL COMMON.PRED.SET 'INITIAL)
			     (SETQ COMMON.PRED.SET (DA-WFO.TREE.PRED.SET SCHEME))
			     T)
			    ((NULL (DA-WFO.TREE.PRED.SET SCHEME)) 
			     (NULL COMMON.PRED.SET))
			    ((NULL COMMON.PRED.SET)
			     (NULL (DA-WFO.TREE.PRED.SET SCHEME)))
			    ((EVERY #'(LAMBDA (PRED)
					(MEMBER PRED COMMON.PRED.SET :TEST 'DA-WFO.PRED.ARE.EQUAL))
				    (DA-WFO.TREE.PRED.SET SCHEME)))
			    ((EVERY #'(LAMBDA (PRED)
					(MEMBER PRED (DA-WFO.TREE.PRED.SET SCHEME) :TEST 'DA-WFO.PRED.ARE.EQUAL))
				    COMMON.PRED.SET)
			     (SETQ COMMON.PRED.SET (DA-WFO.TREE.PRED.SET SCHEME))
			     T)))
		  SCHEMES)
	   (VALUES T COMMON.PRED.SET)))))


(DEFUN REC=WFO.TREE.REC.PARAMETERS (WFO.TREE FORMAL.PARAMETERS PROJECTION)

  ;;; Input  :  a WFO-tree and a list of the formal parameters and a list of argument positions
  ;;; Effect :  computes the subset of formal parameters, which are no local variables and which occur
  ;;;           in some conditions of the WFO-tree.
  ;;; Value  :  a multiple value : the subset of the formal parameters and a list with the corresponding
  ;;;           argument positions.

  (LET (VARIABLES CASE.VARS FORMAL.REC.PARS FORMAL.CASE.PARS NEW.PROJECTION NEW.CASE.PROJECTION (COUNTER 0))
    (MULTIPLE-VALUE-SETQ (VARIABLES CASE.VARS) (REC=WFO.TREE.ALL.VARIABLES WFO.TREE))
    (MAPC #'(LAMBDA (ORDER)
	      (SETQ VARIABLES (UNION VARIABLES (DA-GTERM.VARIABLES (CDR ORDER)))))
	  PROJECTION)
    (MAPC #'(LAMBDA (PAR)
	      (INCF COUNTER)
	      (COND ((MEMBER PAR VARIABLES)
		     (PUSH (DA-TERM.CREATE PAR) FORMAL.REC.PARS)
		     (PUSH COUNTER NEW.PROJECTION))
		    ((MEMBER PAR CASE.VARS)
		     (PUSH (DA-TERM.CREATE PAR) FORMAL.CASE.PARS)
		     (PUSH COUNTER NEW.CASE.PROJECTION))))
	  FORMAL.PARAMETERS)
    (VALUES (NREVERSE FORMAL.REC.PARS) (NREVERSE NEW.PROJECTION)
	    (NREVERSE FORMAL.CASE.PARS) (NREVERSE NEW.CASE.PROJECTION))))


(DEFUN REC=WFO.TREE.ALL.VARIABLES (WFO.TREE &OPTIONAL VARS CASE.VARS)

  ;;; Input:   a wfo-tree
  ;;; Effect:  computes all variables which are part of this wfo-tree.
  ;;; Value:   the computed set of variables
  
  (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE) NIL)
	  (T (MAPC #'(LAMBDA (CASE)
		       (MULTIPLE-VALUE-SETQ (VARS CASE.VARS)
			 (REC=WFO.TREE.ALL.VARIABLES (CAR CASE) VARS CASE.VARS))
		       (COND ((DA-WFO.TREE.IS.ESSENTIAL WFO.TREE)
			      (MAPC #'(LAMBDA (LIT)
					(SETQ VARS (UNION VARS (DA-GTERM.VARIABLES LIT))))
				    (CDR CASE)))
			     (T (MAPC #'(LAMBDA (LIT)
					(SETQ CASE.VARS (UNION CASE.VARS (DA-GTERM.VARIABLES LIT))))
				    (CDR CASE)))))
		   (DA-WFO.TREE.SUBNODES WFO.TREE))))
    (VALUES VARS CASE.VARS))


(DEFUN REC=WFO.ADJUST.SUBST.TO.PARAMS (WFO.TREE FORM.REC.PARS PROJECTION)

  ;;; Input  :  a WFO-tree, a subset of the formal parameters and their corresponding argument positions.
  ;;; Effect :  replaces each recursive call in the substitutions slot of each edge by the substitution
  ;;;           which replaces the subset of the formal parameters by the subset of the actual
  ;;;           recursive call.
  ;;; Value  :  the changed tree.

  (LET (CHANGEABLES NEW.CHANGEABLES ACTUAL.PAR RESULT)
       (COND ((DA-WFO.TREE.IS.LEAF WFO.TREE)
	      (SETQ WFO.TREE (DA-WFO.TREE.PRED.SET.CREATE
			      (MAPCAR #'(LAMBDA (REC.CALL)
						(MAPCAN #'(LAMBDA (FORM.PAR POS)
								  (SETQ ACTUAL.PAR (NTH (1- POS) REC.CALL))
								  (COND ((NOT (UNI-TERM.ARE.EQUAL FORM.PAR ACTUAL.PAR))
									 (PUSH FORM.PAR CHANGEABLES)
									 (LIST FORM.PAR ACTUAL.PAR))))
							FORM.REC.PARS PROJECTION))
				      (REMOVE-DUPLICATES (DA-WFO.TREE.PRED.SET WFO.TREE) :TEST #'UNI-TERMLIST.ARE.EQUAL)))))
	     (T (MAPC #'(LAMBDA (CASE)
				(MULTIPLE-VALUE-SETQ (RESULT NEW.CHANGEABLES)
						     (REC=WFO.ADJUST.SUBST.TO.PARAMS (CAR CASE) FORM.REC.PARS PROJECTION))
				(SETF (CAR CASE) RESULT)
				(SETQ CHANGEABLES (UNION CHANGEABLES NEW.CHANGEABLES :TEST #'UNI-TERM.ARE.EQUAL)))
		      (DA-WFO.TREE.SUBNODES WFO.TREE))))
       (VALUES WFO.TREE CHANGEABLES)))


(DEFUN REC=WFO.STRUCTURAL.TREE.CREATE (VARIABLE)
  ;;; edited : 23.03.93 by CS
  ;;; input  : a variable
  ;;; value  : a tree denoting a structural case analysis of the parameter, the leafs are
  ;;;          term substitutions for the predecessors

  (LET* ((PARAMETER (DA-TERM.CREATE VARIABLE NIL))
	 (STRUCTURE.TERMS (DA-SORT.CREATE.ALL.STRUCTURE.TERMS PARAMETER NIL)))
    (DA-WFO.TREE.CREATE (MAPCAR #'(LAMBDA (TERM)
				    (REC=WFO.PATH.CREATE PARAMETER TERM))
				STRUCTURE.TERMS))))


(DEFUN REC=WFO.PATH.CREATE (PARAMETER TERM)
  ;;; edited : 23.03.93 by CS
  ;;; input  : two terms, the first is a variable, the second is a structure term
  ;;; value  : a dotted pair denoting a path through the structural tree together with
  ;;;          the hypotheses substitutions for the structural order as leaf

  (LET ((CONSTRUCTOR.OR.INDEX (DA-TERM.SYMBOL TERM)))
    (CONS (DA-WFO.TREE.PRED.SET.CREATE 
	   (MAPCAN #'(LAMBDA (SELECTOR)
		       (COND ((DA-FUNCTION.IS.REFLEXIVE SELECTOR)
			      (LIST (UNI-TERMSUBST.CREATE.PARALLEL
				     (LIST (DA-TERM.COPY PARAMETER))
				     (LIST (DA-TERM.CREATE SELECTOR (LIST (DA-TERM.COPY PARAMETER)))))))))
		   (COND ((DA-FUNCTION.IS.CONSTRUCTOR CONSTRUCTOR.OR.INDEX)
			  (DA-SORT.SELECTORS.OF.CONSTRUCTOR CONSTRUCTOR.OR.INDEX)))))
	  (LIST (DA-LITERAL.CREATE (DA-SIGN.MINUS)
				   (DP-PREDICATE.EQUALITY)
				   (LIST (DA-TERM.COPY PARAMETER) (DA-TERM.COPY TERM))
				   (LIST 'KIND (LIST 'MATCH))
				   NIL)))))


;;;;;========================================================================================================
;;;;; Chapter 6.
;;;;; ----------
;;;;;
;;;;; Prove-function
;;;;;========================================================================================================



(DEFUN REC=PROVE.DISJUNCTION (LIT.LIST &OPTIONAL ORDERING)

  (LET (VARS)
    (MAPC #'(LAMBDA (LIT) (SETQ VARS (UNION VARS (DA-GTERM.VARIABLES LIT)))) LIT.LIST)
    (REC=PROVE.DISJUNCTION.INTERNAL LIT.LIST (MAPCAR #'(LAMBDA (X) (DA-TERM.CREATE X)) VARS) ORDERING)))


(DEFUN REC=PROVE.DISJUNCTION.INTERNAL (LIT.LIST PARAMETER.BOUND.TERMS ORDERING &OPTIONAL NO.RECORDING)
  
  (LET (SUBST LIT SYMBOL INVERSE.FLAG LEFT)
    (SETQ LIT.LIST (REMOVE-IF #'DA-LITERAL.IS.FALSE
			      (MAPCAN #'(LAMBDA (LIT) 
					  (REC=ORIGIN.INSERT (DA-FORMULA.JUNCTION.OPEN 'OR (EG-EVAL LIT)) (LIST LIT)))
				      LIT.LIST)))
    (COND ((SOME #'(LAMBDA (FORM) 
		     (COND ((DA-FORMULA.IS.TRUE FORM) (REC=ORIGIN.MARK FORM ORDERING))))
		 LIT.LIST))
	  ((SOME #'(LAMBDA (FORMULA)
		     (COND ((AND (DA-LITERAL.IS FORMULA)
				 (SETQ LIT (MEMBER FORMULA LIT.LIST
						   :TEST #'(LAMBDA (X Y) 
							     (AND (DA-LITERAL.IS X)
								  (DA-LITERAL.IS Y)
								  (UNI-LITERAL.ARE.EQUAL X Y NIL 'OPPOSITE))))))
			    (REC=ORIGIN.MARK FORMULA ORDERING)
			    (REC=ORIGIN.MARK (CAR LIT) ORDERING))))
		 LIT.LIST))
	  ((SOME #'(LAMBDA (FORM) 
		     (COND ((EQ (DA-GTERM.SYMBOL FORM) 'AND)
			    (EVERY #'(LAMBDA (ALT.FORM)
				       (REC=PROVE.DISJUNCTION.INTERNAL (CONS ALT.FORM (REMOVE FORM LIT.LIST)) 
								       PARAMETER.BOUND.TERMS ORDERING T))
				   (REC=ORIGIN.INSERT (DA-FORMULA.JUNCTION.OPEN 'AND FORM) (LIST FORM))))))
		 LIT.LIST))
	  ((SETQ LIT (FIND-IF #'(LAMBDA (LIT)
				  (COND ((AND (DA-LITERAL.IS LIT)
					      (MULTIPLE-VALUE-SETQ (LEFT SYMBOL INVERSE.FLAG)
						(DA-LITERAL.DENOTES.MATCH LIT)))
					 (AND (DA-SORT.IS.FREE.STRUCTURE (da-term.sort left))
					      (OR (NULL PARAMETER.BOUND.TERMS)
						  (MEMBER LEFT PARAMETER.BOUND.TERMS :TEST 'UNI-TERM.ARE.EQUAL))))))
			      LIT.LIST))
	   (COND (INVERSE.FLAG (COND ((EVERY #'(LAMBDA (STRUC.TERM)
						 (SETQ SUBST (UNI-TERMSUBST.CREATE NIL LEFT STRUC.TERM))
						 (REC=PROVE.DISJUNCTION.INTERNAL 
						  (MAPCAN #'(LAMBDA (FORM)
							      (REC=ORIGIN.INSERT (LIST (UNI-TERMSUBST.APPLY SUBST FORM))
										 (LIST LIT FORM)))
							  LIT.LIST)
						  (APPEND PARAMETER.BOUND.TERMS (DA-TERM.TERMLIST STRUC.TERM))
						  ORDERING T))
					     (DA-SORT.CREATE.ALL.STRUCTURE.TERMS LEFT (LIST SYMBOL))))
				     (T (COND ((AND (NOT NO.RECORDING) LIT.LIST)
					       (SETF (GETF rec*failed.proofs ORDERING)
						     (ADJOIN LIT.LIST (GETF rec*failed.proofs ORDERING) :test 'equal))))
					NIL)))
		 (T (SETQ SUBST (UNI-TERMSUBST.CREATE NIL LEFT (SECOND (DA-LITERAL.TERMLIST LIT))))
		    (REC=PROVE.DISJUNCTION.INTERNAL (MAPCAN #'(LAMBDA (FORM)
								(REC=ORIGIN.INSERT (LIST (UNI-TERMSUBST.APPLY SUBST FORM))
										   (LIST LIT FORM)))
							    LIT.LIST)
						    (APPEND PARAMETER.BOUND.TERMS 
							    (DA-TERM.TERMLIST (SECOND (DA-LITERAL.TERMLIST LIT))))
						    ORDERING NO.RECORDING))))
	  ((AND PARAMETER.BOUND.TERMS (REC=PROVE.DISJUNCTION.INTERNAL LIT.LIST NIL ORDERING T)))
	  ((REC=LITLIST.SUBSUMED.BY.DATABASE LIT.LIST ORDERING))
	  ((NOT NO.RECORDING)
	   (COND (LIT.LIST 
		   (SETF (GETF rec*failed.proofs ORDERING)
			 (ADJOIN LIT.LIST (GETF rec*failed.proofs ORDERING) :test 'equal))))
	   nil))))


(DEFUN REC=LITLIST.SUBSUMED.BY.DATABASE (LIT.LIST ORDERING)

  ;;; Input:   a list of literals, considered as disjunction
  ;;; Effect:  tests, whether there is an axiom or lemma in the given database
  ;;;          such that this formula subsumes \verb$LIT.LIST$.
  ;;;          In case there is such a formula, all used literals of \verb$LIT.LIST$
  ;;;          are marked by \verb$ORDERING$
  ;;; Value:   T, iff the subsumption test succeeds.

  (LET (MATCH.LITS OTHER.LITS LEFT SYMBOL INVERSE.FLAG  unifiers1 unifiers2 unifiers
	 ok used.lits otherlit term)
    (MAPC #'(LAMBDA (LIT)
	      (COND ((DA-LITERAL.IS LIT)
		     (MULTIPLE-VALUE-SETQ (LEFT SYMBOL INVERSE.FLAG)
		       (DA-LITERAL.DENOTES.MATCH LIT))
		     (COND ((AND LEFT
				 (NULL INVERSE.FLAG)
				 (DA-VARIABLE.IS (DA-TERM.SYMBOL LEFT)))
			    (PUSH LIT MATCH.LITS))
			   (T (PUSH LIT OTHER.LITS))))
		    (T (PUSH LIT OTHER.LITS))))
	  LIT.LIST)
    (cond ((SOME #'(LAMBDA (LIT)
		     (cond ((NOT (DA-LITERAL.IS LIT)) NIL)
			   ((da-literal.is.equation lit)
			    (cond ((DB-MODIFIER.SELECTION
				    (second (da-literal.termlist lit)) 'top.level NIL
				    #'(lambda (modifier)
					(cond ((and (setq unifiers1 (uni-term.match (da-modifier.input modifier)
										    (second (da-literal.termlist lit))
										    T))
						    (setq unifiers2 (uni-term.match (da-modifier.value modifier)
										    (car (da-literal.termlist lit))
										    t))
						    (setq unifiers (UNI-MATCHER.LIST.MERGE unifiers1 unifiers2)))
					       (cond ((multiple-value-setq (ok used.lits)
							(rec=lit.list.subsumed.by.modifier lit.list
											   (da-modifier.condition modifier)
											   unifiers))
						      (push lit used.lits))))))))
				  ((and (multiple-value-setq (term symbol) (da-literal.denotes.match lit))
					(da-sort.is.free.structure (da-term.sort term)))
				   (every #'(lambda (otherterm)
					      (setq otherlit (da-literal.create (da-sign.minus) (da-predicate.equality)
										(list (da-term.copy term) otherterm)))
					      (DB-PREDICATE.DATABASE.SELECTION
					       otherlit '--
					       #'(LAMBDA (OTHER.SIDE)
						   (cond ((setq unifiers (uni-literal.match (car other.side) otherlit t))
							  (cond ((multiple-value-setq (ok used.lits)
								   (rec=lit.list.subsumed.by.modifier
								    lit.list (da-formula.junction.open
									      'or (DA-GTERM.WITHOUT.TAFS (third other.side)
													 (fourth other.side)))
								    unifiers))
								 (push lit used.lits))))))))
					  (DA-SORT.CREATE.ALL.STRUCTURE.TERMS TERM (list symbol))))))
				   
			   (T (DB-PREDICATE.DATABASE.SELECTION
			       lit (da-literal.sign lit)
			       #'(LAMBDA (OTHER.SIDE)
				   (cond ((setq unifiers (uni-literal.match (car other.side) lit t))
					  (cond ((multiple-value-setq (ok used.lits)
						     (rec=lit.list.subsumed.by.modifier
						      lit.list (da-formula.junction.open
								'or (DA-GTERM.WITHOUT.TAFS (third other.side)
											   (fourth other.side)))
						      unifiers))
						 (push lit used.lits))))))))))
		 OTHER.LITS)
	   (MAPC #'(lambda (lit) (REC=ORIGIN.MARK lit ORDERING)) used.lits)
	   T))))



(DEFUN REC=LIT.LIST.SUBSUMED.BY.MODIFIER (LIT.LIST CONDITION UNIFIERS)

  (LET (SINGLE.UNIS TOTAL.UNIS USED.LITS)
    (COND ((EVERY #'(LAMBDA (COND)
		      (COND ((AND (DA-LITERAL.IS COND)
				  (SOME #'(LAMBDA (LIT)
					    (COND ((AND (SETQ SINGLE.UNIS (UNI-LITERAL.MATCH COND LIT))
							(SETQ TOTAL.UNIS (UNI-MATCHER.LIST.MERGE SINGLE.UNIS UNIFIERS)))
						   (PUSH LIT USED.LITS))))
					LIT.LIST))
			     (SETQ UNIFIERS TOTAL.UNIS))))
		  CONDITION)
	   (VALUES T USED.LITS)))))


(DEFUN REC=ORIGIN.INSERT (LIT.LIST ORIGINS)

  (LET (TRANS.ORIGINS)
    (MAPC #'(LAMBDA (FORM)
	      (SETQ TRANS.ORIGINS (UNION TRANS.ORIGINS 
					 (COND ((GETF (DA-GTERM.ATTRIBUTES FORM) 'ORIGIN))
					       (T (LIST FORM))))))
	  ORIGINS)
    (MAPC #'(LAMBDA (FORM)
	      (SETF (GETF (DA-GTERM.ATTRIBUTES FORM) 'ORIGIN) TRANS.ORIGINS))
	  LIT.LIST)
    LIT.LIST))


(DEFUN REC=ORIGIN.MARK (FORM ORDERING)
  (MAPC #'(LAMBDA (LIT)
	    (REC=RECURSION.MARK.NODE LIT ORDERING))
	(GETF (DA-GTERM.ATTRIBUTES FORM) 'ORIGIN)))


(DEFUN REC=RECURSION.MARK.NODE (LITERAL POSITIONS)

  ;;; Input  :  a tree and one of its leaves, a literal and a list of argument positions
  ;;; Effect :  searches for the occurrence of LITERAL in TREE and mark the corresponding node
  ;;;           to be recursive for the given argument positions.
  ;;; Value  :  undefined.

  (cond ((da-literal.is literal)
	 (SETF (GETF (DA-LITERAL.ATTRIBUTES LITERAL) 'RECURSION)
	       (UNION POSITIONS (GETF (DA-LITERAL.ATTRIBUTES LITERAL) 'RECURSION))))))



(DEFUN REC=LEX.INSERT.ORDERING.TO.CONDS (TERM CONDITIONS ORDERINGS)

  (SOME #'(LAMBDA (LITERAL)
	    (COND ((AND (DA-LITERAL.IS.MATCH LITERAL)
			(UNI-TERM.ARE.EQUAL TERM (CAR (DA-LITERAL.TERMLIST LITERAL))))
		   (REC=RECURSION.MARK.NODE LITERAL ORDERINGS)
		   (MAPC #'(LAMBDA (SUBTERM)
			     (REC=LEX.INSERT.ORDERING.TO.CONDS SUBTERM CONDITIONS ORDERINGS))
			 (DA-TERM.TERMLIST (SECOND (DA-LITERAL.TERMLIST LITERAL))))
		   T)))
	 CONDITIONS))


(defun rec=create.order (term)

  (cons (INCF rec*orderings) term))

