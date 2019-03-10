[PL::Scenes::] Scenes.

Scenes are periods of time during play: at any given moment, several
may be going on, or none. They are started and stopped when certain conditions
are met, or by virtue of having been anchored together.

@h Definitions.

@ Scenes are gated intervals of time, but there are more than two gates: for
while there is only one past, there are many possible futures. These gates
are called "ends" in the code below, and are numbered end 0 (the beginning),
end 1 (the usual end), and then any named ends ("ends badly" or "ends
triumphantly", for instance, might be ends 2 and 3). Each end has a condition
which can cause it, or can be "anchored" to any number of ends of other
scenes -- to express which, the |scene_connector| structure is used.

@d MAX_SCENE_ENDS 32 /* this must exceed 31 */

=
typedef struct scene_connector {
	struct scene *connect_to; /* scene connected to */
	int end; /* end number: see above */
	struct scene_connector *next; /* next in list of connectors for a scene end */
	struct parse_node *where_said; /* where this linkage was specified in source */
} scene_connector;

typedef struct scene {
	struct instance *as_instance; /* the constant for the name of the scene */
	int once_only; /* cannot repeat during play */
	int start_of_play; /* if begins when play begins */
	int marker; /* used to detect potentially infinite recursion when scene changes occur */
	int no_ends; /* how many ends the scene has */
	struct wording end_names[MAX_SCENE_ENDS]; /* for ends 2, 3, ...: e.g. "badly" */
	struct rulebook *end_rulebook[MAX_SCENE_ENDS]; /* rules to apply then */
	struct parse_node *anchor_condition[MAX_SCENE_ENDS];
	struct scene_connector *anchor_scene[MAX_SCENE_ENDS]; /* linked list */
	int indexed; /* temporary storage during Scenes index creation */
	struct parse_node *scene_declared_at; /* where defined */
	struct parse_node *anchor_condition_set[MAX_SCENE_ENDS]; /* where set */
	MEMORY_MANAGEMENT
} scene;

@ The following either/or property needs some compiler support:

=
property *P_recurring = NULL;

@ And so does the one special scene:

=
scene *SC_entire_game = NULL;

@ Scenes are similarly numbered and stored in their own kind:
actually, they are for practical purposes a built-in enumeration kind.

= (early code)
kind *K_scene = NULL;

@ At run-time, we need to store information about the current state of each
scene: whether it is currently playing or not, when the last change occurred,
and so on. This data is stored in I6 arrays as follows:

First, each scene has a unique ID number, used as an index |X| to these arrays.
This ID number is what is stored as an I6 value for the kind of value |scene|,
and it agrees with the allocation ID for the I7 scene structure.

|scene_status-->X| is 0 if the scene is not playing, but may do so in future;
1 if the scene is playing; or 2 if the scene is not playing and will never
play again.

|scene_started-->X| is the value of |the_time| when the scene last started,
or 0 if it has never started.

|scene_ended-->X| is the value of |the_time| when the scene last ended,
or 0 if it has never ended. (The "starting" end does not count as ending
for this purpose.)

|scene_endings-->X| is a bitmap recording which ends have been used,
including bit 1 which records whether the scene has started.

|scene_latest_ending-->X| holds the end number of the most recent ending
(or 0 if the scene has never ended).

@h Plugin calls.

=
void PL::Scenes::start(void) {
	PLUGIN_REGISTER(PLUGIN_NEW_PROPERTY_NOTIFY, PL::Scenes::scenes_new_property_notify);
	PLUGIN_REGISTER(PLUGIN_NEW_INSTANCE_NOTIFY, PL::Scenes::scenes_new_named_instance_notify);
	PLUGIN_REGISTER(PLUGIN_NEW_BASE_KIND_NOTIFY, PL::Scenes::scenes_new_base_kind_notify);
}

@ To detect "scene" and "recurring":

=
int PL::Scenes::scenes_new_base_kind_notify(kind *new_base, text_stream *name, wording W) {
	if (Str::eq_wide_string(name, L"SCENE_TY")) {
		K_scene = new_base; return TRUE;
	}
	return FALSE;
}

@ This is a property name to do with scenes which Inform provides special
support for; it recognises the English name when it is defined by the
Standard Rules. (So there is no need to translate this to other languages.)

=
<notable-scene-properties> ::=
	recurring

@ =
int PL::Scenes::scenes_new_property_notify(property *prn) {
	if (<notable-scene-properties>(prn->name)) {
		switch (<<r>>) {
			case 0: P_recurring = prn; break;
		}
	}
	return FALSE;
}

@ Scene structures are automatically created whenever a new instance of the
kind "scene" is created, and this is where that happens.

=
int PL::Scenes::scenes_new_named_instance_notify(instance *I) {
	if ((K_scene) && (Kinds::Compare::eq(Instances::to_kind(I), K_scene))) {
		PL::Scenes::new_scene(I);
		return TRUE;
	}
	return FALSE;
}

@h Scene structures.
As we've seen, the following is called whenever a new instance of "scene"
is created:

=
void PL::Scenes::new_scene(instance *I) {
	scene *sc = CREATE(scene);
	@<Connect the scene structure to the instance@>;
	@<Initialise the scene structure@>;
}

@ A scene begins with two ends, 0 (beginning) and 1 (standard end).

@<Initialise the scene structure@> =
	sc->once_only = TRUE;
	sc->indexed = FALSE;
	sc->no_ends = 2;
	sc->start_of_play = FALSE;
	sc->scene_declared_at = current_sentence;
	int end;
	for (end=0; end<sc->no_ends; end++) {
		sc->anchor_condition[end] = NULL;
		sc->anchor_scene[end] = NULL;
		PL::Scenes::new_scene_rulebook(sc, end);
	}

@ This is a scene name which Inform provides special support for; it recognises
the English name when it is defined by the Standard Rules. (So there is no need
to translate this to other languages.)

=
<notable-scenes> ::=
	entire game

@<Connect the scene structure to the instance@> =
	sc->as_instance = I;
	Instances::set_connection(I, STORE_POINTER_scene(sc));
	wording W = Instances::get_name(I, FALSE);
	if (<notable-scenes>(W)) SC_entire_game = sc;

@ So we sometimes want to be able to get from an instance to its scene structure.

=
scene *PL::Scenes::from_named_constant(instance *I) {
	if (K_scene == NULL) return NULL;
	kind *K = Instances::to_kind(I);
	if (Kinds::Compare::eq(K, K_scene))
		return RETRIEVE_POINTER_scene(Instances::get_connection(I));
	return NULL;
}

wording PL::Scenes::get_name(scene *sc) {
	return Instances::get_name(sc->as_instance, FALSE);
}

@h Creating and parsing ends.

=
int PL::Scenes::parse_scene_end_name(scene *sc, wording EW, int create) {
	int i;
	for (i=2; i<sc->no_ends; i++)
		if (Wordings::match(EW, sc->end_names[i]))
			return i;
	if (create) {
		int end = sc->no_ends++;
		int max = 31;
		if (VirtualMachines::is_16_bit()) max = 15;
		if (end >= max) @<Issue a too-many-ends problem message@>
		else {
			sc->end_names[end] = EW;
			PL::Scenes::new_scene_rulebook(sc, end);
			return end;
		}
	}
	return -1;
}

@<Issue a too-many-ends problem message@> =
	Problems::Issue::sentence_problem(_p_(PM_ScenesWithTooManyEnds),
		"this scene now has too many different ways to end",
		"and will need to be simplified. (We can have up to 15 ends to a scene "
		"if the project format is for the Z-machine, and 31 for Glulx: see the "
		"project's Settings panel. Note that the ordinary 'begins' and 'ends' "
		"count as two of those, so you can only name up to 13 or 29 more specific "
		"ways for the scene to end.)");

@h Scene end rulebooks.

=
void PL::Scenes::new_scene_rulebook(scene *sc, int end) {
	wording RW = EMPTY_WORDING, AW = EMPTY_WORDING;
	@<Compose a name and alternate name for the new scene end rulebook@>;

	rulebook *rb = Rulebooks::new_automatic(RW, K_action_name,
			NO_OUTCOME, FALSE, FALSE, FALSE, NULL, NULL);
	Rulebooks::set_alt_name(rb, AW);
	sc->end_rulebook[end] = rb;

	if (end >= 2) @<Define phrases detecting whether or not the scene has ended this way@>;
}

@ For example, if a scene is called "Banquet Entertainment" and it ends
"merrily", then the rulebook has two names: "when Banquet Entertainment
ends merrily" and "when the Banquet Entertainment ends merrily".

@<Compose a name and alternate name for the new scene end rulebook@> =
	wording NW = Instances::get_name(sc->as_instance, FALSE);

	feed_t id = Feeds::begin();
	Feeds::feed_text_expanding_strings(L"when");
	Feeds::feed_wording(NW);
	Feeds::feed_text_expanding_strings((end==0)?L"begins":L"ends");
	if (end >= 2) Feeds::feed_wording(sc->end_names[end]);
	RW = Feeds::end(id);

	id = Feeds::begin();
	Feeds::feed_text_expanding_strings(L"when the");
	NW = Instances::get_name(sc->as_instance, FALSE);
	Feeds::feed_wording(NW);
	Feeds::feed_text_expanding_strings((end==0)?L"begins":L"ends");
	if (end >= 2) Feeds::feed_wording(sc->end_names[end]);
	AW = Feeds::end(id);

@<Define phrases detecting whether or not the scene has ended this way@> =
	wording NW = Instances::get_name(sc->as_instance, FALSE);

	TEMPORARY_TEXT(i6_code);
	feed_t id = Feeds::begin();
	Feeds::feed_text_expanding_strings(L"To decide if (S - ");
	Feeds::feed_wording(NW);
	Feeds::feed_text_expanding_strings(L") ended ");
	Feeds::feed_wording(sc->end_names[end]);
	Sentences::make_node(Feeds::end(id), ':');

	id = Feeds::begin();
	Str::clear(i6_code);
	WRITE_TO(i6_code, " (- (scene_latest_ending-->%d == %d) -) ",
		sc->allocation_id, end);
	Feeds::feed_stream_expanding_strings(i6_code);
	Sentences::make_node(Feeds::end(id), '.');

	id = Feeds::begin();
	Feeds::feed_text_expanding_strings(L"To decide if (S - ");
	Feeds::feed_wording(NW);
	Feeds::feed_text_expanding_strings(L") did not end ");
	Feeds::feed_wording(sc->end_names[end]);
	Sentences::make_node(Feeds::end(id), ':');

	id = Feeds::begin();
	Str::clear(i6_code);
	WRITE_TO(i6_code, " (- (scene_latest_ending-->%d ~= 0 or %d) -) ",
		sc->allocation_id, end);
	Feeds::feed_stream_expanding_strings(i6_code);
	Sentences::make_node(Feeds::end(id), '.');
	Sentences::RuleSubtrees::register_recently_lexed_phrases();
	DISCARD_TEXT(i6_code);

@h Anchors.
These are joins between the endings of different scenes, and there are two
assertion sentences to create them. This handles the special meaning "X
begins when...".

=
int PL::Scenes::begins_when_SMF(int task, parse_node *V, wording *NPs) {
	wording SW = (NPs)?(NPs[0]):EMPTY_WORDING;
	wording OW = (NPs)?(NPs[1]):EMPTY_WORDING;
	switch (task) { /* "The Ballroom Scene begins when..." */
		case ACCEPT_SMFT:
			ParseTree::annotate_int(V, verb_id_ANNOT, SPECIAL_MEANING_VB);
			<nounphrase>(OW);
			parse_node *O = <<rp>>;
			<nounphrase>(SW);
			V->next = <<rp>>;
			V->next->next = O;
			return TRUE;
		case TRAVERSE1_SMFT:
			PL::Scenes::new_scene_anchor(V, 1, 0);
			break;
		case TRAVERSE2_SMFT:
			PL::Scenes::new_scene_anchor(V, 2, 0);
			break;
	}
	return FALSE;
}

@ This handles the special meaning "X ends when...", which sometimes takes
two noun phrases and sometimes three.

=
int PL::Scenes::ends_when_SMF(int task, parse_node *V, wording *NPs) {
	wording SW = (NPs)?(NPs[0]):EMPTY_WORDING;
	wording OW = (NPs)?(NPs[1]):EMPTY_WORDING;
	wording O2W = (NPs)?(NPs[2]):EMPTY_WORDING;
	switch (task) { /* "The Ballroom Scene ends when..." */
		case ACCEPT_SMFT:
			ParseTree::annotate_int(V, verb_id_ANNOT, SPECIAL_MEANING_VB);
			<nounphrase>(OW);
			parse_node *O = <<rp>>;
			<nounphrase>(SW);
			V->next = <<rp>>;
			if (Wordings::nonempty(O2W)) {
				<nounphrase>(O2W);
				V->next->next = <<rp>>;
				V->next->next->next = O;
			} else {
				V->next->next = O;
			}
			return TRUE;
		case TRAVERSE1_SMFT:
			PL::Scenes::new_scene_anchor(V, 1, 1);
			break;
		case TRAVERSE2_SMFT:
			PL::Scenes::new_scene_anchor(V, 2, 1);
			break;
	}
	return FALSE;
}

@ =
scene *scene_end_of_which_parsed = NULL;

@ Sentences giving scene boundaries have a simple form:

>> The Ballroom Dance begins when the Hallway Greeting ends.
>> The Ballroom Dance ends dramatically when we have dropped the glass slipper.

The sentence has a subject noun phrase (here "Ballroom Dance") and an
object NP: "the Hallway Greeting ends" or "we have dropped the glass
slipper" are the object NPs here. We will call the optional part,
"dramatically" in this example, the adverb, though it doesn't actually
have to be worded as one.

The subject is simple: it has to be a scene name.

=
<scene-ends-sentence-subject> ::=
	<scene-name> |					==> TRUE; *XP = RP[1]
	...								==> @<Issue PM_ScenesOnly problem@>

@<Issue PM_ScenesOnly problem@> =
	*X = FALSE;
	Problems::Issue::sentence_problem(_p_(PM_ScenesOnly),
		"'begins when' and 'ends when' can only be applied to scenes",
		"which have already been defined with a sentence like 'The final "
		"confrontation is a scene.'");

@ The adverb, if present, always matches, since the scene end is created
if it doesn't already exist:

=
<scene-ends-sentence-adverb> ::=
	<scene-end-name-creating>				==> R[1]

@ The following is elementary enough, but we want to be careful because
there are possible ambiguities: the condition might contain the word "ends"
in a different context, for instance, and could still be valid in that case.

=
<scene-ends-sentence-object> ::=
	<text-including-a-calling> |			==> @<Issue PM_ScenesDisallowCalled problem@>
	play begins |							==> -1
	play ends |								==> @<Issue PM_ScenesNotPlay problem@>
	<scene-name> begins |					==> 0; <<scene:named>> = RP[1]
	<scene-name> ends |						==> 1; <<scene:named>> = RP[1]
	<scene-name> ends <scene-end-name> |	==> R[2]; <<scene:named>> = RP[1]
	<scene-name> ends ... |					==> @<Issue PM_ScenesUnknownEnd problem@>
	<s-condition>						==> -2; <<parse_node:cond>> = RP[1]

@<Issue PM_ScenesDisallowCalled problem@> =
	*X = -1;
	Problems::Issue::sentence_problem(_p_(PM_ScenesDisallowCalled),
		"'(called ...)' is not allowed within conditions for a scene to begin or end",
		"since calling gives only a temporary name to something, for the purpose "
		"of further instructions which immediately follow in. Here there is no room "
		"for such further instructions, so a calling would have no effect. Anyway - "
		"not allowed!");

@<Issue PM_ScenesNotPlay problem@> =
	*X = -1;
	Problems::Issue::sentence_problem(_p_(PM_ScenesNotPlay),
		"'play' is not really a scene",
		"so although you can write '... when play begins' you cannot write '... "
		"when play ends'. But there's no need to do so, anyway. When play ends, "
		"all scenes end.");

@<Issue PM_ScenesUnknownEnd problem@> =
	*X = -1;
	Problems::Issue::sentence_problem(_p_(PM_ScenesUnknownEnd),
		"that's not one of the known ends for that scene",
		"which must be declared with something like 'Confrontation ends happily "
		"when...' or 'Confrontation ends tragically when...'.");

@ Where the following filters instance names to allow those of scenes only,
and also internally converts the result:

=
<scene-name> ::=
	<definite-article> <scene-name-unarticled> |	==> R[2]; *XP = RP[2]
	<scene-name-unarticled>							==> R[1]; *XP = RP[1]

<scene-name-unarticled> ::=
	<instance-of-non-object>	==> @<Convert instance result to scene result, if possible@>

@<Convert instance result to scene result, if possible@> =
	instance *I = <<rp>>;
	if (Instances::of_kind(I, K_scene) == FALSE) return FALSE;
	*XP = PL::Scenes::from_named_constant(I);
	scene_end_of_which_parsed = *XP;

@ Lastly, scene end names are parsed by these internals. They are identical
except that the creating case will create a new end if need be so that it
never fails.

=
<scene-end-name> internal {
	int end = PL::Scenes::parse_scene_end_name(scene_end_of_which_parsed, W, FALSE);
	if (end < 0) return FALSE;
	*X = end; return TRUE;
}

<scene-end-name-creating> internal {
	*X = PL::Scenes::parse_scene_end_name(scene_end_of_which_parsed, W, TRUE);
	return TRUE;
}

@ In a sentence like

>> The Ballroom Dance begins when the Hallway Greeting ends.

we will call "the Ballroom Dance begins" this end, and "the Hallway Greeting
ends" the other end.

=
void PL::Scenes::new_scene_anchor(parse_node *p, int phase, int given_end) {
	scene *this_scene = NULL; /* scene whose end is being caused: must be set */
	int end = -1; /* end which is being anchored: must be set */

	scene *other_scene = NULL; /* Either: another scene whose end it connects to */
	int other_end = -1; /* and which end it is... */
	parse_node *external_condition = NULL; /* Or: an absolute condition... */
	int when_play_begins = FALSE; /* Or: anchor to the start of play */

	wording SW = ParseTree::get_text(p->next); /* scene name */
	wording EW = EMPTY_WORDING; /* end name, if any */
	wording CW = EMPTY_WORDING; /* condition for end to occur */
	if (p->next->next->next) {
		EW = ParseTree::get_text(p->next->next);
		CW = ParseTree::get_text(p->next->next->next);
	} else {
		CW = ParseTree::get_text(p->next->next);
	}

	@<Parse the scene and end to be anchored@>;
	if ((this_scene == NULL) || (end < 0)) internal_error("scene misparsed");

	if (phase == 2) {
		@<Parse which form of anchor we have@>;
		if ((this_scene == SC_entire_game) && (external_condition == NULL)) {
			Problems::Issue::sentence_problem(_p_(PM_EntireGameHardwired),
				"the special 'Entire Game' scene cannot have its start or end modified",
				"because it is a built-in scene designed to be going on whenever there "
				"is play going on in the story.");
		} else if (when_play_begins)
			@<Connect this end to the start of play@>
		else if (other_scene)
			@<Connect this end to an end of another scene@>
		else if (external_condition)
			@<Make this an external scene end condition@>
		else internal_error("failed to obtain an anchor condition");
	}
}

@<Connect this end to the start of play@> =
	this_scene->start_of_play = TRUE;

@<Make this an external scene end condition@> =
	if (this_scene->anchor_condition[end])
		Problems::Issue::sentence_problem(_p_(PM_ScenesOversetEnd),
			"you have already told me a condition for when that happens",
			"and although a scene can be linked to the beginning or ending "
			"of any number of other scenes, it can only have a single "
			"condition such as 'when the player is in the Dining Car' "
			"to trigger it from outside the scene machinery.");

	this_scene->anchor_condition[end] = external_condition;
	this_scene->anchor_condition_set[end] = current_sentence;

@<Connect this end to an end of another scene@> =
	scene_connector *scon = CREATE(scene_connector);
	scon->connect_to = other_scene;
	scon->end = other_end;
	scon->where_said = current_sentence;
	scon->next = this_scene->anchor_scene[end];
	this_scene->anchor_scene[end] = scon;

@<Parse the scene and end to be anchored@> =
	<scene-ends-sentence-subject>(SW);
	if (<<r>> == FALSE) return;
	this_scene = <<rp>>;
	scene_end_of_which_parsed = this_scene;

	if (Wordings::nonempty(EW)) {
		<scene-ends-sentence-adverb>(EW);
		end = <<r>>;
	} else end = given_end;
	if (end < 0) return; /* to recover from any parsing Problems */

@<Parse which form of anchor we have@> =
	if (<scene-ends-sentence-object>(CW)) {
		int end = <<r>>;
		switch (end) {
			case -2: external_condition = <<parse_node:cond>>; break;
			case -1: when_play_begins = TRUE; break;
			default: other_end = end; other_scene = <<scene:named>>; break;
		}
	} else external_condition = Specifications::new_UNKNOWN(CW);

@h Scene-changing machinery at run-time.
So what are scenes for? Well, they have two uses. One is that the end rulebooks
are run when ends occur, which is a convenient way to time events. The
following generates the necessary code to (a) detect when a scene end occurs,
and (b) act upon it. This is all handled by the following I6 routine.

There is one argument, |chs|: the number of iterations so far. Iterations occur
because each set of scene changes could change the circumstances in such a
way that other scene changes are now required (through external conditions,
not through anchors); we don't want this to lock up, so we will cap recursion.
Within the routine, a second local variable, |ch|, is a flag indicating
whether any change in status has or has not occurred.

There is no significance to the return value.

@d MAX_SCENE_CHANGE_ITERATION 20

=
void PL::Scenes::DetectSceneChange_routine(void) {
	package_request *R = Kinds::Behaviour::package(K_use_option);
	inter_name *iname = Packaging::function(InterNames::one_off(I"detect_scene_change_fn", R),
		R, InterNames::iname(DetectSceneChange_INAME));
	packaging_state save = Packaging::enter_home_of(iname);
	Routines::begin(iname);
	inter_symbol *self = InterNames::to_symbol(iname);
	inter_symbol *chs_s = LocalVariables::add_internal_local_c_as_symbol(I"chs", "count of changes made");
	inter_symbol *ch_s = LocalVariables::add_internal_local_c_as_symbol(I"ch", "flag: change made");
	inter_symbol *CScene_l = Emit::reserve_label(I".CScene");

	scene *sc;
	LOOP_OVER(sc, scene) @<Compile code detecting the ends of a specific scene@>;

	Emit::place_label(CScene_l, TRUE);
	@<Add the scene-change tail@>;

	Routines::end();
	Packaging::exit(save);
}

@<Add the scene-change tail@> =
	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::inv_primitive(gt_interp);
		Emit::down();
			Emit::val_symbol(K_value, chs_s);
			Emit::val(K_number, LITERAL_IVAL, (inter_t) MAX_SCENE_CHANGE_ITERATION);
		Emit::up();
		Emit::code();
		Emit::down();
			Emit::inv_primitive(print_interp);
			Emit::down();
				Emit::val_text(I">--> The scene change machinery is stuck.\n");
			Emit::up();
			Emit::rtrue();
		Emit::up();
	Emit::up();

	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::inv_primitive(gt_interp);
		Emit::down();
			Emit::val_symbol(K_value, ch_s);
			Emit::val(K_number, LITERAL_IVAL, 0);
		Emit::up();
		Emit::code();
		Emit::down();
			Emit::inv_call(self);
			Emit::down();
				Emit::inv_primitive(preincrement_interp);
				Emit::down();
					Emit::ref_symbol(K_value, chs_s);
				Emit::up();
			Emit::up();
		Emit::up();
	Emit::up();

	Emit::rfalse();

@ Recall that ends numbered 1, 2, 3, ... are all ways for the scene to end,
so they are only checked if its status is currently running; end 0 is the
beginning, checked only if it isn't. We give priority to the higher end
numbers so that more abstruse ways to end take precedence over less.

@<Compile code detecting the ends of a specific scene@> =
	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::inv_primitive(eq_interp);
		Emit::down();
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_object, InterNames::extern(SCENESTATUS_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::val(K_number, LITERAL_IVAL, 1);
		Emit::up();
		Emit::code();
		Emit::down();
			for (int end=sc->no_ends-1; end>=1; end--)
				PL::Scenes::test_scene_end(sc, end, ch_s, CScene_l);
		Emit::up();
	Emit::up();

	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::inv_primitive(eq_interp);
		Emit::down();
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_object, InterNames::extern(SCENESTATUS_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::val(K_number, LITERAL_IVAL, 0);
		Emit::up();
		Emit::code();
		Emit::down();
			PL::Scenes::test_scene_end(sc, 0, ch_s, CScene_l);
		Emit::up();
	Emit::up();

@ Individual ends are tested here. There are actually three ways an end can
occur: at start of play (for end 0 only), when an I7 condition holds, or when
another end to which it is anchored also ends. But we only check the first
two, because the third way will be taken care of by the consequences code
below.

=
void PL::Scenes::test_scene_end(scene *sc, int end, inter_symbol *ch_s, inter_symbol *CScene_l) {
	if ((end == 0) && (sc->start_of_play)) {
		Emit::inv_primitive(if_interp);
		Emit::down();
			Emit::inv_primitive(eq_interp);
			Emit::down();
				Emit::inv_primitive(bitwiseand_interp);
				Emit::down();
					Emit::inv_primitive(lookup_interp);
					Emit::down();
						Emit::val_iname(K_object, InterNames::extern(SCENEENDINGS_EXNAMEF));
						Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
					Emit::up();
					Emit::val(K_number, LITERAL_IVAL, 1);
				Emit::up();
				Emit::val(K_number, LITERAL_IVAL, 0);
			Emit::up();
			Emit::code();
			Emit::down();
				PL::Scenes::compile_scene_end(sc, 0);
			Emit::up();
		Emit::up();
	}
	parse_node *S = sc->anchor_condition[end];
	if (S) {
		@<Reparse the scene end condition in this new context@>;
		@<Compile code to test the scene end condition@>;
	}
}

@<Reparse the scene end condition in this new context@> =
	current_sentence = sc->anchor_condition_set[end];
	if (ParseTree::is(S, UNKNOWN_NT)) {
		if (<s-condition>(ParseTree::get_text(S))) S = <<rp>>;
		sc->anchor_condition[end] = S;
	}
	if (ParseTree::is(S, UNKNOWN_NT)) {
		LOG("Condition: $P\n", S);
		Problems::Issue::sentence_problem(_p_(PM_ScenesBadCondition),
			"'begins when' and 'ends when' must be followed by a condition",
			"which this does not seem to be, or else 'when play begins', "
			"'when play ends', 'when S begins', or 'when S ends', where "
			"S is the name of any scene.");
		return;
	}

	if (Dash::check_condition(S) == FALSE) return;

@ If the condition holds, we set the change flag |ch| and abort the search
through scenes by jumping past the run of tests. (We can't compile a break
instruction because we're not compiling a loop.)

@<Compile code to test the scene end condition@> =
	Emit::inv_primitive(if_interp);
	Emit::down();
		current_sentence = sc->anchor_condition_set[end];
		Specifications::Compiler::emit_as_val(K_truth_state, S);
		Emit::code();
		Emit::down();
			Emit::inv_primitive(store_interp);
			Emit::down();
				Emit::ref_symbol(K_value, ch_s);
				Emit::val(K_number, LITERAL_IVAL, 1);
			Emit::up();
			PL::Scenes::compile_scene_end(sc, end);
			Emit::inv_primitive(jump_interp);
			Emit::down();
				Emit::lab(CScene_l);
			Emit::up();
		Emit::up();
	Emit::up();

@ That's everything except for the consequences of a scene end occurring.
Code for that is generated here.

Because one end can cause another, given anchoring, we must guard against
compiler hangs when the source text calls for infinite recursion (since
this would cause us to generate infinitely long code). So the |marker| flags
are used to mark which scenes have already been ended in code generated
for this purpose.

=
void PL::Scenes::compile_scene_end(scene *sc, int end) {
	scene *sc2;
	LOOP_OVER(sc2, scene) sc2->marker = 0;
	PL::Scenes::compile_scene_end_dash(sc, end);
}

@ The semantics of scene ending are trickier than they look, because of the
fact that "Ballroom Dance ends merrily" (say, end number 3) is in some
sense a specialisation of "Ballroom Dance ends" (1). The doctrine is that
end 3 causes end 1 to happen first, because a special ending is also a
general ending; {\it but} rules taking effect on end 3 come earlier than
those for end 1, because they're more specialised, so they have a right to
take effect first.

=
void PL::Scenes::compile_scene_end_dash(scene *sc, int end) {
	int ix = sc->allocation_id;
	sc->marker++;
	if (end >= 2) {
		int e = end; end = 1;
		@<Compile code to print text in response to the SCENES command@>;
		@<Compile code to update the scene status@>;
		@<Compile code to update the arrays recording most recent scene ending@>;
		end = e;
	}
	@<Compile code to print text in response to the SCENES command@>;
	@<Compile code to update the scene status@>;
	@<Compile code to run the scene end rulebooks@>
	@<Compile code to update the arrays recording most recent scene ending@>;
	@<Compile code to cause consequent scene ends@>;

	if (end >= 2) {
		int e = end; end = 1;
		@<Compile code to run the scene end rulebooks@>;
		@<Compile code to cause consequent scene ends@>;
		end = e;
	}
}

@ If the scene has the "recurring" either/or property, then any of the
"ends" endings will fail to reset its status. (This doesn't mean that no
end actually occurred.)

@<Compile code to update the scene status@> =
	if (end == 0) {
		Emit::inv_primitive(store_interp);
		Emit::down();
			Emit::inv_primitive(lookupref_interp);
			Emit::down();
				Emit::val_iname(K_value, InterNames::extern(SCENESTATUS_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::val(K_number, LITERAL_IVAL, 1);
		Emit::up();
	} else {
		Emit::inv_primitive(ifelse_interp);
		Emit::down();
			inter_name *iname = InterNames::extern(GPROPERTY_EXNAMEF);
			Emit::inv_call(InterNames::to_symbol(iname));
			Emit::down();
				Kinds::RunTime::emit_weak_id_as_val(K_scene);
				Emit::val(K_number, LITERAL_IVAL, (inter_t) ix+1);
				Emit::val_iname(K_value, Properties::iname(P_recurring));
			Emit::up();
			Emit::code();
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::inv_primitive(lookupref_interp);
					Emit::down();
						Emit::val_iname(K_value, InterNames::extern(SCENESTATUS_EXNAMEF));
						Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
					Emit::up();
					Emit::val(K_number, LITERAL_IVAL, 0);
				Emit::up();
			Emit::up();
			Emit::code();
			Emit::down();
				Emit::inv_primitive(store_interp);
				Emit::down();
					Emit::inv_primitive(lookupref_interp);
					Emit::down();
						Emit::val_iname(K_value, InterNames::extern(SCENESTATUS_EXNAMEF));
						Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
					Emit::up();
					Emit::val(K_number, LITERAL_IVAL, 2);
				Emit::up();
			Emit::up();
		Emit::up();
	}

@<Compile code to run the scene end rulebooks@> =
	if (end == 0) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(FOLLOWRULEBOOK_EXNAMEF)));
		Emit::down();
			Emit::val_iname(K_value, InterNames::extern(WHENSCENEBEGINS_EXNAMEF));
			Emit::val(K_number, LITERAL_IVAL, (inter_t) (sc->allocation_id + 1));
		Emit::up();
	}
	Emit::inv_call(InterNames::to_symbol(InterNames::extern(FOLLOWRULEBOOK_EXNAMEF)));
	Emit::down();
		Emit::val(K_number, LITERAL_IVAL, (inter_t) (sc->end_rulebook[end]->allocation_id));
	Emit::up();
	if (end == 1) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(FOLLOWRULEBOOK_EXNAMEF)));
		Emit::down();
			Emit::val_iname(K_value, InterNames::extern(WHENSCENEENDS_EXNAMEF));
			Emit::val(K_number, LITERAL_IVAL, (inter_t) (sc->allocation_id + 1));
		Emit::up();
	}

