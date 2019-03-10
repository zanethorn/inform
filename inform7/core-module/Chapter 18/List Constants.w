[Lists::] List Constants.

In this section we compile I6 arrays for constant lists arising
from braced literals.

@h Definitions.

@ Every literal list in the source text, such as

>> {2, 12, 13}

is parsed into an instance of the following structure. There are two rules:
(1) every LL structure represents a syntactically well-formed list, in which
braces and commas balance; and
(2) there can be at most one LL structure at any word position.

=
typedef struct literal_list {
	struct wording unbraced_text; /* position in the source of quoted text, excluding braces */
	struct parse_node *list_text; /* used for problem reporting only */
	int listed_within_code; /* appears within a phrase, rather than (say) a table entry? */

	struct kind *entry_kind; /* i.e., of the entries, not the list */
	int kinds_known_to_be_inconsistent; /* problem(s) thrown when parsing these */
	struct llist_entry *first_llist_entry; /* linked list of contents */

	struct inter_name *ll_iname;

	int list_compiled; /* lists are compiled at several different points: has this one been done? */

	MEMORY_MANAGEMENT
} literal_list;

@ I believe "llath" is the Welsh word for "mile": not sure about "llist".

=
typedef struct llist_entry {
	struct parse_node *llist_entry_value;
	struct llist_entry *next_llist_entry;
	MEMORY_MANAGEMENT
} llist_entry;

@ One of the few pieces of Inform syntax which wouldn't look out of place in
a conventional programming language; list constants are series of values,
separated by commas, and enclosed in braces. The empty list |{ }| is valid
as a constant.

The values are in fact eventually required to be constants, and to have
mutually consistent kinds, but that checking is done after parsing, so it
isn't expressed in this grammar.

=
<s-literal-list> ::=
	\{ \} |								==> Rvalues::from_wording_of_list(Lists::kind_of_ll(Lists::empty_literal_list(Wordings::last_word(W)), FALSE), W)
	\{ <literal-list-contents> \}		==> Rvalues::from_wording_of_list(Lists::kind_of_ll(RP[1], FALSE), W)

<literal-list-contents> ::=
	<literal-list-entry> , <literal-list-contents> |	==> 0; *XP = Lists::add_to_ll(RP[1], RP[2], W, R[1])
	<literal-list-entry>				==> 0; *XP = Lists::add_to_ll(RP[1], Lists::empty_literal_list(W), W, R[1])

<literal-list-entry> ::=
	<s-value> |				==> FALSE; *XP = RP[1]
	......								==> TRUE; *XP = Specifications::new_UNKNOWN(W)

@ The grammar above builds our list structures from the bottom up. They begin
with a call to:

=
literal_list *Lists::empty_literal_list(wording W) {
	literal_list *ll = Lists::find_list_at(Wordings::first_wn(W));
	if (ll == NULL) {
		ll = CREATE(literal_list);
		ll->list_compiled = FALSE;
	}
	ll->unbraced_text = W; ll->entry_kind = K_value;
	ll->listed_within_code = FALSE;
	ll->kinds_known_to_be_inconsistent = FALSE;
	ll->ll_iname = NULL;
	ll->first_llist_entry = NULL;
	ll->list_text = NULL;
	Kinds::RunTime::ensure_basic_heap_present();
	return ll;
}

@ Parsing is quadratic in the number of constant lists in the source text,
which is in principle a bad thing, but in practice the following causes no
speed problems even on large-scale tests. If it becomes a problem, we can
easily trade the time spent here for memory, by attaching a pointer to
each word in the source text, or for complexity, by constructing some kind
of binary search tree.

=
literal_list *Lists::find_list_at(int incipit) {
	literal_list *ll;
	LOOP_OVER(ll, literal_list)
		if (Wordings::first_wn(ll->unbraced_text) == incipit)
			return ll;
	return NULL;
}

@ Note that the entry kind is initially unknown, and it's not even decided
for sure when we add the first entry. Here's how each entry is added,
recursing right to left (i.e., reversing the direction of reading):

=
literal_list *Lists::add_to_ll(parse_node *spec, literal_list *ll, wording W, int bad) {
	llist_entry *lle = CREATE(llist_entry);
	lle->next_llist_entry = ll->first_llist_entry;
	ll->first_llist_entry = lle;
	lle->llist_entry_value = spec;
	literal_list *ll2 = Lists::find_list_at(Wordings::first_wn(W));
	if (ll2) ll = ll2;
	ll->unbraced_text = W;
	if (bad) ll->kinds_known_to_be_inconsistent = TRUE;
	return ll;
}

