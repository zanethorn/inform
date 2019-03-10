[Calculus::Deferrals::] Deciding to Defer.

To decide whether a proposition can be compiled immediately, in the
body of the current routine, or whether it must be deferred to a routine of
its own, which is called from the current routine.

@h Definitions.

@ So far in this chapter, we have written code which suggests that there
are basically only three ways to compile a proposition: as a test
("if the tree is blossoming"), as code forcing it to be true ("now
the tree is blossoming") or as code forcing it to be false ("now the
tree is not blossoming"). That's not quite true, and so deferral can happen
for a number of different reasons, enumerated as follows:

@d CONDITION_DEFER 1 /* "if S", where S is a sentence */
@d NOW_ASSERTION_DEFER 2 /* "now S" */
@d EXTREMAL_DEFER 3 /* "the heaviest X", where X is a description */
@d LOOP_DOMAIN_DEFER 4 /* "repeat with I running through X" */
@d NUMBER_OF_DEFER 5 /* "the number of X" */
@d TOTAL_DEFER 6 /* "the total P of X" */
@d RANDOM_OF_DEFER 7 /* "a random X" */
@d LIST_OF_DEFER 8 /* "the list of X" */

@d MULTIPURPOSE_DEFER 100 /* potentially any of the above */

=
typedef struct pcalc_prop_deferral {
	int reason; /* what we intend to do with it: one of the reasons above */
	struct pcalc_prop *proposition_to_defer; /* the proposition */
	struct parse_node *deferred_from; /* remember where it came from, for Problem reports */
	struct general_pointer defn_ref; /* sometimes we must remember other things too */
	struct kind *cinder_kinds[16]; /* the kinds of value being cindered (see below) */
	struct inter_name *ppd_iname; /* routine to implement this */
	struct inter_name *rtp_iname; /* compile a string of the origin text for run-time problems? */
	MEMORY_MANAGEMENT
} pcalc_prop_deferral;

@h The guillotine.
We must be careful not to request a fresh deferral after the point at which
all deferral requests are redeemed -- they would then never be reached.

=
int no_further_deferrals = FALSE;
void Calculus::Deferrals::allow_no_further_deferrals(void) {
	no_further_deferrals = TRUE;
}

@h Deferral requests.
The following fills out the paperwork to request a deferred proposition.

=
pcalc_prop_deferral *Calculus::Deferrals::new_deferred_proposition(pcalc_prop *prop, int reason) {
	pcalc_prop_deferral *pdef = CREATE(pcalc_prop_deferral);
	pdef->proposition_to_defer = prop;
	pdef->reason = reason;
	pdef->deferred_from = current_sentence;
	pdef->rtp_iname = NULL;
//	pdef->ppd_iname = InterNames::new_in(DEFERRED_PROPOSITION_ROUTINE_INAMEF, Modules::current());
	pdef->ppd_iname = Packaging::function(Packaging::supply_iname(Packaging::current_enclosure(), PROPOSITION_PR_COUNTER), Packaging::current_enclosure(), NULL);


	Inter::Symbols::set_flag(InterNames::to_symbol(pdef->ppd_iname), MAKE_NAME_UNIQUE);

	if (no_further_deferrals) internal_error("Too late now to defer propositions");
	return pdef;
}

@ It's worth cacheing deferral requests in the case of loop domains,
because they are typically needed in the case of repeat-through loops where
the same proposition is used three times in a row.

=
pcalc_prop *cache_loop_proposition = NULL;
pcalc_prop_deferral *cache_loop_pdef = NULL;

pcalc_prop_deferral *Calculus::Deferrals::defer_loop_domain(pcalc_prop *prop) {
	pcalc_prop_deferral *pdef;
	if (prop == cache_loop_proposition) return cache_loop_pdef;
	pdef = Calculus::Deferrals::new_deferred_proposition(prop, LOOP_DOMAIN_DEFER);
	cache_loop_proposition = prop;
	cache_loop_pdef = pdef;
	return pdef;
}

@ The following shorthand routine takes a description SP, converts it to
a proposition $\phi(x)$, then defers this and returns the number |n| such
that the resulting routine will be called |Prop_n|.

=
inter_name *Calculus::Deferrals::compile_deferred_description_test(parse_node *spec) {
	pcalc_prop *prop = Specifications::to_proposition(spec);
	if (Calculus::Propositions::contains_callings(prop)) {
		Problems::Issue::sentence_problem(_p_(PM_CantCallDeferredDescs),
			"'called' can't be used when testing a description",
			"since it would make a name for something which existed only "
			"so temporarily that it couldn't be used anywhere else.");
		return NULL;
	} else {
		pcalc_prop_deferral *pdef = Calculus::Deferrals::new_deferred_proposition(prop, CONDITION_DEFER);
		return pdef->ppd_iname;
	}
}

@h Testing, or deferring a test.
Given a proposition $\phi$, and a value $v$, we compile a valid I6 condition
to decide whether or not $\phi(v)$ is true. $\phi$ can either be a sentence
with all variables bound, in which case $v$ must be null, or can have just
variable $x$ free, in which case $v$ must not be null.

We defer the proposition to a routine of its own if and only if it contains
quantification.

=
void Calculus::Deferrals::emit_test_of_proposition(parse_node *substitution, pcalc_prop *prop) {
	value_holster VH = Holsters::new(INTER_VAL_VHMODE);
	Calculus::Deferrals::compile_test_of_proposition_inner(&VH, substitution, prop);
}

void Calculus::Deferrals::compile_test_of_proposition_inner(value_holster *VH,
	parse_node *substitution, pcalc_prop *prop) {
	LOGIF(PREDICATE_CALCULUS_WORKINGS, "Compiling as test: $D\n", prop);

	prop = Calculus::Propositions::copy(prop);

	if (prop == NULL) {
		Emit::val(K_truth_state, LITERAL_IVAL, 1);
	} else if (Calculus::Propositions::contains_quantifier(prop)) {
		@<Defer test of proposition instead@>;
	} else {
		if (substitution) Calculus::Variables::substitute_var_0_in(prop, substitution);
		TRAVERSE_VARIABLE(pl);
		pcalc_prop *last_pl = NULL;
		TRAVERSE_PROPOSITION(pl, prop) last_pl = pl;
		if (last_pl) Calculus::Deferrals::ctop_recurse(VH, prop, prop, last_pl);
	}
}

@ Since this is the first of our deferrals, let's take it slowly. We are
compiling code in some outer routine -- let's call it |R| -- and the idea
is to compile a function call |Prop_19(...)| into |R| where the test should
be; this function will return either |true| or |false|, and its job is to
test the proposition for us. (Deferred propositions are numbered in order
of deferral; for the sake of example, we'll suppose ours in number 19.)

@<Defer test of proposition instead@> =
	pcalc_prop_deferral *pdef;
	LocalVariables::begin_condition_emit();
	int go_up = FALSE;
	@<If the proposition is a negation, take care of that now@>;
	int NC = Calculus::Deferrals::count_callings_in_condition(prop);
	if (NC > 0) {
		Emit::inv_primitive(and_interp);
		Emit::down();
	}
	pdef = Calculus::Deferrals::new_deferred_proposition(prop, CONDITION_DEFER);
	@<Compile the call to the test-proposition routine@>;
	if (NC > 0) Calculus::Deferrals::emit_retrieve_callings_in_condition(prop, NC);
	if (NC > 0) Emit::up();
	if (go_up) Emit::up();
	LocalVariables::end_condition_emit();

@ This is done purely for the sake of compiling tidier code: if $\phi = \lnot(\psi)$
then we defer $\psi$ instead, negating the result of testing it.

@<If the proposition is a negation, take care of that now@> =
	if (Calculus::Propositions::is_a_group(prop, NEGATION_OPEN_ATOM)) {
		prop = Calculus::Propositions::remove_topmost_group(prop);
		Emit::inv_primitive(not_interp); Emit::down(); go_up = TRUE;
	}

@ All of the subtlety here is to do with the fact that |R| and |Prop_19|
have access to different values -- in particular, they have different sets
of local variables.

Because code in |Prop_19| cannot see the local variables of |R|, any such
values needed must be passed from |R| to |Prop_19| as call parameters.
These passed values are called "cinders".

In addition, |R| might not be able to evaluate the substitution value $v$
for itself, so that must also be a call parameter. It will then become the
initial value of the local variable |x| in |Prop_19|, and since $x$ is free
in the proposition, |x| never changes in |Prop_19|: thus we effect a
substitution of $x=v$.

For example, |R| might contain the function call:

	|Prop_19(t_6, t_2, O13_sphinx)|

and the function header of |Prop_19| might then look like so:

	|[ Prop_19 const_0 const_1 x;|

The value of |cinder_count| would then be 2.

@<Compile the call to the test-proposition routine@> =
	Emit::inv_call(InterNames::to_symbol(pdef->ppd_iname));
	Emit::down();
		Calculus::Deferrals::Cinders::find_emit(prop, pdef);
		if (substitution) Specifications::Compiler::emit_as_val(K_value, substitution);
	Emit::up();

@ =
void Calculus::Deferrals::ctop_recurse(value_holster *VH, pcalc_prop *prop, pcalc_prop *from_pl, pcalc_prop *to_pl) {
	int active = FALSE, bl = 0;
	pcalc_prop *penultimate_pl = NULL;
	TRAVERSE_VARIABLE(pl);
	TRAVERSE_PROPOSITION(pl, prop) {
		if (pl == from_pl) active = TRUE;
		if (active) {
			if ((bl == 0) && (pl != from_pl) &&
				(Calculus::Propositions::implied_conjunction_between(pl_prev, pl))) {
				Emit::inv_primitive(and_interp); Emit::down();
				Calculus::Deferrals::ctop_recurse(VH, prop, from_pl, pl_prev);
				Calculus::Deferrals::ctop_recurse(VH, prop, pl, to_pl);
				Emit::up();
				return;
			}
			if (pl->element == NEGATION_CLOSE_ATOM) bl--;
			if (pl->element == NEGATION_OPEN_ATOM) bl++;
		}
		if (pl == to_pl) { active = FALSE; penultimate_pl = pl_prev; }
	}

	if ((from_pl->element == NEGATION_OPEN_ATOM) && (to_pl->element == NEGATION_CLOSE_ATOM)) {
		Emit::inv_primitive(not_interp);
		Emit::down();
		if (from_pl == penultimate_pl) {
			Emit::val(K_truth_state, LITERAL_IVAL, 1);
		} else {
			Calculus::Deferrals::ctop_recurse(VH, prop, from_pl->next, penultimate_pl);
		}
		Emit::up();
		return;
	}

	active = FALSE;
	TRAVERSE_PROPOSITION(pl, prop) {
		if (pl == from_pl) active = TRUE;
		if (active) {
			switch(pl->element) {
				case NEGATION_OPEN_ATOM: internal_error("blundered");
					break;
				case NEGATION_CLOSE_ATOM: internal_error("blundered");
					break;
				default:
					Calculus::Atoms::Compile::compile(VH, TEST_ATOM_TASK, pl, TRUE);
					break;
			}
		}
		if (pl == to_pl) active = FALSE;
	}
}

@ When we defer a test, we make "called" more tricky to achieve. Suppose
we are compiling a condition for

>> if a woman (called the moll) has a weapon (called the gun), ...

This needs to set two local variables, "moll" and "gun", but those
have to be locals in |R| -- they are inaccessible to |Prop_19|. Somehow,
they need to be return values, but I6 supports only a single return value
from a routine, and that needs to be either |true| or |false|. What to do?

The answer is that |Prop_19| copies these values onto a special I6 array
called the "deferred calling list". The very last thing that |Prop_19|
does before it returns is to fill in this list; the very first thing we
do on receiving that return is to extract what we want from it. (Because
no other activity takes place in between, there is no risk that some
recursive use of propositions will overwrite the list.)

For example, |R| might this time contain a call like so:

	|(Prop_19() && (t_2=deferred_calling_list-->0, t_3=deferred_calling_list-->1, true))|

which safely transfers the values to locals |t_2| and |t_3| of |R|. Note
that I6 evaluates conditions joined by |&&| from left to right, so we
can be certain that |Prop_19| has been called and has returned before we
get to the setting of |t_2| and |t_3|.

=
int Calculus::Deferrals::count_callings_in_condition(pcalc_prop *prop) {
	int calling_count=0;
	TRAVERSE_VARIABLE(pl);
	TRAVERSE_PROPOSITION(pl, prop) {
		switch(pl->element) {
			case CALLED_ATOM: {
				calling_count++;
				break;
			}
		}
	}
	return calling_count;
}

void Calculus::Deferrals::emit_retrieve_callings_in_condition(pcalc_prop *prop, int NC) {
	Emit::inv_primitive(sequential_interp);
	Emit::down();
		int calling_count = 0, downs = 0;
		TRAVERSE_VARIABLE(pl);
		TRAVERSE_PROPOSITION(pl, prop) {
			switch(pl->element) {
				case CALLED_ATOM: {
					local_variable *local;
					@<Find which local variable in R needs the value, creating it if necessary@>;
					calling_count++;
					if (calling_count < NC) { Emit::inv_primitive(sequential_interp); Emit::down(); downs++; }
					Emit::inv_primitive(store_interp);
					Emit::down();
						inter_symbol *local_s = LocalVariables::declare_this(local, FALSE, 8);
						Emit::ref_symbol(K_value, local_s);
						Emit::inv_primitive(lookup_interp);
						Emit::down();
							Emit::val_iname(K_value, InterNames::extern(DEFERREDCALLINGLIST_EXNAMEF));
							Emit::val(K_number, LITERAL_IVAL, (inter_t) (calling_count - 1));
						Emit::up();
					Emit::up();
					LocalVariables::add_calling_to_condition(local);
					break;
				}
			}
		}
		while (downs > 0) { Emit::up(); downs--; }
		if (calling_count == 0) internal_error("called improperly");
		Emit::val(K_truth_state, LITERAL_IVAL, 1);
	Emit::up();
}

void Calculus::Deferrals::emit_retrieve_callings(pcalc_prop *prop) {
	int calling_count=0;
	TRAVERSE_VARIABLE(pl);
	TRAVERSE_PROPOSITION(pl, prop) {
		switch(pl->element) {
			case CALLED_ATOM: {
				local_variable *local;
				@<Find which local variable in R needs the value, creating it if necessary@>;
				Emit::inv_primitive(sequential_interp);
				Emit::down();
					Emit::inv_primitive(store_interp);
					Emit::down();
						inter_symbol *local_s = LocalVariables::declare_this(local, FALSE, 8);
						Emit::ref_symbol(K_value, local_s);
						Emit::inv_primitive(lookup_interp);
						Emit::down();
							Emit::val_iname(K_value, InterNames::extern(DEFERREDCALLINGLIST_EXNAMEF));
							Emit::val(K_number, LITERAL_IVAL, (inter_t) calling_count++);
						Emit::up();
					Emit::up();
				break;
			}
		}
	}
	if (calling_count > 0) {
		Emit::inv_primitive(lookup_interp);
		Emit::down();
			Emit::val_iname(K_value, InterNames::extern(DEFERREDCALLINGLIST_EXNAMEF));
			Emit::val(K_number, LITERAL_IVAL, 26);
		Emit::up();
	}
}

@ And for value context:

=
void Calculus::Deferrals::prepare_to_retrieve_callings(OUTPUT_STREAM, pcalc_prop *prop, int condition_context) {
	if ((condition_context == FALSE) && (Calculus::Propositions::contains_callings(prop))) {
		WRITE("deferred_calling_list-->26 = ");
	}
}

int Calculus::Deferrals::emit_prepare_to_retrieve_callings(pcalc_prop *prop, int condition_context) {
	if ((condition_context == FALSE) && (Calculus::Propositions::contains_callings(prop))) {
		Emit::inv_primitive(store_interp);
		Emit::down();
			Emit::inv_primitive(lookupref_interp);
			Emit::down();
				Emit::val_iname(K_value, InterNames::extern(DEFERREDCALLINGLIST_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, 26);
			Emit::up();
		return TRUE;
	}
	return FALSE;
}

@ |LocalVariables::ensure_called_local| is so called because it ensures that a local of the
right name and kind of value exists in |R|.

@<Find which local variable in R needs the value, creating it if necessary@> =
	wording W = Calculus::Atoms::CALLED_get_name(pl);
	local = LocalVariables::ensure_called_local(W, pl->assert_kind);

@ The following wrapper contributes almost nothing, but it checks some
consistency assertions and writes to the debugging log.

=
void Calculus::Deferrals::emit_test_if_var_matches_description(parse_node *var, parse_node *matches) {
	if (matches == NULL) internal_error("VMD against null description");
	if (var == NULL) internal_error("VMD on null variable");
	if ((Lvalues::get_storage_form(var) != NONLOCAL_VARIABLE_NT) &&
		(Lvalues::get_storage_form(var) != LOCAL_VARIABLE_NT))
		internal_error("VMD on non-variable");

	LOG_INDENT;
	pcalc_prop *prop = Calculus::Propositions::from_spec(matches);
	kind *K = Specifications::to_kind(var);
	prop = Calculus::Propositions::concatenate(
		Calculus::Atoms::KIND_new(K, Calculus::Terms::new_variable(0)), prop);
	LOGIF(DESCRIPTION_COMPILATION, "[VMD: $P ($u) matches $D]\n", var, K, prop);
	if (Calculus::Propositions::Checker::type_check(prop,
		Calculus::Propositions::Checker::tc_no_problem_reporting()) == NEVER_MATCH) {
		Emit::val(K_truth_state, LITERAL_IVAL, 0);
	} else {
		Calculus::Deferrals::emit_test_of_proposition(var, prop);
	}
	LOG_OUTDENT;
}

@h Forcing with now, or deferring the force.
For example, compiling code to achieve something like:

>> now the Marble Door is closed;

(which does not need to be deferred) or

>> now all the women are in the Dining Room;

(which does, since it contains a quantifier).

This is simpler than testing, because a "now" does not have callings, and
because it always acts on whole sentences -- no substitution is ever needed;
the only call parameters for our |Prop_19| are the cinders, if any; and we
never need to extract from the |deferred_calling_list|.

Once again the question arises of how to force $\lnot(\phi\land\psi)$ to
be true. It would be sufficient to falsify either one of $\phi$ or $\psi$
alone, but for the sake of symmetry we falsify both. (We took the same
decision when asserting propositions about the initial state of the model.)

=
void Calculus::Deferrals::emit_now_proposition(pcalc_prop *prop) {
	int quantifier_count = 0;

	LOGIF(PREDICATE_CALCULUS_WORKINGS, "Compiling as 'now': $D\n", prop);

	@<Count quantifiers in, and generally vet, the proposition to be forced@>;

	if (quantifier_count > 0) {
		pcalc_prop_deferral *pdef = Calculus::Deferrals::new_deferred_proposition(prop, NOW_ASSERTION_DEFER);
		Emit::inv_call(InterNames::to_symbol(pdef->ppd_iname));
		Emit::down();
		Calculus::Deferrals::Cinders::find_emit(prop, pdef);
		Emit::up();
	} else {
		int parity = TRUE;
		TRAVERSE_VARIABLE(pl);
		TRAVERSE_PROPOSITION(pl, prop) {
			switch (pl->element) {
				case NEGATION_OPEN_ATOM: case NEGATION_CLOSE_ATOM:
					parity = (parity)?FALSE:TRUE;
					break;
				default:
					Calculus::Atoms::Compile::emit(
						(parity)?NOW_ATOM_TRUE_TASK:NOW_ATOM_FALSE_TASK, pl, TRUE);
					break;
			}
		}
	}
}

@ We reject multiple quantifiers as too much work, and $\exists x$ because
it would either require us to judge the $x$ most likely to be meant -- tricky --
or to create an $x$ out of nothing, which it's too late for, since Inform
does not have run-time object or value creation.

@<Count quantifiers in, and generally vet, the proposition to be forced@> =
	TRAVERSE_VARIABLE(pl);
	TRAVERSE_PROPOSITION(pl, prop) {
		switch(pl->element) {
			case QUANTIFIER_ATOM:
				if (Calculus::Atoms::is_existence_quantifier(pl)) {
					Problems::Issue::sentence_problem(_p_(PM_CantForceExistence),
						"this is not explicit enough",
						"and should set out definite relationships between specific "
						"things, like 'now the cat is in the bag', not something "
						"more elusive like 'now the cat is carried by a woman.' "
						"(Which woman? That's the trouble.)");
					return;
				}
				if (Calculus::Atoms::is_now_assertable_quantifier(pl) == FALSE) {
					Problems::Issue::sentence_problem(_p_(PM_CantForceGeneralised),
						"this can't be made true with 'now'",
						"because it is too vague about what it applies to. It's fine "
						"to say 'now all the doors are open' or 'now none of the doors "
						"is open', because that clearly tells me which doors are "
						"affected; but if you write 'now six of the doors are open' "
						"or 'now almost all the doors are open', what am I to do?");
					return;
				}
				quantifier_count++;
				break;
			case CALLED_ATOM:
				Problems::Issue::sentence_problem(_p_(PM_CantForceCalling),
					"a 'now' is not allowed to call names",
					"and it wouldn't really make sense to do so anyway. 'if "
					"a person (called the victim) is in the Trap Room' makes "
					"sense, because it gives a name - 'victim' - to someone "
					"whose identity we don't know. But 'now a person (called "
					"the victim) is in the Trap Room' won't be allowed, "
					"because 'now' can only talk about people or things whose "
					"identities we do know.");
				return;
		}
	}

@h Multipurpose descriptions.
Descriptions in the form $\phi(x)$, where $x$ is free, are also sometimes
converted into values -- this is the kind of value "description". The
I6 representation is (the address of) a routine |D| which, in general,
performs task $u$ on value $v$ when called as |D(u, v)|, where $u$ is
expected to be one of the following values. (Note that $v$ is only needed
in the first two cases.)

These numbers {\it must} be negative, since they need to be different from
every valid member of a quantifiable domain (objects, enumerated kinds, truth
states, times of day, and so on).

@d CONDITION_DUSAGE -1 /* return |true| iff $\phi(v)$ */
@d LOOP_DOMAIN_DUSAGE -2 /* return the next $x$ after $v$ such that $\phi(x)$ */
@d NUMBER_OF_DUSAGE -3 /* return the number of $w$ such that $\phi(w)$ */
@d RANDOM_OF_DUSAGE -4 /* return a random $w$ such that $\phi(w)$, or 0 if none exists */
@d TOTAL_DUSAGE -5 /* return the total value of a property among $w$ such that $\phi(w)$ */
@d EXTREMAL_DUSAGE -6 /* return the maximal property value among such $w$ */
@d LIST_OF_DUSAGE -7 /* return the list of $w$ such that $\phi(w)$ */

@ Multi-purpose description routines are pretty dandy, then, but they have
one big drawback: they can't be passed cinders, because they might be called
from absolutely anywhere. Hence the following:

=
void Calculus::Deferrals::compile_multiple_use_proposition(value_holster *VH,
	parse_node *spec, kind *K) {

	int negate = FALSE;
	quantifier *q = Descriptions::get_quantifier(spec);
	if (q == not_exists_quantifier) negate = TRUE;
	else if ((q) && (q != for_all_quantifier)) {
		Problems::quote_source(1, current_sentence);
		Problems::quote_spec(2, spec);
		Problems::Issue::handmade_problem(_p_(BelievedImpossible));
		Problems::issue_problem_segment(
			"In %1 you wrote the description '%2' in the context of a value, "
			"but descriptions used that way are not allowed to talk about "
			"quantities. For example, it's okay to write 'an even number' "
			"as a description value, but not 'three numbers' or 'most numbers'.");
		Problems::issue_problem_end();
	}
	pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
	if (negate) {
		prop = Calculus::Propositions::concatenate(Calculus::Atoms::new(NEGATION_OPEN_ATOM), prop);
		prop = Calculus::Propositions::concatenate(prop, Calculus::Atoms::new(NEGATION_CLOSE_ATOM));
	}
	prop = Calculus::Propositions::concatenate(
		Calculus::Atoms::KIND_new(K, Calculus::Terms::new_variable(0)), prop);
	if (Calculus::Propositions::Checker::type_check(prop,
		Calculus::Propositions::Checker::tc_no_problem_reporting()) == NEVER_MATCH) return;
	parse_node *example = NULL;
	if (Calculus::Variables::detect_locals(prop, &example) > 0) {
		LOG("Offending proposition: $D\n", prop);
		Problems::quote_source(1, current_sentence);
		Problems::quote_wording(2, ParseTree::get_text(example));
		Problems::Issue::handmade_problem(_p_(PM_LocalInDescription));
		Problems::issue_problem_segment(
			"You wrote %1, but descriptions used as values are not allowed to "
			"contain references to temporary values (defined by 'let', or by loops, "
			"or existing only in certain rulebooks or actions, say) - unfortunately "
			"'%2' is just such a temporary value. The problem is that it may well "
			"not exist any more when the description needs to be used, in another "
			"time and another place.");
		Problems::issue_problem_end();
	} else {
		pcalc_prop_deferral *pdef = Calculus::Deferrals::new_deferred_proposition(prop, MULTIPURPOSE_DEFER);
		Emit::val_iname(K_value, pdef->ppd_iname);
	}
}

@ Because multipurpose descriptions have this big drawback, we want to avoid
them if we possibly can. Fortunately something much simpler will often do.
For example, consider:

>> [1] the number of members of S
>> [2] the number of closed doors

where S, in [1], is a description which appears as a parameter in a phrase.
In [1] we have no way of knowing what S might be, but we can safely assume
that it has been compiled as a multi-purpose description routine, and
therefore compile the function call:

	|D(NUMBER_OF_DUSAGE)|

But in case [2] it is sufficient to take $\phi(x) = {\it door}(x)\land{\it closed}(x)$,
defer it to a proposition with reason |NUMBER_OF_DEFER|, and then compile just

	|Prop_19()|

to perform the calculation. We never need a multi-purpose description routine for
$\phi(x)$ because it only occurs in this one context.

@ We now perform this trick for "number of":

=
void Calculus::Deferrals::emit_number_of_S(parse_node *spec) {
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_primitive(indirect1_interp);
		Emit::down();
			Specifications::Compiler::emit_as_val(K_value, spec);
			Emit::val(K_number, LITERAL_IVAL, (inter_t) NUMBER_OF_DUSAGE);
		Emit::up();
	} else {
		pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
		Calculus::Deferrals::prop_verify_descriptive(prop, "a number of things matching a description", spec);
		Calculus::Deferrals::emit_call_to_deferred_desc(prop, NUMBER_OF_DEFER, NULL_GENERAL_POINTER, NULL);
	}
}

@ Where we employ:

=
int Calculus::Deferrals::spec_is_variable_of_kind_description(parse_node *spec) {
	if ((ParseTreeUsage::is_lvalue(spec)) &&
		(Kinds::get_construct(Specifications::to_kind(spec)) == CON_description))
		return TRUE;
	return FALSE;
}

void Calculus::Deferrals::emit_call_to_deferred_desc(pcalc_prop *prop,
	int reason, general_pointer data, kind *K) {
	pcalc_prop_deferral *pdef = Calculus::Deferrals::new_deferred_proposition(prop, reason);
	pdef->defn_ref = data;
	int with_callings = Calculus::Propositions::contains_callings(prop);
	if (with_callings) {
		Emit::inv_primitive(sequential_interp);
		Emit::down();
	}
	int L = Emit::level();
	Calculus::Deferrals::emit_prepare_to_retrieve_callings(prop, FALSE);

	int arity = Calculus::Deferrals::Cinders::find_count(prop, pdef);
	if (K) arity = arity + 2;
	switch (arity) {
		case 0: Emit::inv_primitive(indirect0_interp); break;
		case 1: Emit::inv_primitive(indirect1_interp); break;
		case 2: Emit::inv_primitive(indirect2_interp); break;
		case 3: Emit::inv_primitive(indirect3_interp); break;
		case 4: Emit::inv_primitive(indirect4_interp); break;
		default: internal_error("indirect function call with too many arguments");
	}
	Emit::down();
	Emit::val_iname(K_value, pdef->ppd_iname);
	Calculus::Deferrals::Cinders::find_emit(prop, pdef);
	if (K) {
		Frames::emit_allocation(K);
		Kinds::RunTime::emit_strong_id_as_val(Kinds::unary_construction_material(K));
	}
	Emit::up();
	while (Emit::level() > L) Emit::up();
	Calculus::Deferrals::emit_retrieve_callings(prop);
	if (with_callings) { Emit::up(); Emit::up(); }

}

@ And for "list of":

=
void Calculus::Deferrals::emit_list_of_S(parse_node *spec, kind *K) {
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYDESC_EXNAMEF)));
		Emit::down();
			Frames::emit_allocation(K);
			Specifications::Compiler::emit_as_val(K_value, spec);
			Kinds::RunTime::emit_strong_id_as_val(Kinds::unary_construction_material(K));
		Emit::up();
	} else {
		pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
		Calculus::Deferrals::prop_verify_descriptive(prop, "a list of things matching a description", spec);
		Calculus::Deferrals::emit_call_to_deferred_desc(prop, LIST_OF_DEFER, NULL_GENERAL_POINTER, K);
	}
}

