[ParseTree::AdjectiveLists::] Constants and Descriptions.

To parse noun phrases in constant contexts, which specify values
either explicitly or by describing them more or less vaguely.

@h Constant values.
As we've seen, not all of the names Inform knows are literals. The following
nonterminal covers constants in general, a wider category.

The word "nothing" needs special treatment later on. Sometimes it means
the dummy value "not an object", and is genuinely a constant value;
but at other times it behaves more like a determiner, as in "if nothing
is on the table". For now, though, we treat it as a noun.

=
<s-constant-value> ::=
	<s-literal> |										==> RP[1]
	nothing	|											==> Rvalues::new_nothing_object_constant();
	<s-miscellaneous-proper-noun> |						==> RP[1]
	<s-rulebook-outcome-name> outcome |					==> RP[1]
	<s-use-option-name> option |						==> RP[1]
	verb <instance-of-verb> |							==> @<Compose verb ML@>
	<s-rule-name> response ( <response-letter> )		==> @<Compose response ML@>

@<Compose verb ML@> =
	verb_form *vf = (verb_form *) (RP[1]);
	parse_node *spec = Rvalues::from_verb_form(vf);
	ParseTree::set_text(spec, W);
	*XP = spec;

@<Compose response ML@> =
	parse_node *spec = RP[1];
	ParseTree::set_kind_of_value(spec, K_response);
	ParseTree::annotate_int(spec, response_code_ANNOT, R[2]);
	*XP = spec;

@ Screening for this saves time.

@d CONSTANT_VAL_BITMAP (RULE_MC + RULEBOOK_MC + NAMED_CONSTANT_MC + ACTIVITY_MC +
	TABLE_MC + EQUATION_MC + PHRASE_CONSTANT_MC)

@ To be a little less vague, the "miscellaneous proper nouns" are: rule
and rulebook names; action names, as nouns; relation names; instances of
kinds; activity names; table names; equation names; and names of phrases
being used as nouns for functional-programming purposes.

=
<s-miscellaneous-proper-noun> internal {
	parse_node *p = ExParser::parse_excerpt(MISCELLANEOUS_MC, W);
	if (p) {
		if ((Rvalues::is_CONSTANT_of_kind(p, K_action_name)) ||
			(Rvalues::is_CONSTANT_construction(p, CON_relation)) ||
			(Rvalues::is_CONSTANT_construction(p, CON_rule))) {
			*XP = p; return TRUE;
		}
	}
	p = ExParser::parse_excerpt(VARIABLE_MC, W);
	if (p) {
		nonlocal_variable *nlv = Lvalues::get_nonlocal_variable_if_any(p);
		if (NonlocalVariables::is_constant(nlv)) {
			*XP = p; return TRUE;
		}
	}

	if ((Vocabulary::disjunction_of_flags(W)) & CONSTANT_VAL_BITMAP) {
		p = ExParser::parse_excerpt(CONSTANT_VAL_BITMAP, W);
		if (p) { *XP = p; return TRUE; }
	}
	return FALSE;
}

@ Named constants are handled separately.

=
<s-named-constant> internal {
	parse_node *p = ExParser::parse_excerpt(VARIABLE_MC, W);
	if (p) {
		nonlocal_variable *nlv = Lvalues::get_nonlocal_variable_if_any(p);
		if (NonlocalVariables::is_constant(nlv)) {
			*XP = p; return TRUE;
		}
	}
	return FALSE;
}

@ There's actually nothing special about rulebook outcome names or use option
names; but because they are stored internally without the compulsory words
"outcome" and "option", they need nonterminals of their own.

=
<s-rulebook-outcome-name> internal {
	parse_node *p = ExParser::parse_excerpt(MISCELLANEOUS_MC, W);
	if (Rvalues::is_CONSTANT_of_kind(p, K_rulebook_outcome)) {
		*XP = p;
		return TRUE;
	}
	return FALSE;
}

