[ExParser::Subtrees::] Verbal and Relative Clauses.

To break down an excerpt into NP and VP-like clauses, perhaps with
a primary verb (to make a sentence), perhaps only a relative clause (to make
a more complex NP).

@h Definitions.

@ This is a global mode for the S-parser: see below.

=
int force_all_SP_noun_phrases_to_be_physical = FALSE;

@h The top level of the S-grammar.
English is an SVO language, where the main parts of the sentence occur in the
order subject, verb, object. The following grammar parses that crucial division,
and note that it can be used either to form a complete sentence, where there
is an active verb --

>> now the silver bars are in the Hall of Mists;

or alternatively to make a more elaborate noun phrase, using a relative clause,
where there is no active verb:

>> a woman who carries the silver bars;

We sometimes also have to deal with English's use of "there" as a meaningless
placeholder to stand for a missing noun phrase:

>> there is an open door

@ The following parses a sentence with an active verb.

=
<s-sentence> ::=
	<s-existential-np> <s-existential-verb-tail> |	==> @<Make SV provided object is descriptive@>;
	<s-noun-phrase> <s-general-verb-tail>			==> @<Make SV@>;

<s-existential-verb-tail> ::=
	<copular-verb> <s-noun-phrase-nounless>			==> ExParser::Subtrees::verb_marker(RP[1], NULL, RP[2])

@<Make SV@> =
	ExParser::Subtrees::correct_for_adjectives(RP[1], RP[2]);
	*XP = ExParser::Subtrees::to_specification(TRUE, W, RP[1], RP[2]);

@ An ugly trick, invisible from the grammar itself, is that we forbid the
object to be a value. This removes cases like "if there is 21", but in fact
we do it to avoid problem messages whenever a table column exists with the
name "there". (Because of the unfortunately worded phrase "there is T"
for a table reference; the phrase should never have been called something
so ambiguous -- a bad decision in about 2003.)

@<Make SV provided object is descriptive@> =
	parse_node *op = RP[2];
	parse_node *test = op->down;
	if (ParseTree::is(test, AMBIGUITY_NT)) test = test->down;
	if (Specifications::is_description_like(test) == FALSE) return FAIL_NONTERMINAL;
	*XP = ExParser::Subtrees::to_specification(TRUE, W, NULL, op);

@ More generally, the tail syntax splits according to the verb in question. The
copular verb "to be" has special syntactic rules for its object phrase (for
Inform, at least: linguists would probably analyse this slightly differently).
We've just seen one special point: "to be" can take the placeholder
"there", which no other verb can. (English does allow this, for archaic or
dramatic purposes: "There lurks a mysterious invisible force." Inform
doesn't, and it also doesn't read the mathematical usage "there exists",
though this caused the author a certain pang of regret.) The verb "to be" is
considered "copular" because it acts to combine its subject and object: "X
is 5", "Y is blue", and so on, refer to just one thing but make a statement
about its nature or identity. Other verbs -- "to carry", say -- normally
refer to two different things, at least in their most general forms: "X
carries the briefcase". Therefore:

>> Mr Cogito is in the Dining Room.

should be parsed, but

>> Mr Cogito carries in the Dining Room.

should not. One can debate whether this is a difference of syntax or semantics,
but for Inform, it's handled at the syntax level.

The universal verb "to relate" needs a special syntax in order to
handle its extra object: see below.

=
<s-general-verb-tail> ::=
	<universal-verb> <s-universal-relation-term> |								==> ExParser::Subtrees::verb_marker(RP[1], NULL, RP[2])
	<meaningful-nonimperative-verb> <permitted-preposition> <s-noun-phrase> |	==> ExParser::Subtrees::verb_marker(RP[1], RP[2], RP[3])
	<meaningful-nonimperative-verb> <s-noun-phrase>								==> ExParser::Subtrees::verb_marker(RP[1], NULL, RP[2])

@ The verb marker is a temporary node used just to store the verb or preposition
usage; it's attached to the tree only briefly before sentence conversion
removes it again.