@ With all the entries in place, we now have to reconcile their kinds, if
that's possible. Problems are only issued on request, and with the current
sentence cut down to just the list itself -- since otherwise we might be
printing out an entire huge table to report a problem in a single entry
which happens to be a malformed list.

=
kind *Lists::kind_of_ll(literal_list *ll, int issue_problems) {
	parse_node *cs = current_sentence;
	if (issue_problems) {
		if (ll->list_text == NULL)
			ll->list_text = NounPhrases::new_raw(ll->unbraced_text);
		current_sentence = ll->list_text;
	}
	kind *K = K_value;
	llist_entry *lle;
	for (lle = ll->first_llist_entry; lle; lle = lle->next_llist_entry) {
		parse_node *spec = lle->llist_entry_value;
		if (!ParseTree::is(spec, UNKNOWN_NT)) {
			if (Conditions::is_TEST_ACTION(spec))
				Dash::check_value_silently(spec, K_stored_action);
			else
				Dash::check_value_silently(spec, NULL);
		}
		spec = NonlocalVariables::substitute_constants(spec);
		kind *E = NULL;
		@<Work out the entry kind E@>;
		if (Kinds::Compare::eq(K, K_value)) K = E;
		else @<Revise K in the light of E@>;
	}
	if (ll->kinds_known_to_be_inconsistent) K = K_value;
	ll->entry_kind = K;
	current_sentence = cs;
	return Kinds::unary_construction(CON_list_of, K);
}

@<Work out the entry kind E@> =
	if (ParseTree::is(spec, UNKNOWN_NT)) {
		if (issue_problems) @<Issue a bad list entry problem@>;
		ll->kinds_known_to_be_inconsistent = TRUE;
		E = K;
	} else if ((ParseTree::is(spec, CONSTANT_NT) == FALSE) &&
		(Lvalues::is_constant_NONLOCAL_VARIABLE(spec) == FALSE)) {
		if (issue_problems) @<Issue a nonconstant list entry problem@>;
		ll->kinds_known_to_be_inconsistent = TRUE;
		E = K;
	} else {
		E = Specifications::to_kind(spec);
		if (E == NULL) {
			if (issue_problems) @<Issue a bad list entry problem@>;
			ll->kinds_known_to_be_inconsistent = TRUE;
		}
	}

@ The following broadens K to include E, if necessary, but never narrows K.
Thus a list containing a person, a woman and a door will see K become
successively "person", "person" (E being narrower), then "thing" (E being
incomparable, and "thing" being the max of "person" and "door").

@<Revise K in the light of E@> =
	kind *previous_K = K;
	K = Kinds::Compare::max(E, K);
	if (Kinds::Compare::eq(K, K_value)) {
		if (issue_problems) @<Issue a list entry kind mismatch problem@>;
		ll->kinds_known_to_be_inconsistent = TRUE;
		break;
	}

@<Issue a bad list entry problem@> =
	Problems::quote_source(1, current_sentence);
	Problems::quote_wording(2, ParseTree::get_text(spec));
	Problems::Issue::handmade_problem(_p_(PM_BadConstantListEntry));
	Problems::issue_problem_segment(
		"The constant list %1 contains an entry '%2' which isn't any "
		"form of constant I'm able to read.");
	Problems::issue_problem_segment(
		"%PNote that lists have to be written with spaces after commas, "
		"so I like '{2, 4}' but not '{2,4}', for instance.");
	Problems::issue_problem_end();

@<Issue a nonconstant list entry problem@> =
	Problems::quote_source(1, current_sentence);
	Problems::quote_wording(2, ParseTree::get_text(spec));
	Problems::quote_spec(3, spec);
	Problems::Issue::handmade_problem(_p_(PM_NonconstantConstantListEntry));
	Problems::issue_problem_segment(
		"The constant list %1 contains an entry '%2' which does make sense, "
		"but isn't a constant (it's %3). Only constants can appear as entries in "
		"constant lists, i.e., in lists written in braces '{' and '}'.");
	Problems::issue_problem_end();