@ The pattern is repeated for "a random ...":

=
void Calculus::Deferrals::emit_random_of_S(parse_node *spec) {
	if (Rvalues::is_CONSTANT_construction(spec, CON_description)) {
		kind *K = ParseTree::get_kind_of_value(spec);
		K = Kinds::unary_construction_material(K);
		if ((K) && (Kinds::Behaviour::is_an_enumeration(K)) &&
			(Specifications::to_proposition(spec) == NULL) &&
			(Kinds::Compare::lt(Specifications::to_kind(spec), K_object) == FALSE) &&
			(Descriptions::to_instance(spec) == NULL) &&
			(Descriptions::number_of_adjectives_applied_to(spec) == 0)) {
			Emit::inv_primitive(indirect0_interp);
			Emit::down();
				Emit::val_iname(K_value, Kinds::Behaviour::get_ranger_iname(K));
			Emit::up();
			return;
		}
	}
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_primitive(indirect1_interp);
		Emit::down();
			Specifications::Compiler::emit_as_val(K_value, spec);
			Emit::val(K_number, LITERAL_IVAL, (inter_t) RANDOM_OF_DUSAGE);
		Emit::up();
	} else {
		pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
		Calculus::Deferrals::prop_verify_descriptive(prop, "a random thing matching a description", spec);
		kind *K = Calculus::Propositions::describes_kind(prop);
		if ((K) && (Kinds::Behaviour::compile_domain_possible(K) == FALSE))
			@<Issue random impossible problem@>
		else
			Calculus::Deferrals::emit_call_to_deferred_desc(prop, RANDOM_OF_DEFER, NULL_GENERAL_POINTER, NULL);
	}
}