<s-use-option-name> internal {
	parse_node *p = ExParser::parse_excerpt(MISCELLANEOUS_MC, W);
	if (Rvalues::is_CONSTANT_of_kind(p, K_use_option)) {
		*XP = p; return TRUE;
	}
	return FALSE;
}

<s-rule-name> internal {
	parse_node *p = ExParser::parse_excerpt(MISCELLANEOUS_MC, W);
	if (Rvalues::is_CONSTANT_construction(p, CON_rule)) {
		*XP = p;
		return TRUE;
	}
	return FALSE;
}

@ We will also sometimes need a nonterminal which can only produce table
column names, and similarly for property names. These don't fall under
"miscellaneous proper nouns" above, and they aren't in general valid
as constants.

=
<s-table-column-name> internal {
	parse_node *p = ExParser::parse_excerpt(TABLE_COLUMN_MC, W);
	if (p) { *XP = p; return TRUE; }
	return FALSE;
}

@ In order to resolve a subtle distinction of usage later on, we want not
only to parse a property name but also to record whether it was used in
the explicit syntax ("the property open" rather than "open", say).
The internal <s-property-name> uses <property-name-as-noun-phrase>
to do this.

=
<property-name-as-noun-phrase> ::=
	<definite-article> <property-name-construction> |
	<property-name-construction>

<s-property-name> internal {
	parse_node *p = ExParser::parse_excerpt(PROPERTY_MC, W);
	if (p) {
		*XP = p;
		if (<property-name-as-noun-phrase>(W))
			ParseTree::annotate_int(p, property_name_used_as_noun_ANNOT, TRUE);
		else
			ParseTree::annotate_int(p, property_name_used_as_noun_ANNOT, FALSE);
		return TRUE;
	}
	return FALSE;
}

@h Adjective lists.
"I first tried to write a story when I was about seven. It was about a dragon.
I remember nothing about it except a philological fact. My mother said nothing
about the dragon, but pointed out that one could not say "a green great dragon",
but had to say "a great green dragon". I wondered why, and still do" (Tolkien
to Auden, 1955). We are going to allow lists of adjectives such as "green great"
or "great green" in any order: although some have suggested conceptual
hierarchies for adjectives (e.g., that size always precedes material) these
are too tendentious to enforce.

The first nonterminal looks quite unnecessary; but it takes the result of
parsing an adjective list and transforms the result to make it a description
(even though there is no actual noun). Inform has to work hard at this sort
of thing, mostly because of deficiencies in English to do with words like
"scenery" and "clothing" which can't be used as count nouns even though,
logically, they should be. Inform implements them adjectivally, but this means
that "scenery" -- an adjective list with one entry -- is sometimes a
description on a par with "door" -- a common noun. In effect, "scenery"
is read as if it were "scenery thing".

=
<s-adjective-list-as-desc> ::=
	<s-adjective-list>				==> ParseTree::AdjectiveLists::add_adjlist(Descriptions::from_proposition(NULL, W), RP[1])

@ So now we test whether an excerpt is a list of adjectives; for example,
this matches

>> exciting transparent green fixed in place

as a list of four adjectives.

Perhaps surprisingly, the word "not" is allowed in such lists. Since this
looks as if it negates the verb, it ought to belong to the verb phrase, and
surely doesn't belong to the grammar of nouns and their adjectives. But there
are several problems with that analysis. Firstly, English does strange things
with the placing of "not":

>> The blue door is open and not transparent.
>> A door is usually not open.

Note that neither of these sentences places "not" adjacent to the verb, so
if we're going to say it's part of the verb phrase then this has to be a
non-contiguous sequence of words able to grab material from possibly distant
NPs. This isn't easy to go along with. Secondly, we also want to provide a
way to write the negation of an adjective. For instance,

>> exciting not transparent fixed in place

is valid. Though in this case it would be equivalent to write "opaque" in
place of "not transparent", some adjectives do not have named negations.