=
parse_node *ExParser::Subtrees::verb_marker(verb_usage *vu, preposition_identity *prep, parse_node *np) {
	parse_node *VP_part = ParseTree::new(UNKNOWN_NT);
	ParseTree::set_vu(VP_part, vu);
	ParseTree::set_prep(VP_part, prep);
	VP_part->down = np;
	return VP_part;
}

@ The following catches the "Y to Z" right-hand term of the universal relation,

>> X relates Y to Z

where Y and Z must somehow be folded into a single noun phrase. Conceptually it
would be neatest to represent this as a combination kind, but that might lead
us to require the presence of the heap, since combinations are stored on the
heap; and that would effectively make "relates" of limited use on Z-machine
works.

=
<s-universal-relation-term> ::=
	<s-noun-phrase> to <s-noun-phrase>	==> ExParser::val(Rvalues::from_pair(RP[1], RP[2]), W)

@ The following parses a noun phrase with a relative clause, which is
syntactically very similar to the case of a sentence. Sometimes the verb is
explicit, as here:

>> a woman who does not carry an animal

in which case "who", acting as a marker of the relative clause, is the
only way this differs from a sentence; but sometimes it is implicit:

>> a woman not in the Hall of Mists

In this case the verb is implicitly the copular verb "to be" and our
grammar has to differ from the sentence grammar above.

Some prepositions imply the player as object: "carried", in the sense of
"to be carried", for instance -- "The briefcase is carried". We fill the
relevant noun subtree with a representation of the player-object for those.

=
<s-np-with-relative-clause> ::=
	<s-noun-phrase-nounless> <s-implied-relative-verb-tail> |							==> @<Make SN@>
	<s-noun-phrase> <s-relative-verb-tail>												==> @<Make SN@>

<s-implied-relative-verb-tail> ::=
	<copular-preposition> <s-noun-phrase-nounless> |									==> ExParser::Subtrees::verb_marker(regular_to_be, RP[1], RP[2])
	not <copular-preposition> <s-noun-phrase-nounless>									==> ExParser::Subtrees::verb_marker(negated_to_be, RP[1], RP[2])

<s-relative-verb-tail> ::=
	<relative-clause-marker> <universal-verb> <s-universal-relation-term> |				==> ExParser::Subtrees::verb_marker(RP[2], NULL, RP[3])
	<relative-clause-marker> <meaningful-nonimperative-verb> <permitted-preposition> <s-noun-phrase> |	==> ExParser::Subtrees::verb_marker(RP[2], RP[3], RP[4])
	<relative-clause-marker> <meaningful-nonimperative-verb> <s-noun-phrase> 							==> ExParser::Subtrees::verb_marker(RP[2], NULL, RP[3])

@<Make SN@> =
	LOGIF(MATCHING, "So uncorrectedly RP[1] = $T\n", RP[1]);
	LOGIF(MATCHING, "and uncorrectedly RP[2] = $T\n", RP[2]);
	ExParser::Subtrees::correct_for_adjectives(RP[1], RP[2]);
	*XP = ExParser::Subtrees::to_specification(FALSE, W, RP[1], RP[2]);

@h Tidying up a sentence subtree.
This checks, in a paranoid sort of way, that a subtree is properly formed,
and also makes one useful correction when it sees a wrong guess as to whether
an adjective is meant as a noun.

=
void ExParser::Subtrees::correct_for_adjectives(parse_node *A, parse_node *B) {
	parse_node *subject_phrase_subtree, *object_phrase_subtree, *verb_phrase_subtree;

	if (A == NULL) internal_error("SV childless");

	subject_phrase_subtree = A;
	verb_phrase_subtree = B;

	if (verb_phrase_subtree->down == NULL)
		internal_error("SV childless");

	object_phrase_subtree = verb_phrase_subtree->down;
	@<Modify the object from a noun to an adjective if the subject is also a noun@>;
}

@ The following is used to correct the SV-subtree for something like "painting
is orange" so that "orange" will be used not as a noun but as an adjective.