@<Issue random impossible problem@> =
	Problems::Issue::sentence_problem(_p_(PM_RandomImpossible),
		"this asks to find a random choice from a range which is too "
		"large or impractical",
		"so can't be done. For instance, 'a random person' is fine - "
		"it's clear exactly who all the people are, and the supply is "
		"limited - but not 'a random text'.");

@ And similarly for "total of":

=
void Calculus::Deferrals::emit_total_of_S(property *prn, parse_node *spec) {
	if (prn == NULL) internal_error("total of on non-property");
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_primitive(sequential_interp);
		Emit::down();
			Emit::inv_primitive(store_interp);
			Emit::down();
				Emit::ref_iname(K_value, InterNames::extern(PROPERTYTOBETOTALLED_EXNAMEF));
				Emit::val_iname(K_value, Properties::iname(prn));
			Emit::up();
			Emit::inv_primitive(indirect1_interp);
			Emit::down();
				Specifications::Compiler::emit_as_val(K_value, spec);
				Emit::val(K_number, LITERAL_IVAL, (inter_t) TOTAL_DUSAGE);
			Emit::up();
		Emit::up();
	} else {
		pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
		Calculus::Deferrals::prop_verify_descriptive(prop,
			"a total property value for things matching a description", spec);
		Calculus::Deferrals::emit_call_to_deferred_desc(prop, TOTAL_DEFER,
			STORE_POINTER_property(prn), NULL);
	}
}