@<Compile code to update the arrays recording most recent scene ending@> =
	inter_name *sarr = InterNames::extern(SCENEENDED_EXNAMEF);
	if (end == 0) sarr = InterNames::extern(SCENESTARTED_EXNAMEF);
	Emit::inv_primitive(store_interp);
	Emit::down();
		Emit::inv_primitive(lookupref_interp);
		Emit::down();
			Emit::val_iname(K_value, sarr);
			Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
		Emit::up();
		Emit::val_iname(K_number, InterNames::extern(THETIME_EXNAMEF));
	Emit::up();

	Emit::inv_primitive(store_interp);
	Emit::down();
		Emit::inv_primitive(lookupref_interp);
		Emit::down();
			Emit::val_iname(K_value, InterNames::extern(SCENEENDINGS_EXNAMEF));
			Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
		Emit::up();
		Emit::inv_primitive(bitwiseor_interp);
		Emit::down();
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_value, InterNames::extern(SCENEENDINGS_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::val(K_number, LITERAL_IVAL, (inter_t) (1 << end));
		Emit::up();
	Emit::up();

	Emit::inv_primitive(store_interp);
	Emit::down();
		Emit::inv_primitive(lookupref_interp);
		Emit::down();
			Emit::val_iname(K_value, InterNames::extern(SCENELATESTENDING_EXNAMEF));
			Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
		Emit::up();
		Emit::val(K_value, LITERAL_IVAL, (inter_t) end);
	Emit::up();

@<Compile code to print text in response to the SCENES command@> =
	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::val_iname(K_value, InterNames::extern(DEBUGSCENES_EXNAMEF));
		Emit::code();
		Emit::down();
			TEMPORARY_TEXT(OUT);
			WRITE("[Scene '");
			if (sc->as_instance) WRITE("%+W", Instances::get_name(sc->as_instance, FALSE));
			WRITE("' ");
			if (end == 0) WRITE("begins"); else WRITE("ends");
			if (end >= 2) WRITE(" %+W", sc->end_names[end]);
			WRITE("]\n");
			Emit::inv_primitive(print_interp);
			Emit::down();
				Emit::val_text(OUT);
			Emit::up();
			DISCARD_TEXT(OUT);
		Emit::up();
	Emit::up();

@ In general, the marker count is used to ensure that |PL::Scenes::compile_scene_end_dash|
never calls itself for a scene it has been called with before on this round.
This prevents Inform locking up generating infinite amounts of code. However,
one exception is allowed, in very limited circumstances. Suppose we want to
make a scene recur, but only if it ends in a particular way. Then we might
type:

>> Brisk Quadrille begins when Brisk Quadrille ends untidily.

This is allowed; it's a case where the "tolerance" below is raised.

@<Compile code to cause consequent scene ends@> =
	scene *other_scene;
	LOOP_OVER(other_scene, scene) {
		int tolerance = 1;
		if (sc == other_scene) tolerance = sc->no_ends;
		if (other_scene->marker < tolerance) {
			int other_end;
			for (other_end = 0; other_end < other_scene->no_ends; other_end++) {
				scene_connector *scon;
				for (scon = other_scene->anchor_scene[other_end]; scon; scon = scon->next) {
					if ((scon->connect_to == sc) && (scon->end == end)) {
						Emit::inv_primitive(if_interp);
						Emit::down();
							Emit::inv_primitive(eq_interp);
							Emit::down();
								Emit::inv_primitive(lookup_interp);
								Emit::down();
									Emit::val_iname(K_value, InterNames::extern(SCENESTATUS_EXNAMEF));
									Emit::val(K_number, LITERAL_IVAL, (inter_t) other_scene->allocation_id);
								Emit::up();
								if (other_end >= 1)
									Emit::val(K_number, LITERAL_IVAL, 1);
								else
									Emit::val(K_number, LITERAL_IVAL, 0);
							Emit::up();
							Emit::code();
							Emit::down();
								PL::Scenes::compile_scene_end_dash(other_scene, other_end);
							Emit::up();
						Emit::up();
					}
				}
			}
		}
	}

@h More SCENES output.
As we've seen, when the SCENES command has been typed, Inform prints a notice
out at run-time when any scene end occurs. It also prints a run-down of the
scene status at the moment the command is typed, and the following code is
what handles this.

=
void PL::Scenes::ShowSceneStatus_routine(void) {
	package_request *R = Kinds::Behaviour::package(K_use_option);
	inter_name *iname = Packaging::function(InterNames::one_off(I"show_scene_status_fn", R),
		R, InterNames::iname(ShowSceneStatus_INAME));
	packaging_state save = Packaging::enter_home_of(iname);
	Routines::begin(iname);
	Emit::inv_primitive(ifdebug_interp);
	Emit::down();
		Emit::code();
		Emit::down();
			scene *sc;
			LOOP_OVER(sc, scene) {
				wording NW = Instances::get_name(sc->as_instance, FALSE);

				Emit::inv_primitive(ifelse_interp);
				Emit::down();
					Emit::inv_primitive(eq_interp);
					Emit::down();
						Emit::inv_primitive(lookup_interp);
						Emit::down();
							Emit::val_iname(K_object, InterNames::extern(SCENESTATUS_EXNAMEF));
							Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
						Emit::up();
						Emit::val(K_number, LITERAL_IVAL, 1);
					Emit::up();
					Emit::code();
					Emit::down();
						@<Show status of this running scene@>;
					Emit::up();
					Emit::code();
					Emit::down();
						@<Show status of this non-running scene@>;
					Emit::up();
				Emit::up();
			}
		Emit::up();
	Emit::up();
	Routines::end();
	Packaging::exit(save);
}

@<Show status of this running scene@> =
	TEMPORARY_TEXT(T);
	WRITE_TO(T, "Scene '%+W' playing (for ", NW);
	Emit::inv_primitive(print_interp);
	Emit::down();
		Emit::val_text(T);
	Emit::up();
	DISCARD_TEXT(T);

	Emit::inv_primitive(printnumber_interp);
	Emit::down();
		Emit::inv_primitive(minus_interp);
		Emit::down();
			Emit::val_iname(K_number, InterNames::extern(THETIME_EXNAMEF));
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_object, InterNames::extern(SCENESTARTED_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
		Emit::up();
	Emit::up();

	Emit::inv_primitive(print_interp);
	Emit::down();
		Emit::val_text(I" mins now)\n");
	Emit::up();

@<Show status of this non-running scene@> =
	Emit::inv_primitive(if_interp);
	Emit::down();
		Emit::inv_primitive(gt_interp);
		Emit::down();
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_object, InterNames::extern(SCENELATESTENDING_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::val(K_number, LITERAL_IVAL, 0);
		Emit::up();
		Emit::code();
		Emit::down();
			@<Show status of this recently ended scene@>;
		Emit::up();
	Emit::up();

@<Show status of this recently ended scene@> =
	TEMPORARY_TEXT(T);
	WRITE_TO(T, "Scene '%+W' ended", NW);
	Emit::inv_primitive(print_interp);
	Emit::down();
		Emit::val_text(T);
	Emit::up();
	DISCARD_TEXT(T);

	if (sc->no_ends > 2) {
		Emit::inv_primitive(switch_interp);
		Emit::down();
			Emit::inv_primitive(lookup_interp);
			Emit::down();
				Emit::val_iname(K_object, InterNames::extern(SCENELATESTENDING_EXNAMEF));
				Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
			Emit::up();
			Emit::code();
			Emit::down();
				for (int end=2; end<sc->no_ends; end++) {
					Emit::inv_primitive(case_interp);
					Emit::down();
						Emit::val(K_number, LITERAL_IVAL, (inter_t) end);
						Emit::code();
						Emit::down();
							TEMPORARY_TEXT(T);
							WRITE_TO(T, " %+W", sc->end_names[end]);
							Emit::inv_primitive(print_interp);
							Emit::down();
								Emit::val_text(T);
							Emit::up();
							DISCARD_TEXT(T);
						Emit::up();
					Emit::up();
				}
			Emit::up();
		Emit::up();
	}

	Emit::inv_primitive(print_interp);
	Emit::down();
		Emit::val_text(I"\n");
	Emit::up();

@h Printing scene names.
The following routine isn't really necessary, but it's convenient to define
it explicitly rather than allowing Inform to generate a similar routine by
virtue of "scene" being an enumerated kind. (Because we're doing this in a
plugin, and it would cause timing hassles, that's why. It's only a small sin.)

=
void PL::Scenes::PrintSceneName_routine(void) {
	Routines::begin(InterNames::iname(PrintSceneName_INAME));
	inter_symbol *sc_s = LocalVariables::add_named_call_as_symbol(I"sc");
	Emit::inv_primitive(switch_interp);
	Emit::down();
		Emit::val_symbol(K_value, sc_s);
		Emit::code();
		Emit::down();
			scene *sc;
			LOOP_OVER(sc, scene) {
				Emit::inv_primitive(case_interp);
				Emit::down();
					Emit::val(K_number, LITERAL_IVAL, (inter_t) (sc->allocation_id + 1));
					Emit::code();
					Emit::down();
						Emit::inv_primitive(print_interp);
						Emit::down();
							TEMPORARY_TEXT(T);
							wording NW = Instances::get_name(sc->as_instance, FALSE);
							WRITE_TO(T, "%W", NW);
							Emit::val_text(T);
							DISCARD_TEXT(T);
						Emit::up();
					Emit::up();
				Emit::up();
			}
			Emit::inv_primitive(default_interp);
			Emit::down();
				Emit::code();
				Emit::down();
					Emit::inv_primitive(print_interp);
					Emit::down();
						Emit::val_text(I"<no-such-scene>");
					Emit::up();
				Emit::up();
			Emit::up();
		Emit::up();
	Emit::up();
	Routines::end();
}

@h During clauses.
We've now seen one use of scenes: they kick off rulebooks when they begin or
end. The other use for them is to predicate rules on whether they are currently
playing or not, using a "during" clause.

We allow these either to name a specific scene, or to describe a collection
of them:

=
<s-scene-description> ::=
	<s-value>		==> @<Filter to force this to be a scene description@>

@<Filter to force this to be a scene description@> =
	if (K_scene == NULL) return FALSE;
	parse_node *spec = RP[1];
	instance *I = Rvalues::to_instance(spec);
	if (((I) && (Instances::of_kind(I, K_scene))) ||
		((Specifications::is_description(spec)) &&
			(Kinds::Compare::eq(Specifications::to_kind(spec), K_scene)))) {
		*XP = spec;
	} else return FALSE;

@ And this is where we compile I6 code to test that a scene matching this is
actually running:

=
void PL::Scenes::emit_during_clause(parse_node *spec) {
	int stuck = TRUE;
	if (K_scene == NULL) { Emit::val(K_truth_state, LITERAL_IVAL, 1); return; }
	if (ParseTreeUsage::is_rvalue(spec)) {
		Dash::check_value(spec, K_scene);
		instance *I = Rvalues::to_instance(spec);
		if (Instances::of_kind(I, K_scene)) {
			scene *sc = PL::Scenes::from_named_constant(I);
			Emit::inv_primitive(eq_interp);
			Emit::down();
				Emit::inv_primitive(lookup_interp);
				Emit::down();
					Emit::val_iname(K_value, InterNames::extern(SCENESTATUS_EXNAMEF));
					Emit::val(K_number, LITERAL_IVAL, (inter_t) sc->allocation_id);
				Emit::up();
				Emit::val(K_number, LITERAL_IVAL, 1);
			Emit::up();
			stuck = FALSE;
		}
	} else {
		if (Dash::check_value(spec, Kinds::unary_construction(CON_description, K_scene)) == ALWAYS_MATCH) {
			parse_node *desc = Descriptions::to_rvalue(spec);
			if (desc) {
				Emit::inv_call(InterNames::to_symbol(InterNames::extern(DURINGSCENEMATCHING_EXNAMEF)));
				Emit::down();
					Specifications::Compiler::emit_as_val(K_value, desc);
				Emit::up();
				stuck = FALSE;
			}
		}
	}
	if (stuck) {
		Emit::val(K_truth_state, LITERAL_IVAL, 1);
		Problems::Issue::sentence_problem(_p_(PM_ScenesBadDuring),
			"'during' must be followed by the name of a scene or of a "
			"description which applies to a single scene",
			"such as 'during Station Arrival' or 'during a recurring scene'.");
		return;
	}
}