The grammar for adjective lists also allows the presence of an indefinite
article, less controversially, but that then leads to an interesting and
very arcane de Morgan-law-like point, affecting only a tiny number of
assertion sentences. If we write:

>> a not great green dragon

Inform considers that "not" applies only to "great"; the dragon is still
to be green. But if we write

>> not a great green dragon

then Inform requires it to be neither great nor green. It's terrible style
to write this sort of thing as a description outside of a condition like
the following:

>> if Smaug is not a great green dragon, ...

and conditions like this are parsed with "is not" as the verb and "great
green dragon" as the description, with the adjective list being just "great
green". So this awkward point about "not a..." only comes in when writing
assertion sentences like:

>> A hairless chimp is not a hairy animal.

(This was submitted as a bug report.) In assertions, Inform has to know for
definite what the truth is, so it can't afford to read this as saying that
the chimp is either not hairy or not an animal.

=
<s-adjective-list> ::=
	not <indefinite-article> <s-adjective-list-unarticled> |	==> 0; *XP = ParseTree::AdjectiveLists::make_adjlist(ParseTree::AdjectiveLists::negate_adjlist(RP[2]), W)
	<indefinite-article> <s-adjective-list-unarticled> |		==> 0; *XP = ParseTree::AdjectiveLists::make_adjlist(RP[2], W)
	<s-adjective-list-unarticled>								==> 0; *XP = ParseTree::AdjectiveLists::make_adjlist(RP[1], W)

<s-adjective-list-unarticled> ::=
	not <s-adjective> |											==> 0; *XP = ParseTree::AdjectiveLists::negate_adjlist(RP[1])
	<s-adjective> |												==> 0; *XP = RP[1]
	not <s-adjective> <s-adjective-list-unarticled> |			==> 0; *XP = ParseTree::AdjectiveLists::join_adjlist(ParseTree::AdjectiveLists::negate_adjlist(RP[1]), RP[2])
	<s-adjective> <s-adjective-list-unarticled>					==> 0; *XP = ParseTree::AdjectiveLists::join_adjlist(RP[1], RP[2])

@ That reduces us to an internal nonterminal, which matches the longest
possible adjective name it can see.

=
<s-adjective> internal ? {
	parse_node *p = ExParser::parse_excerpt_maximal(ADJECTIVE_MC, W);
	if (p) {
		adjective_usage *ale = AdjectiveUsages::new(
			RETRIEVE_POINTER_adjectival_phrase(ExcerptMeanings::data(ParseTree::get_meaning(p))),
				TRUE);
		*XP = Descriptions::from_proposition(NULL, W);
		Descriptions::add_to_adjective_list(ale, *XP);
		int sc = ParseTree::get_score(p);
		if (sc == 0) internal_error("Length-scored maximal parse with length 0");
		return Wordings::first_wn(W) + sc - 1;
	}
	return FALSE;
}

@ =
parse_node *ParseTree::AdjectiveLists::join_adjlist(parse_node *A, parse_node *B) {
	adjective_usage *au;
	pcalc_prop *au_prop = NULL;
	LOOP_THROUGH_ADJECTIVE_LIST(au, au_prop, B)
		Descriptions::add_to_adjective_list(AdjectiveUsages::copy(au), A);
	return A;
}

parse_node *ParseTree::AdjectiveLists::join_adjlist_w(parse_node *A, parse_node *B) {
	adjective_usage *au;
	pcalc_prop *au_prop = NULL;
	LOOP_THROUGH_ADJECTIVE_LIST(au, au_prop, B)
		Descriptions::add_to_adjective_list_w(AdjectiveUsages::copy(au), A);
	return A;
}

parse_node *ParseTree::AdjectiveLists::make_adjlist(parse_node *A, wording W) {
	ParseTree::set_text(A, W);
	return A;
}