@ Also for the occasionally useful task of seeing if the current value of
the "substitution variable") is within the domain.

=
void Calculus::Deferrals::emit_substitution_test(parse_node *in,
	parse_node *spec) {
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_primitive(indirect2_interp);
		Emit::down();
			Specifications::Compiler::emit_as_val(K_value, spec);
			Emit::val(K_number, LITERAL_IVAL, (inter_t) CONDITION_DUSAGE);
			Specifications::Compiler::emit_as_val(K_value, in);
		Emit::up();
	} else {
		Calculus::Deferrals::emit_test_of_proposition(
			in, Calculus::Propositions::from_spec(spec));
	}
}

@ A variation on which is:

=
void Calculus::Deferrals::emit_substitution_now(parse_node *in,
	parse_node *spec) {
	pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
	Calculus::Variables::substitute_var_0_in(prop, in);
	Calculus::Propositions::Checker::type_check(prop,
		Calculus::Propositions::Checker::tc_no_problem_reporting());
	int save_cck = suppress_C14CantChangeKind;
	suppress_C14CantChangeKind = TRUE;
	Calculus::Deferrals::emit_now_proposition(prop);
	suppress_C14CantChangeKind = save_cck;
}

@ And the extremal case is pretty well the same, too, with only some fuss
over identifying which superlative is meant. We get here from code like