@<Modify the object from a noun to an adjective if the subject is also a noun@> =

	if ((Rvalues::to_instance(object_phrase_subtree)) &&
		(subject_phrase_subtree) &&
		(Specifications::is_description_like(subject_phrase_subtree))) {
		parse_node *adjq = object_phrase_subtree;
		instance *I = Rvalues::to_instance(adjq);
		if (Instances::get_adjectival_phrase(I)) {
			adjective_usage *ale = AdjectiveUsages::new(Instances::get_adjectival_phrase(I), TRUE);
			parse_node *spec = Descriptions::from_proposition(NULL, ParseTree::get_text(adjq));
			Descriptions::add_to_adjective_list(ale, spec);
			verb_phrase_subtree->down = spec;
		}
	}

@h Values as noun phrases.
It is very nearly true that the subject and object noun phrases are parsed
by <s-value>, which was given in "Type Expressions and Values". But there
is a technicality: for reasons to do with ambiguities, <s-value> needs to
be able to try descriptions which involve only physical objects at one stage,
and then later to try other descriptions.

Note that <s-purely-physical-description> calls <s-description> which in
turn may, if there's a relative clause, call <s-np-with-relative-clause> and thus
<s-noun-phrase>. Rather than passing endless copies of a flag down the call
stack, we simply give <s-noun-phrase> a global mode of operation.

=
<s-purely-physical-description> internal {
	int s = force_all_SP_noun_phrases_to_be_physical;
	force_all_SP_noun_phrases_to_be_physical = TRUE;
	parse_node *p = NULL;
	if (<s-description>(W)) p = <<rp>>;
	force_all_SP_noun_phrases_to_be_physical = s;
	if (p) { *XP = p; return TRUE; }
	return FALSE;
}

<if-forced-physical> internal 0 {
	if (force_all_SP_noun_phrases_to_be_physical) return TRUE;
	return FALSE;
}

@ The upshot of this is that <s-noun-phrase> is only ever called in "purely
physical mode" when it will later be called outside that mode in any event,
and that therefore the set of excerpts matched by <s-noun-phrase> genuinely
is the same as that matched by <s-value>.

=
<s-noun-phrase> ::=
	<if-forced-physical> <s-variable-as-value> |		==> RP[2]
	<if-forced-physical> <s-description> |				==> RP[2]
	^<if-forced-physical> <s-value-uncached> |			==> RP[2]

<s-noun-phrase-nounless> ::=
	<if-forced-physical> <s-variable-as-value> |		==> RP[2]
	<if-forced-physical> <s-description-nounless> |		==> RP[2]
	^<if-forced-physical> <s-value-uncached> |			==> RP[2]