parse_node *ParseTree::AdjectiveLists::negate_adjlist(parse_node *A) {
	adjective_usage *au;
	pcalc_prop *au_prop = NULL;
	LOOP_THROUGH_ADJECTIVE_LIST(au, au_prop, A)
		AdjectiveUsages::flip_parity(au);
	return A;
}

@ =
parse_node *ParseTree::AdjectiveLists::add_adjlist(parse_node *spec, parse_node *adjlist) {
	if (adjlist) {
		instance *I = Rvalues::to_object_instance(spec);
		if (I) spec = Descriptions::from_instance(I, ParseTree::get_text(spec));
		ParseTree::AdjectiveLists::join_adjlist(spec, adjlist);
	}
	return spec;
}

parse_node *ParseTree::AdjectiveLists::add_adjlist_w(parse_node *spec, parse_node *adjlist) {
	if (adjlist) {
		instance *I = Rvalues::to_object_instance(spec);
		if (I) spec = Descriptions::from_instance(I, ParseTree::get_text(spec));
		ParseTree::AdjectiveLists::join_adjlist_w(spec, adjlist);
	}
	return spec;
}

@ And this makes a more semantic check:

=
int ParseTree::AdjectiveLists::adjlist_applies_to_kind(parse_node *A, kind *K) {
	adjective_usage *au;
	pcalc_prop *au_prop = NULL;
	LOOP_THROUGH_ADJECTIVE_LIST(au, au_prop, A) {
		adjectival_phrase *aph = AdjectiveUsages::get_aph(au);
		if (Adjectives::Meanings::applicable_to(aph, K) == FALSE) return FALSE;
	}
	return TRUE;
}

@ The following global is needed only to pass a parameter from one Preform token
to another one parsed immediately after it has been matched; it has no
significance the rest of the time.

=
kind *s_adj_domain = NULL;

@ This prevents doubled issue of the same problem message.

=
parse_node *PM_DefiniteCommonNoun_issued_at = NULL;
parse_node *PM_SpecificCalling_issued_at = NULL;
parse_node *PM_PastSubordinate_issued_at = NULL;

@ When they appear in descriptions, these adjectives serve as "qualifiers":
they qualify their nouns. For example, "open door" consists of "open",
a qualifier, followed by "door", a noun.

Not every value known to Inform can be qualified as a noun: in fact, very few
can be. This prevents us from writing "even 3", that is, the number 3 as
a noun qualified by the adjective "even"; doctrinally, Inform takes the
line that adjectives applied to values like 3 will never vary in their
applicability -- 3 is always odd -- so that it makes no sense to test for
them with conditions like

>> if N is an even 3, ...

=
<s-qualifiable-noun> ::=
	<k-kind> |								==> Specifications::from_kind(RP[1]); s_adj_domain = RP[1];
	<s-instance-name>						==> RP[1]; s_adj_domain = NULL;

<s-qualifiable-common-noun> ::=
	<k-kind>								==> Specifications::from_kind(RP[1]); s_adj_domain = RP[1];

<s-qualifiable-proper-noun> ::=
	<s-instance-name>						==> RP[1]; s_adj_domain = NULL;

@ <s-instance-name> parses text exactly as if it were <instance-of-object>, but
is just a little faster written as an internal like this.

=
<s-instance-name> internal {
	parse_node *p = ExParser::parse_excerpt(NOUN_MC, W);
	if (p) {
		noun *nt = Nouns::disambiguate(p, MAX_NOUN_PRIORITY);
		if ((nt) && (Nouns::priority(nt) == LOW_NOUN_PRIORITY)) {
			instance *I = Rvalues::to_object_instance(
				RETRIEVE_POINTER_parse_node(Nouns::tag_holder(nt)));
			*XP = Rvalues::from_instance(I); return TRUE;
		}
	}
	return FALSE;
}