>> let X be the heaviest thing in the wooden box;

where there has previously been a definition of "heavy".

=
void Calculus::Deferrals::emit_extremal_of_S(parse_node *spec,
	property *prn, int sign) {
	if (prn == NULL) internal_error("extremal of on non-property");
	if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) {
		Emit::inv_primitive(sequential_interp);
		Emit::down();
			Emit::inv_primitive(store_interp);
			Emit::down();
				Emit::ref_iname(K_value, InterNames::extern(PROPERTYTOBETOTALLED_EXNAMEF));
				Emit::val_iname(K_value, Properties::iname(prn));
			Emit::up();
			Emit::inv_primitive(sequential_interp);
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_iname(K_value, InterNames::extern(PROPERTYLOOPSIGN_EXNAMEF));
					Emit::val(K_number, LITERAL_IVAL, (inter_t) sign);
				Emit::up();
				Emit::inv_primitive(indirect1_interp);
				Emit::down();
					Specifications::Compiler::emit_as_val(K_value, spec);
					Emit::val(K_number, LITERAL_IVAL, (inter_t) EXTREMAL_DUSAGE);
				Emit::up();
			Emit::up();
		Emit::up();
	} else {
		measurement_definition *mdef_found = Properties::Measurement::retrieve(prn, sign);
		if (mdef_found) {
			pcalc_prop *prop = Calculus::Propositions::from_spec(spec);
			Calculus::Deferrals::prop_verify_descriptive(prop,
				"an extreme case of something matching a description", spec);
			Calculus::Deferrals::emit_call_to_deferred_desc(prop, EXTREMAL_DEFER,
				STORE_POINTER_measurement_definition(mdef_found), NULL);
		}
	}
}