@ Finally, the following is needed for conditions ("if fixed in place
scenery, ...") where the object referred to is understood from context.

=
<s-descriptive-np> ::=
	( <s-descriptive-np> ) |	==> RP[1]
	<cardinal-number> |			==> @<Reject a bare number as descriptive@>
	<s-description> |			==> @<Construct a descriptive SN subtree@>
	<s-adjective-list-as-desc>	==> @<Construct a descriptive SN subtree@>

@ The reason a literal number is explicitly not allowed to be a condition is
that if something is created called (say) "Room 62" then "62" might be read
by <s-description> as an abbreviated reference to that room. (This doesn't
happen with non-descriptive NPs because then literal values are tried earlier,
pre-empting descriptions.)

@<Reject a bare number as descriptive@> =
	return FAIL_NONTERMINAL;

@<Construct a descriptive SN subtree@> =
	parse_node *sn = RP[1];
	if (ParseTree::int_annotation(sn, converted_SN_ANNOT)) {
		*XP = sn;
	} else {
		*XP = ExParser::Subtrees::to_specification(FALSE, W, RP[1], NULL);
	}
	parse_node *pn = *XP;
	ParseTree::set_text(pn, W);

@h Junction.
At this point we need to join two subtrees, called |A| and |B|. |A| is the
subject of the sentence phrase, |B| contains the verb marker and also the
object.

=
parse_node *PM_DescLocalPast_location = NULL;

parse_node *ExParser::Subtrees::to_specification(int SV_not_SN, wording W, parse_node *A, parse_node *B) {
	parse_node *R = ExParser::Subtrees::to_specification_inner(SV_not_SN, W, A, B);
	return R;
}
parse_node *ExParser::Subtrees::to_specification_inner(int SV_not_SN, wording W, parse_node *A, parse_node *B) {
	parse_node *spec;
	parse_node *subject_noun_phrase = NULL, *verb_phrase = NULL;
	verb_usage *vu = NULL; preposition_identity *prep = NULL;
	int verb_phrase_negated = FALSE;

	if (ParseTree::is(A, AMBIGUITY_NT)) {
		parse_node *amb = NULL;
		for (parse_node *poss = A->down; poss; poss = poss->next_alternative) {
			parse_node *one = ParseTree::duplicate(poss);
			one->next_alternative = NULL;
			parse_node *new_poss = ExParser::Subtrees::to_specification(SV_not_SN, W, one, B);
			if (!(ParseTree::is(new_poss, UNKNOWN_NT)))
				amb = ParseTree::add_possible_reading(amb, new_poss, W);
		}
		if (amb == NULL) amb = Specifications::new_UNKNOWN(W);
		return amb;
	}
	if ((B) && (B->down) && (ParseTree::is(B->down, AMBIGUITY_NT))) {
		parse_node *amb = NULL;
		for (parse_node *poss = B->down->down; poss; poss = poss->next_alternative) {
			parse_node *hmm = ParseTree::duplicate(B);
			hmm->down = ParseTree::duplicate(poss);
			hmm->down->next_alternative = NULL;
			parse_node *new_poss = ExParser::Subtrees::to_specification(SV_not_SN, W, A, hmm);
			if (!(ParseTree::is(new_poss, UNKNOWN_NT)))
				amb = ParseTree::add_possible_reading(amb, new_poss, W);
		}
		if (amb == NULL) amb = Specifications::new_UNKNOWN(W);
		return amb;
	}
	@<Reconstruct a bare description as a sentence with an implied absent subject@>;
	@<Check that the top structure of the tree is in order, and obtain the verb@>;

	pcalc_term *subj = CREATE(pcalc_term);
	*subj = Calculus::Terms::new_constant(NULL);

	if (SV_not_SN) @<Convert an SV subtree@>
	else @<Convert an SN subtree@>;

	return spec;
}

@ For instance, "if an open door" can contain a valid condition generating
an SV-subtree: the implied subject is whatever is being discussed (the I6 |self|
object, in practice) and the implied verb is "is", in the present tense.

@<Reconstruct a bare description as a sentence with an implied absent subject@> =
	if ((A) && (B == NULL)) {
		B = ExParser::Subtrees::verb_marker(regular_to_be, NULL, A);
		A = ParseTree::new(UNKNOWN_NT);
		SV_not_SN = TRUE;
		ExParser::Subtrees::correct_for_adjectives(A, B);
	}

@ Having performed that manoeuvre, we can be certain that the top of the tree
has the standard form, but we check it anyway.

@<Check that the top structure of the tree is in order, and obtain the verb@> =
	subject_noun_phrase = A;
	verb_phrase = B;

	if (verb_phrase->down == NULL) Problems::Issue::s_subtree_error("VP childless");

	if (ParseTree::get_type(verb_phrase) != UNKNOWN_NT)
		Problems::Issue::s_subtree_error("VP not a VP");

	vu = ParseTree::get_vu(verb_phrase);
	if (vu == NULL) Problems::Issue::s_subtree_error("verb null");
	verb_phrase_negated = (VerbUsages::is_used_negatively(vu))?TRUE:FALSE;
	prep = ParseTree::get_prep(verb_phrase);

@ There's a delicate little manoeuvre here. We have to be careful because
the tense and negation operators do not commute with each other: consider
the difference between "it was true that X is not Y" and "it is not true
that X was Y". It's therefore essential to apply these operators in the
correct order. What complicates this is that we have two ways to represent
the negation of an SV: "X is not Y" can be written as the negation operator
applied to "X is Y", which we'll call explicit negation, or as a direct
test of the proposition "not(X is Y)", which is implicit. Explicit negation
is essential if we need a non-present tense, because the tense operator
has to come between the negation operator and the test. So it might seem
that we should always use explicit negation. It makes no difference to
testing propositions, but it does make a difference to the "now" phrase,
because the asserting machinery can't take as wide a range of conditions
as the testing one: so, in general, a condition destined to be used in
a "now" must have implicit negation. Unfortunately, we can't know its
destiny yet. What saves the day is that "now" can only accept present
tense conditions anyway. We therefore adopt explicit negation only when
using a tense other than the present, and all is well.

@<Convert an SV subtree@> =
	int pass = verb_phrase_negated, explicit_negation = FALSE;

	if ((VerbUsages::is_used_negatively(vu)) && (VerbUsages::get_tense_used(vu) != IS_TENSE)) {
		explicit_negation = TRUE; pass = FALSE;
	}
	spec = Conditions::new_TEST_PROPOSITION(
		Calculus::Propositions::FromSentences::S_subtree(TRUE, W, A, B, subj, pass));
	ParseTree::set_subject_term(spec, subj);
	if (Wordings::nonempty(W)) ParseTree::set_text(spec, W);
	if (VerbUsages::get_tense_used(vu) != IS_TENSE) {
		if (Calculus::Variables::detect_locals(Specifications::to_proposition(spec), NULL) > 0)
			@<Issue a problem for referring to temporary values at a time when they did not exist@>;
		spec = Conditions::attach_tense(spec, VerbUsages::get_tense_used(vu));
	}
	if (explicit_negation)
		spec = Conditions::negate(spec);

@<Issue a problem for referring to temporary values at a time when they did not exist@> =
	if (PM_DescLocalPast_location != current_sentence)
		Problems::Issue::sentence_problem(_p_(PM_DescLocalPast),
			"conditions written in the past tense cannot refer to "
			"temporary values",
			"because they have no past. For instance, the name given in a "
			"'repeat...' can't be talked about as having existed before, and "
			"similarly the pronoun 'it' changes its meaning often, so we can't "
			"safely talk about 'it' in the past.");
	PM_DescLocalPast_location = current_sentence;

@ This is easier, because tenses don't arise.

@<Convert an SN subtree@> =
	spec = Descriptions::from_proposition(
		Calculus::Propositions::FromSentences::S_subtree(FALSE, W, A, B, subj, verb_phrase_negated), W);
	ParseTree::set_subject_term(spec, subj);
	ParseTree::annotate_int(spec, converted_SN_ANNOT, TRUE);
	if (A) @<Veto certain cases where text was misunderstood as a description@>;
	if (VerbUsages::get_tense_used(vu) != IS_TENSE) ExParser::Subtrees::throw_past_problem(TRUE);

@ This is a little inelegant, but it catches awkward phrases such as "going
south in the Home" which might be read otherwise as "going south" (an action
pattern) plus "in the Home" (a description).

@<Veto certain cases where text was misunderstood as a description@> =
	if (!((ParseTree::is(A, CONSTANT_NT)) ||
		(Specifications::is_description(A)) ||
		(Lvalues::get_storage_form(A) == LOCAL_VARIABLE_NT) ||
		(Lvalues::get_storage_form(A) == NONLOCAL_VARIABLE_NT)))
		return Specifications::new_UNKNOWN(W);

@ =
void ExParser::Subtrees::throw_past_problem(int desc) {
	if (PM_PastSubordinate_issued_at != current_sentence) {
		PM_PastSubordinate_issued_at = current_sentence;
			Problems::Issue::sentence_problem(_p_(PM_PastSubordinate),
				"subordinate clauses have to be in the present tense",
				"so 'the Black Door was open' is fine, but not 'something which "
				"was open'. Only the main verb can be in the past tense.");
	}
}