@ The following is used only in combination with a qualifiable noun: it
simply provides a filter on <s-adjective-list> to require that each
adjective listed must be one which applies to the noun. For example,
"empty room" won't be parsed as "empty" qualifying "room" because
(perhaps curiously) the Standard Rules don't define "empty" for rooms;
whereas "empty rulebook" will work.

=
<s-applicable-adjective-list> ::=
	<s-adjective-list>	==> RP[1]; if ((s_adj_domain) && (ParseTree::AdjectiveLists::adjlist_applies_to_kind(RP[1], s_adj_domain) == FALSE)) return FALSE;

@h Descriptions.
In most programming languages, commands are like imperative verbs, but their
noun phrases are specific. |print X|, say, prints an unambiguously determined
quantity |X|. Sometimes wildcards are allowed, as when the Unix shell allows
|ls *.txt| to list all text files in the current directory. Inform goes
further, and -- in some circumstances at least -- permits the |X| to be a more
or less vague description of a collection of values, such that only at run-time
can it be determined what values |X| refers to.

It might look as if a description is a generalisation of a value: that is,
every value is a description. In fact, that isn't true, because the noun part
of a description has to be "qualifiable" in the sense above: so "100", for
instance, is a value but not a description.

Grammatically, a description is a sequence of the following five elements, some
of which are optional:

(a) {\it specifier}, which will be a determiner and/or an article (optional);

(b) {\it qualifier}, which for Inform means adjectives of the various kinds
described above (optional);

(c) {\it qualifiable noun} (sometimes optional, sometimes compulsory); and

(d) {\it subordinate clause}, such as "in ..." or "which are on ..."
(optional).

For the most part the sequence must be (a), (b), (c), (d), as in:

>> six of the / open / containers / in the Attic

but the composite words made up from quantifiers and kinds -- something,
anywhere, everybody, and such -- force us to make an exception to this:

>> something / open / in the Attic

which takes the sequence (a) and (c), (b), (d). We will call words like
"something" and "everywhere" specifying nouns, since they are both
noun and specifier in one.

Simpler readings beat more complicated ones. Thus we won't match a
subordinate clause if there's a way to read the text which doesn't need to;
and similarly for specifiers.

In cases of ambiguity, the earliest split wins: that is, the one
maximising the length of the noun. This means that if the source text
actually names a dark room, the text "dark room" will not be confused
with "dark (i.e., the property) room (i.e, the kind)", since that
splits later.

In the grammar for <s-description>, the noun is compulsory.

=
<s-description> ::=
	<s-description-uncomposite-inner> |								==> RP[1]
	<s-np-with-relative-clause>										==> RP[1]

<s-description-uncomposite> ::=
	<s-description-uncomposite-inner>								==> RP[1]

<s-description-uncomposite-inner> ::=
	<s-description-uncalled> ( called <s-calling-name> ) |			==> @<Glue on the calling ML@>
	<s-description-uncalled>										==> RP[1]

<s-description-uncalled> ::=
	<s-specifier> <s-description-unspecified> |						==> @<Glue on the quantification ML@>
	<s-specifying-noun> |											==> RP[1]
	<s-specifying-noun> <s-adjective-list> |						==> ParseTree::AdjectiveLists::add_adjlist_w(RP[1], RP[2])
	<if-trying-omission-permitted> <definite-article> <s-common-description-unspecified> |	==> RP[3]
	^<if-trying-omission-permitted> ^<if-multiplicitous> <definite-article> <s-common-description-unspecified> |	==> @<Issue PM_DefiniteCommonNoun problem@>
	<definite-article> <s-proper-description-unspecified> |			==> RP[2]
	<indefinite-article> <s-description-unspecified> |				==> RP[2]
	<s-description-unspecified>										==> RP[1]

<s-description-unspecified> ::=
	<s-qualifiable-noun> |											==> RP[1]
	<s-applicable-adjective-list> <s-qualifiable-noun>				==> ParseTree::AdjectiveLists::add_adjlist(RP[2], RP[1])