@h Domains of loops.
Here we define an I6 |for| loop header to handle a repeat loop through all
of the $x$ matching a given description $\phi(x)$.

We are allowed to use two local variables in the current stack frame: |t_v1|
and |t_v2|, where the numbers $v_1$ and $v_2$ are supplied to us. We mark
them as available for reuse once the loop has been exited, by setting their
scope to the code block for the loop.

We use $v_1$ as the current value and $v_2$ as the one which will follow it.
Always evaluating one step ahead protects us in case the body of the loop
takes action which moves $v_1$ out of the domain -- e.g., in the case of

>> repeat with T running through items on the table: now T is in the box.

This is the famous "broken |objectloop|" hazard of Inform 6, which typically
occurs because the mechanism to move from one value to the next uses |sibling|
in the I6 object tree, and that relies on $v_1$ being an object which is still
in the same location at the end of the loop as at the beginning.

Thus a typical loop header has the form

	|for (t_1=D(0), t_2=D(t_1): t_1: t_1=t_2, t_2=D(t_1))|

where |D| is a routine such that at 0 it produces the first element of the
domain, and then given |x| in the domain, |D(x)| produces the next element
until it returns 0, when the domain is exhausted.

=
void Calculus::Deferrals::emit_repeat_through_domain_S(parse_node *spec,
	local_variable *v1) {
	kind *DK = Specifications::to_kind(spec);
	if (Kinds::get_construct(DK) != CON_description)
		internal_error("repeat through non-description");
	kind *K = Kinds::unary_construction_material(DK);

	local_variable *v2 = LocalVariables::new(EMPTY_WORDING, K);

	Frames::Blocks::set_scope_to_block_about_to_open(v1);
	Frames::Blocks::set_scope_to_block_about_to_open(v2);

	inter_symbol *val_var_s = LocalVariables::declare_this(v1, FALSE, 8);
	inter_symbol *aux_var_s = LocalVariables::declare_this(v2, FALSE, 8);

	if (Kinds::Compare::le(K, K_object)) {
		pcalc_prop *domain_prop = NULL; int use_as_is = FALSE;
		if (Calculus::Deferrals::spec_is_variable_of_kind_description(spec)) use_as_is = TRUE;
		else {
			domain_prop = Calculus::Propositions::from_spec(spec);
			if (Calculus::Propositions::contains_callings(domain_prop))
				@<Issue called in repeat problem@>;
		}

		Emit::inv_primitive(for_interp);
		Emit::down();
			Emit::inv_primitive(sequential_interp);
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, val_var_s);
					if (use_as_is) Calculus::Deferrals::emit_repeat_call(spec, NULL);
					else Calculus::Deferrals::emit_repeat_domain(domain_prop, NULL);
				Emit::up();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, aux_var_s);
					if (use_as_is) Calculus::Deferrals::emit_repeat_call(spec, v1);
					else Calculus::Deferrals::emit_repeat_domain(domain_prop, v1);
				Emit::up();
			Emit::up();

			Emit::val_symbol(K_value, val_var_s);

			Emit::inv_primitive(sequential_interp);
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, val_var_s);
					Emit::val_symbol(K_value, aux_var_s);
				Emit::up();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, aux_var_s);
					if (use_as_is) Calculus::Deferrals::emit_repeat_call(spec, v2);
					else Calculus::Deferrals::emit_repeat_domain(domain_prop, v2);
				Emit::up();
			Emit::up();

			Emit::code();
			Emit::down();
	} else {
		BEGIN_COMPILATION_MODE;
		COMPILATION_MODE_EXIT(DEREFERENCE_POINTERS_CMODE);
		i6_schema loop_schema;
		if (Calculus::Deferrals::write_loop_schema(&loop_schema, K)) {
			Calculus::Schemas::emit_expand_from_locals(&loop_schema, v1, v2, TRUE);
			if (ParseTreeUsage::is_lvalue(spec) == FALSE) {
				if (Specifications::to_proposition(spec)) {
					Emit::inv_primitive(if_interp);
					Emit::down();
						Calculus::Deferrals::emit_test_of_proposition(
							Lvalues::new_LOCAL_VARIABLE(EMPTY_WORDING, v1),
							Specifications::to_proposition(spec));
						Emit::code();
						Emit::down();
				}
			} else {
				Emit::inv_primitive(if_interp);
				Emit::down();
					Emit::inv_primitive(indirect2_interp);
					Emit::down();
						Specifications::Compiler::emit_as_val(K_value, spec);
						Emit::val(K_number, LITERAL_IVAL, (inter_t) CONDITION_DUSAGE);
						Specifications::Compiler::emit_as_val(K_value,
							Lvalues::new_LOCAL_VARIABLE(EMPTY_WORDING, v1));
					Emit::up();
					Emit::code();
					Emit::down();
			}
		} else @<Issue bad repeat domain problem@>;
		END_COMPILATION_MODE;
	}
}