@<Issue a list entry kind mismatch problem@> =
	Problems::quote_source(1, current_sentence);
	Problems::quote_wording(2, ParseTree::get_text(spec));
	Problems::quote_kind(3, E);
	Problems::quote_kind(4, previous_K);
	Problems::Issue::handmade_problem(_p_(PM_IncompatibleConstantListEntry));
	Problems::issue_problem_segment(
		"The constant list %1 contains an entry '%2' whose kind is '%3', but "
		"that's not compatible with the kind I had established from looking at "
		"earlier entries ('%4').");
	Problems::issue_problem_end();

@ The following allow other parts of Inform to find the kind of a constant
list at a given word position; either to discover the answer, or to force
problem messages out into the open --

=
kind *Lists::kind_of_list_at(wording W) {
	int incipit = Wordings::first_wn(W);
	literal_list *ll = Lists::find_list_at(incipit+1);
	if (ll) return Lists::kind_of_ll(ll, FALSE);
	return NULL;
}

void Lists::check_one(wording W) {
	int incipit = Wordings::first_wn(W);
	literal_list *ll = Lists::find_list_at(incipit+1);
	if (ll) Lists::kind_of_ll(ll, TRUE);
}

@ And this checks every list, with problem messages on:

=
void Lists::check(void) {
	if (problem_count == 0) {
		literal_list *ll;
		LOOP_OVER(ll, literal_list)
			Lists::kind_of_ll(ll, TRUE);
	}
}

@ That leaves just the compilation of lists at run-time. This used to be a
complex dance with initialisation code interleaved with heap construction,
so there was once a two-page explanation here, but it is now blessedly simple.

=
inter_name *Lists::compile_literal_list(wording W) {
	int incipit = Wordings::first_wn(W);
	literal_list *ll = Lists::find_list_at(incipit+1);
	if (ll) {
		kind *K = Lists::kind_of_ll(ll, FALSE);
		packaging_state save = Packaging::enter_current_enclosure();
		inter_name *N = Kinds::RunTime::begin_block_constant(K);
		Emit::array_iname_entry(Lists::iname(ll));
		Emit::array_numeric_entry(0);
		Kinds::RunTime::end_block_constant(K);
		Packaging::exit(save);
		return N;
	}
	return NULL;
}

inter_name *Lists::iname(literal_list *ll) {
	if (ll->ll_iname == NULL) {
		ll->ll_iname = InterNames::new(LITERAL_LIST_INAMEF);
		InterNames::to_symbol(ll->ll_iname);
	}
	return ll->ll_iname;
}

@ Using:

=
void Lists::compile(void) {
	literal_list *ll;

	if (problem_count == 0)
		LOOP_OVER(ll, literal_list)
			if ((ll->list_compiled == FALSE) && (ll->ll_iname)) {
				ll->list_compiled = TRUE;
				current_sentence = ll->list_text;
				Lists::kind_of_ll(ll, TRUE);
				if (problem_count == 0) @<Actually compile the list array@>;
			}
}

@ These are I6 word arrays, with the contents:

(a) a zero word, used as a flag at run-time;
(b) the strong kind ID of the kind of entry the list holds (not the kind of
the list!);
(c) the number of entries in the list; and
(d) that number of values, each representing one entry.

@<Actually compile the list array@> =
	Emit::named_array_begin(ll->ll_iname, K_value);
	llist_entry *lle;
	int n = 0;
	for (lle = ll->first_llist_entry; lle; lle = lle->next_llist_entry) n++;

	Kinds::RunTime::emit_block_value_header(Lists::kind_of_ll(ll, FALSE), TRUE, n+2);

	Kinds::RunTime::emit_strong_id(ll->entry_kind);

	Emit::array_numeric_entry((inter_t) n);
	for (lle = ll->first_llist_entry; lle; lle = lle->next_llist_entry)
		Specifications::Compiler::emit_constant_to_kind(
			lle->llist_entry_value, ll->entry_kind);
	Emit::array_end();

@ The default list of any given kind is empty.

=
void Lists::compile_default_list(inter_name *identifier, kind *K) {
	Emit::named_array_begin(identifier, K_value);
	Kinds::RunTime::emit_block_value_header(K, TRUE, 2);
	Kinds::RunTime::emit_strong_id(Kinds::unary_construction_material(K));
	Emit::array_numeric_entry(0);
	Emit::array_end();
}