<s-common-description-unspecified> ::=
	<s-qualifiable-common-noun> |									==> RP[1]
	<s-applicable-adjective-list> <s-qualifiable-common-noun>		==> ParseTree::AdjectiveLists::add_adjlist(RP[2], RP[1])

<s-proper-description-unspecified> ::=
	<s-qualifiable-proper-noun> |									==> RP[1]
	<s-applicable-adjective-list> <s-qualifiable-proper-noun>		==> ParseTree::AdjectiveLists::add_adjlist(RP[2], RP[1])

<if-trying-omission-permitted> internal 0 {
	#ifdef IF_MODULE
	if (permit_trying_omission) return TRUE;
	#endif
	return FALSE;
}

<if-multiplicitous> internal 0 {
	if (<s-value-uncached>->multiplicitous) return TRUE;
	return FALSE;
}

@ The grammar for <s-description-nounless> is almost exactly the same
except that the noun is optional. The only difference is right at the bottom.

=
<s-description-nounless> ::=
	<s-description-nounless-uncomposite> |							==> RP[1]
	<s-np-with-relative-clause>										==> RP[1]

<s-description-nounless-uncomposite> ::=
	<s-description-nounless-uncalled> ( called <s-calling-name> ) |	==> @<Glue on the calling ML@>
	<s-description-nounless-uncalled>								==> RP[1]

<s-description-nounless-uncalled> ::=
	<s-specifier> <s-description-nounless-unspecified> |			==> @<Glue on the quantification ML@>
	<s-specifying-noun> |											==> RP[1]
	<s-specifying-noun> <s-adjective-list> |						==> ParseTree::AdjectiveLists::add_adjlist_w(RP[1], RP[2])
	<if-trying-omission-permitted> <definite-article> <s-common-description-unspecified> |	==> RP[3]
	^<if-trying-omission-permitted> ^<if-multiplicitous> <definite-article> <s-common-description-unspecified> |	==> @<Issue PM_DefiniteCommonNoun problem@>
	<indefinite-article> <s-description-nounless-unspecified> |		==> RP[2]
	<definite-article> <s-proper-description-unspecified> |			==> RP[2]
	<s-description-nounless-unspecified>							==> RP[1]

<s-description-nounless-unspecified> ::=
	<s-qualifiable-noun> |											==> RP[1]
	<s-applicable-adjective-list> <s-qualifiable-noun> |			==> ParseTree::AdjectiveLists::add_adjlist(RP[2], RP[1])
	<s-adjective-list>												==> ParseTree::AdjectiveLists::add_adjlist(Descriptions::from_proposition(NULL, W), RP[1])

@<Glue on the calling ML@> =
	parse_node *p = RP[1];
	parse_node *c = RP[2];

	if (ParseTree::is(p, CONSTANT_NT)) {
		if (PM_SpecificCalling_issued_at != current_sentence) {
			PM_SpecificCalling_issued_at = current_sentence;
			Problems::Issue::sentence_problem(_p_(PM_SpecificCalling),
				"a 'called' name can only be given to something "
				"which is described vaguely",
				"and can't be given to a definite object or value. "
				"So 'if a thing (called the gadget) is carried' is "
				"allowed, but 'if the X-Ray Zapper (called the gadget) "
				"is carried' isn't allowed - if it's the X-Ray Zapper, "
				"then call it that.");
		}
	} else {
		if (Frames::current_stack_frame()) {
			wording C = ParseTree::get_text(c);
			Descriptions::attach_calling(p, C);
			kind *K = Specifications::to_kind(p);
			LocalVariables::ensure_called_local(C, K);
		}
	}
	*XP = p;

@ Determiners make sense in the context of a common noun, e.g., "three doors",
but not usually for proper nouns ("all 5"). But we allow existence in the
context of a proper noun, as in "some tea", because it may be confusion of
"some" the determiner with "some" the indefinite article.