@<Issue called in repeat problem@> =
	Problems::Issue::sentence_problem(_p_(PM_CalledInRepeat),
		"this tries to use '(called ...)' to give names to values "
		"arising in the course of working out what to repeat through",
		"but this is not allowed. (Sorry: it's too hard to get right.)");

@<Issue bad repeat domain problem@> =
	Problems::Issue::sentence_problem(_p_(PM_BadRepeatDomain),
		"this describes a collection of values which can't be repeated through",
		"because the possible range is too large (or has no sensible ordering). "
		"For instance, you can 'repeat with D running through doors' because "
		"there are only a small number of doors and they can be put in order "
		"of creation. But you can't 'repeat with N running through numbers' "
		"because numbers are without end.");

@ If the domain is a kind of object, say "things", then we can certainly
perform the loop by inefficiently looping through all objects and checking
each in turn for its class membership -- this is slow, though, so we ask
the counting plugin to optimise matters by using a linked list fixed at
compile time.

If it happens that no instances exist -- unlikely for things, but often true
of more unusual kinds -- then a loop header which never executes the block
following it is compiled.

If the domain |K| is not a kind of object, then we loop through the
known constants which make up this kind of value; each kind is
allowed to provide its own loop syntax for this. For "time", for
instance, it becomes a |for| loop running from 0 (midnight) to 1439 (one
minute to midnight).

In all cases, we copy a valid schema to |sch| if the loop can be made, and
return |TRUE| or |FALSE| to indicate success.

@d MAX_LOOP_DOMAIN_SCHEMA_LENGTH 1000

=
int Calculus::Deferrals::write_loop_schema(i6_schema *sch, kind *K) {
	if (K == NULL) return FALSE;

	if (Kinds::Compare::lt(K, K_object)) {
		if (PL::Counting::optimise_loop(sch, K) == FALSE)
			Calculus::Schemas::modify(sch, "objectloop (*1 ofclass %n)",
				Kinds::RunTime::I6_classname(K));
		return TRUE;
	}

	if (Kinds::Compare::eq(K, K_object)) {
		Calculus::Schemas::modify(sch, "objectloop (*1 ofclass Object)");
		return TRUE;
	}

	if (Kinds::Behaviour::is_an_enumeration(K)) {
		Calculus::Schemas::modify(sch,
			"for (*1=1: *1<=%d: *1++)", Kinds::Behaviour::get_highest_valid_value_as_integer(K));
		return TRUE;
	}

	text_stream *p = K->construct->loop_domain_schema;
	if (p == NULL) return FALSE;
	Calculus::Schemas::modify(sch, "%S", p);
	return TRUE;
}

@ If the description $D$ is not explicitly known -- because it sits inside
a variable -- then the following compiles code to call |D| in order to
calculate the next value in the domain after the one stored in |fromv|.

Here, once again, we know that $D$ has been compiled to a general-purpose
deferred description routine, and we simply call that routine with the
|LOOP_DOMAIN_DUSAGE| task.

=
void Calculus::Deferrals::emit_repeat_call(parse_node *spec, local_variable *fromv) {
	Emit::inv_primitive(indirect2_interp);
	Emit::down();
		Specifications::Compiler::emit_as_val(K_value, spec);
		Emit::val(K_number, LITERAL_IVAL, (inter_t) LOOP_DOMAIN_DUSAGE);
		if (fromv) {
			inter_symbol *fromv_s = LocalVariables::declare_this(fromv, FALSE, 8);
			Emit::val_symbol(K_value, fromv_s);
		} else {
			Emit::val(K_number, LITERAL_IVAL, 0);
		}
	Emit::up();
}

@ But if the description $D=\phi(x)$ is an explicitly known proposition,
then we defer it to a routine specifically tailored to loop domains -- it
will never be needed for anything else.

=
void Calculus::Deferrals::emit_repeat_domain(pcalc_prop *prop, local_variable *fromv) {
	pcalc_prop_deferral *pdef = Calculus::Deferrals::defer_loop_domain(prop);
	int arity = Calculus::Deferrals::Cinders::find_count(prop, pdef) + 1;
	switch (arity) {
		case 0: Emit::inv_primitive(indirect0_interp); break;
		case 1: Emit::inv_primitive(indirect1_interp); break;
		case 2: Emit::inv_primitive(indirect2_interp); break;
		case 3: Emit::inv_primitive(indirect3_interp); break;
		case 4: Emit::inv_primitive(indirect4_interp); break;
		default: internal_error("indirect function call with too many arguments");
	}
	Emit::down();
		Emit::val_iname(K_value, pdef->ppd_iname);
		Calculus::Deferrals::Cinders::find_emit(prop, pdef);
		if (fromv) {
			inter_symbol *fromv_s = LocalVariables::declare_this(fromv, FALSE, 8);
			Emit::val_symbol(K_value, fromv_s);
		} else {
			Emit::val(K_number, LITERAL_IVAL, 0);
		}
	Emit::up();
}

@ And for looping over lists:

=
void Calculus::Deferrals::emit_loop_over_list_S(parse_node *spec, local_variable *val_var) {
	local_variable *index_var = LocalVariables::new(EMPTY_WORDING, K_number);
	local_variable *copy_var = LocalVariables::new(EMPTY_WORDING, K_number);
	kind *K = Specifications::to_kind(spec);
	kind *CK = Kinds::unary_construction_material(K);

	int pointery = FALSE;
	if (Kinds::Behaviour::uses_pointer_values(CK)) {
		pointery = TRUE;
		LocalVariables::mark_to_free_at_end_of_scope(val_var);
	}

	Frames::Blocks::set_scope_to_block_about_to_open(val_var);
	LocalVariables::set_kind(val_var, CK);
	Frames::Blocks::set_scope_to_block_about_to_open(index_var);

	inter_symbol *val_var_s = LocalVariables::declare_this(val_var, FALSE, 8);
	inter_symbol *index_var_s = LocalVariables::declare_this(index_var, FALSE, 8);
	inter_symbol *copy_var_s = LocalVariables::declare_this(copy_var, FALSE, 8);

	BEGIN_COMPILATION_MODE;
	COMPILATION_MODE_EXIT(DEREFERENCE_POINTERS_CMODE);
	Emit::inv_primitive(for_interp);
	Emit::down();
		Emit::inv_primitive(sequential_interp);
		Emit::down();
			Emit::inv_primitive(store_interp);
			Emit::down();
				Emit::ref_symbol(K_value, copy_var_s);
				Specifications::Compiler::emit_as_val(K_value, spec);
			Emit::up();
			Emit::inv_primitive(sequential_interp);
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, index_var_s);
					Emit::val(K_number, LITERAL_IVAL, 1);
				Emit::up();
				if (pointery) {
					Emit::inv_primitive(sequential_interp);
					Emit::down();
						Emit::inv_primitive(store_interp);
						Emit::down();
							Emit::ref_symbol(K_value, val_var_s);
							Emit::inv_call(InterNames::to_symbol(InterNames::extern(BLKVALUECREATE_EXNAMEF)));
							Emit::down();
								Kinds::RunTime::emit_strong_id_as_val(CK);
							Emit::up();
						Emit::up();
						Emit::inv_call(InterNames::to_symbol(InterNames::extern(BLKVALUECOPYAZ_EXNAMEF)));
						Emit::down();
							Emit::val_symbol(K_value, val_var_s);
							Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYGETITEM_EXNAMEF)));
							Emit::down();
								Emit::val_symbol(K_value, copy_var_s);
								Emit::val_symbol(K_value, index_var_s);
								Emit::val(K_truth_state, LITERAL_IVAL, 1);
							Emit::up();
						Emit::up();
					Emit::up();
				} else {
					Emit::inv_primitive(store_interp);
					Emit::down();
						Emit::ref_symbol(K_value, val_var_s);
						Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYGETITEM_EXNAMEF)));
						Emit::down();
							Emit::val_symbol(K_value, copy_var_s);
							Emit::val_symbol(K_value, index_var_s);
							Emit::val(K_truth_state, LITERAL_IVAL, 1);
						Emit::up();
					Emit::up();
				}
			Emit::up();
		Emit::up();

		Emit::inv_primitive(le_interp);
		Emit::down();
			Emit::val_symbol(K_value, index_var_s);
			Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYGETLENGTH_EXNAMEF)));
			Emit::down();
				Emit::val_symbol(K_value, copy_var_s);
			Emit::up();
		Emit::up();

		Emit::inv_primitive(sequential_interp);
		Emit::down();
			Emit::inv_primitive(postincrement_interp);
			Emit::down();
				Emit::ref_symbol(K_value, index_var_s);
			Emit::up();
			if (pointery) {
				Emit::inv_call(InterNames::to_symbol(InterNames::extern(BLKVALUECOPYAZ_EXNAMEF)));
				Emit::down();
					Emit::val_symbol(K_value, val_var_s);
					Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYGETITEM_EXNAMEF)));
					Emit::down();
						Emit::val_symbol(K_value, copy_var_s);
						Emit::val_symbol(K_value, index_var_s);
						Emit::val(K_truth_state, LITERAL_IVAL, 1);
					Emit::up();
				Emit::up();
			} else {
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::ref_symbol(K_value, val_var_s);
					Emit::inv_call(InterNames::to_symbol(InterNames::extern(LISTOFTYGETITEM_EXNAMEF)));
					Emit::down();
						Emit::val_symbol(K_value, copy_var_s);
						Emit::val_symbol(K_value, index_var_s);
						Emit::val(K_truth_state, LITERAL_IVAL, 1);
					Emit::up();
				Emit::up();
			}
		Emit::up();

		Emit::code();
			Emit::down();

	END_COMPILATION_MODE;
}

@h Checking the validity of a description.
The following utility routine checks that a proposition contains exactly
one unbound variable, producing problem messages if not, and that it
passes type-checking successfully.

=
void Calculus::Deferrals::prop_verify_descriptive(pcalc_prop *prop, char *billing,
	parse_node *constructor) {

	if (constructor == NULL) internal_error("description with null constructor");

	/* best guess at the text to quote in any problem message */
	wording EW = ParseTree::get_text(constructor);
	if ((Wordings::empty(EW)) && (constructor->down))
		EW = ParseTree::get_text(constructor->down);

	if (Calculus::Variables::is_well_formed(prop) == FALSE)
		internal_error("malformed proposition in description verification");

	int N = Calculus::Variables::number_free(prop);

	if (N == 1)
		Calculus::Propositions::Checker::type_check(prop,
			Calculus::Propositions::Checker::tc_problem_reporting(EW,
			"involve a range of objects matching a description"));

	if (N > 1) {
		Problems::quote_source(1, current_sentence);
		Problems::quote_text(2, billing);
		Problems::quote_wording(3, EW);
		Problems::Issue::handmade_problem(_p_(BelievedImpossible));
		Problems::issue_problem_segment(
			"In %1, you are asking for %2, but this should range over a "
			"simpler description than '%3', please - it should not include any "
			"determiners such as 'at least three', 'all' or 'most'. "
			"(The range is always taken to be all of the things matching "
			"the description.)");
		Problems::issue_problem_end();
		return;
	}

	if (N < 1) {
		Problems::quote_source(1, current_sentence);
		Problems::quote_text(2, billing);
		Problems::quote_wording(3, EW);
		Problems::Issue::handmade_problem(_p_(BelievedImpossible));
		Problems::issue_problem_segment(
			"In %1, you are asking for %2, but '%3' looks as if it ranges "
			"over only a single specific object, not a whole collection of "
			"objects.");
		Problems::issue_problem_end();
	}
}