@<Glue on the quantification ML@> =
	parse_node *p = RP[2];
	parse_node *annotation = RP[1];
	quantifier *quant = ParseTree::get_quant(annotation);
	if (quant) {
		if (Specifications::is_description(p)) {
			Descriptions::quantify(p,
				quant, ParseTree::int_annotation(annotation, quantification_parameter_ANNOT));
		} else if (!((quant == exists_quantifier) && (ParseTree::is(p, CONSTANT_NT))))
			p = Specifications::new_UNKNOWN(W);
	}
	*XP = p;

@<Issue PM_DefiniteCommonNoun problem@> =
	*XP = RP[4];
	if ((PM_DefiniteCommonNoun_issued_at != current_sentence) ||
		(PM_DefiniteCommonNoun_issued_at == NULL)) {
		PM_DefiniteCommonNoun_issued_at = current_sentence;
		Problems::quote_source(1, current_sentence);
		Problems::quote_wording(2, W);
		Problems::Issue::handmade_problem(_p_(PM_DefiniteCommonNoun));
		Problems::issue_problem_segment(
			"In %1, I'm not able to understand what specific thing is meant "
			"by the phrase '%2'. You use the definite article 'the', which "
			"suggests you have a particular thing in mind, but then you go "
			"on to refer to a kind rather than something definite. Quite "
			"likely a human reading this sentence would find it obvious what "
			"you mean, but I don't. %P"
			"This often arises when writing something like: 'Instead of "
			"opening a door when the door is closed' - where clearly a human "
			"would understand that 'the door' refers to the same one in 'a "
			"door' earlier. I can make sense of this only if you help: for "
			"example, 'Instead of opening a door (called the portal) when "
			"the portal is closed' would work. So would 'Instead of opening "
			"a closed door'; or 'Instead of opening a door which is closed'. "
			"All of these alternatives help me by making clear that only one "
			"door is being talked about.");
		Problems::issue_problem_end();
	}

@ This simply wraps up a calling name into S-grammar form.

=
<s-calling-name> ::=
	<article> ... |		==> ParseTree::new_with_words(UNKNOWN_NT, WR[1])
	...					==> ParseTree::new_with_words(UNKNOWN_NT, WR[1])

@ The following is written as an internal, voracious nonterminal for speed.
It matches text like

>> all
>> six of the
>> most

and so on. Note that an article can follow a determiner, as in "six of the
people", where "six of" is a determiner. At this point we don't need to
notice whether the article is definite or not, and we're similarly turning a
blind eye to singular vs plural.

=
<s-specifier> internal ? {
	int which_N = -1; quantifier *quantifier_used = NULL;
	int x1 = Quantifiers::parse_against_text(W, &which_N, &quantifier_used);
	if (x1 >= 0) {
		if ((x1<Wordings::last_wn(W)) && (Preform::test_word(x1, <article>))) x1++;
		parse_node *qp = Specifications::new_UNKNOWN(Wordings::up_to(W, x1-1));
		ParseTree::set_quant(qp, quantifier_used);
		ParseTree::annotate_int(qp, quantification_parameter_ANNOT, which_N);
		*XP = qp;
		return x1-1;
	}
	return 0;
}

@ Similarly, this nonterminal matches specifying nouns like "somebody" or
"everywhere". Doctrinally, "something" is not taken to refer explicitly
to the kind "thing", whereas "somebody" does refer to people and
"everywhere" to places: English is slippery on this.

=
<s-specifying-noun> internal ? {
	wording DW = Wordings::first_word(W);
	quantifier *quantifier_used = NULL; kind *some_kind = NULL;
	Plugins::Call::parse_composite_NQs(&W, &DW, &quantifier_used, &some_kind);
	if (some_kind) {
		parse_node *p = Descriptions::from_kind(some_kind, TRUE);
		if (quantifier_used)
			Descriptions::quantify(p, quantifier_used, -1);
		*XP = p;
		return Wordings::first_wn(W) - 1;
	}
	return 0;
}