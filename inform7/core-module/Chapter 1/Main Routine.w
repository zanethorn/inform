[CoreMain::] Main Routine.

As with all C programs, Inform begins execution in a |main| routine,
reading command-line arguments to modify its behaviour.

@h Flags.
These flags are set by command-line parameters. |for_release| will be set
when NI is used in a run started by clicking on the Release button in the
application. |rng_seed_at_start_of_play| is not used by the application,
but the |intest| program makes use of this feature to make repeated
tests of the Z-machine story file produce identical sequences of random
numbers: without this, we would have difficulty comparing a transcript of
text produced by the story file on one compilation from another.

|story_filename_extension| is also set as a result of information passed
from the application via the command line to NI. In order for NI to write
good releasing instructions, it needs to know the story file format
(".z5", ".z8", etc.) of the finally produced story file. But since
NI compiles only to Inform 6 code, and does not run I6 itself, it has no
way of telling what the application intends to do on this. So the
application is required to give NI advance notice of this via a
command-line option.

=
int this_is_a_debug_compile = FALSE; /* Destined to be compiled with debug features */
int this_is_a_release_compile = FALSE; /* Omit sections of source text marked not for release */
int existing_story_file = FALSE; /* Ignore source text to blorb existing story file? */
int rng_seed_at_start_of_play = 0; /* The seed value, or 0 if not seeded */
int census_mode = FALSE; /* NI running only to update extension documentation */
text_stream *story_filename_extension = NULL; /* What story file we will eventually have */
int show_progress_indicator = TRUE; /* Produce percentage of progress messages */
int default_scoring_setting = FALSE; /* By default, whether a score is kept at run time */
int scoring_option_set = NOT_APPLICABLE; /* Whether in this case a score is kept at run time */
int disable_import = FALSE;

@ This flag is set by the use option "Use no deprecated features", and makes
Inform strict in rejecting syntaxes we intend to get rid of later on.

=
int no_deprecated_features = FALSE; /* forbid syntaxes marked as deprecated? */

@ Broadly speaking, what NI does can be divided into two halves: in
the first half, it reads all the assertions, makes all the objects and
global variables and constructs the model world; in the second half,
it compiles the phrases and grammar to go with it.
|model_world_constructed| records which of these halves we are
currently in: |FALSE| in the first half, |TRUE| in the second.

If there were a third stage, it would be indexing, and during that
period |indexing_stage| is |TRUE|. But by that time the compilation of
Inform 6 code is complete.

=
int text_loaded_from_source = FALSE; /* Lexical scanning is done */
int model_world_under_construction = FALSE; /* World model is being constructed */
int model_world_constructed = FALSE; /* World model is now constructed */
int indexing_stage = FALSE; /* Everything is done except indexing */

@ Either way, execution really begins in the |core_inform_main| routine, which
takes command-line arguments with the standard parameters |argc| and |argv|.
In practice it consists only of command-line processing and the minimum setup
necessary to get the meta-language interpreter running, so that it can then
hand over to the template file |Main.i6t|.

Inform returns only two possible values to the shell, either here or via
|exit(1)| in the case of fatal errors: 0 if it completed its run with no
errors, 1 if errors were produced.

=
int report_clock_time = FALSE;
time_t right_now;
int export_mode = FALSE, import_mode = FALSE;
text_stream *inter_processing_chain = NULL;

int CoreMain::main(int argc, char *argv[]) {
	clock_t start = clock();
	@<Banner and startup@>;
	@<Register command-line arguments@>;
	int proceed = CommandLine::read(argc, argv, NULL, &CoreMain::switch, &CoreMain::bareword);
	if (proceed) {
		@<With that done, configure all other settings@>;
		@<Open the debugging log and the problems report@>;
		@<Boot up the compiler@>;
		if (census_mode)
			Extensions::Files::handle_census_mode();
		else {
			@<Perform lexical analysis@>;
			@<Perform semantic analysis@>;
			@<Read the assertions in two passes@>;
			@<Make the model world@>;
			@<Tables and grammar@>;
			@<Phrases and rules@>;
			@<Generate inter@>;
			@<Convert inter to Inform 6@>;
			@<Generate metadata@>;
			@<Post mortem logging@>;
		}
	}
	clock_t end = clock();
	@<Shutdown and rennab@>;
	if (problem_count > 0) Problems::Fatal::exit(1);
	return 0;
}

@ It is the dawn of time...

@<Banner and startup@> =
	Errors::set_internal_handler(&Problems::Issue::internal_error_fn);
	story_filename_extension = I"ulx";

	PRINT("%B build %B has started.\n", FALSE, TRUE);
	STREAM_FLUSH(STDOUT);

@ Note that the locations manager is also allowed to process command-line
arguments in order to set certain pathnames or filenames, so the following
list is not exhaustive.

@e CASE_CLSW
@e CENSUS_CLSW
@e CLOCK_CLSW
@e DEBUG_CLSW
@e EXTERNAL_CLSW
@e FORMAT_CLSW
@e CRASHALL_CLSW
@e INTERNAL_CLSW
@e NOINDEX_CLSW
@e NOPROGRESS_CLSW
@e PROJECT_CLSW
@e RELEASE_CLSW
@e REQUIRE_PROBLEM_CLSW
@e RNG_CLSW
@e SCORING_CLSW
@e SIGILS_CLSW
@e TRANSIENT_CLSW
@e INTER_CLSW
@e IMPORT_CLSW
@e EXPORT_CLSW

@<Register command-line arguments@> =
	CommandLine::declare_heading(
		L"inform7: a compiler from source text to Inform 6 code\n\n"
		L"Usage: inform7 [OPTIONS] [SOURCETEXT]\n");

	CommandLine::declare_textual_switch(FORMAT_CLSW, L"format", 1,
		L"compile I6 code suitable for the virtual machine X");
	CommandLine::declare_boolean_switch(CENSUS_CLSW, L"census", 1,
		L"rather than compile, perform an extensions census");
	CommandLine::declare_boolean_switch(CLOCK_CLSW, L"clock", 1,
		L"time how long inform7 takes to run");
	CommandLine::declare_boolean_switch(DEBUG_CLSW, L"debug", 1,
		L"compile with debugging features even on a Release");
	CommandLine::declare_boolean_switch(CRASHALL_CLSW, L"crash-all", 1,
		L"crash intentionally on Problem messages (for debugger backtraces)");
	CommandLine::declare_boolean_switch(NOINDEX_CLSW, L"noindex", 1,
		L"don't produce an Index");
	CommandLine::declare_boolean_switch(NOPROGRESS_CLSW, L"noprogress", 1,
		L"don't display progress percentages");
	CommandLine::declare_boolean_switch(RELEASE_CLSW, L"release", 1,
		L"compile a version suitable for a Release build");
	CommandLine::declare_boolean_switch(RNG_CLSW, L"rng", 1,
		L"fix the random number generator of the story file (for testing)");
	CommandLine::declare_boolean_switch(SCORING_CLSW, L"scoring", 1,
		L"set default scoring setting");
	CommandLine::declare_boolean_switch(SIGILS_CLSW, L"sigils", 1,
		L"print Problem message sigils (for testing)");
	CommandLine::declare_switch(CASE_CLSW, L"case", 2,
		L"make any source links refer to the source in extension example X");
	CommandLine::declare_switch(REQUIRE_PROBLEM_CLSW, L"require-problem", 2,
		L"return 0 unless exactly this Problem message is generated (for testing)");
	CommandLine::declare_switch(INTER_CLSW, L"inter", 2,
		L"specify code-generation chain for inter code");
	CommandLine::declare_switch(IMPORT_CLSW, L"import", 2,
		L"import Standard Rules as module (experimental)");
	CommandLine::declare_switch(EXPORT_CLSW, L"export", 2,
		L"export Standard Rules as module (experimental)");

	CommandLine::declare_switch(PROJECT_CLSW, L"project", 2,
		L"work within the Inform project X");
	CommandLine::declare_switch(INTERNAL_CLSW, L"internal", 2,
		L"use X as the location of built-in material such as the Standard Rules");
	CommandLine::declare_switch(EXTERNAL_CLSW, L"external", 2,
		L"use X as the user's home for installed material such as extensions");
	CommandLine::declare_switch(TRANSIENT_CLSW, L"transient", 2,
		L"use X for transient data such as the extensions census");

@<With that done, configure all other settings@> =
	VirtualMachines::set_identifier(story_filename_extension);
	if (Locations::set_defaults(census_mode) == FALSE)
		Problems::Fatal::issue("Unable to create folders in local file system");
	Log::set_debug_log_filename(filename_of_debugging_log);

@<Open the debugging log and the problems report@> =
	Log::open();
	LOG("Inform called as:");
	for (int i=0; i<argc; i++) LOG(" %s", argv[i]);
	LOG("\n");
	Problems::Issue::start_problems_report();

@

@d COMPILATION_STEP(routine, mark) {
	if (problem_count == 0) {
		routine();
		/* Emit::marker(mark); */
	}
}

@<Boot up the compiler@> =
	Emit::begin();
	COMPILATION_STEP(Semantics::read_preform, I"Semantics::read_preform")
	COMPILATION_STEP(Plugins::Manage::start, I"Plugins::Manage::start")
	COMPILATION_STEP(InferenceSubjects::begin, I"InferenceSubjects::begin")

@<Perform lexical analysis@> =
	ProgressBar::update_progress_bar(0, 0);
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Lexical analysis");
	COMPILATION_STEP(SourceFiles::read_primary_source_text, I"SourceFiles::read_primary_source_text")
	COMPILATION_STEP(Sentences::RuleSubtrees::create_standard_csps, I"Sentences::RuleSubtrees::create_standard_csps")

@<Perform semantic analysis@> =
	ProgressBar::update_progress_bar(1, 0);
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Semantic analysis Ia");
	COMPILATION_STEP(ParseTreeUsage::plant_parse_tree, I"ParseTreeUsage::plant_parse_tree")
	COMPILATION_STEP(StructuralSentences::break_source, I"StructuralSentences::break_source")
	COMPILATION_STEP(Extensions::Inclusion::traverse, I"Extensions::Inclusion::traverse")
	COMPILATION_STEP(Sentences::Headings::satisfy_dependencies, I"Sentences::Headings::satisfy_dependencies")

	if (problem_count == 0) CoreMain::go_to_log_phase(I"Initialise language semantics");
	if (problem_count == 0) Plugins::Manage::command(I"load");
	COMPILATION_STEP(BinaryPredicates::make_built_in, I"BinaryPredicates::make_built_in")
	COMPILATION_STEP(NewVerbs::add_inequalities, I"NewVerbs::add_inequalities")

	if (problem_count == 0) CoreMain::go_to_log_phase(I"Semantic analysis Ib");
	COMPILATION_STEP(Sentences::VPs::traverse, I"Sentences::VPs::traverse")
	COMPILATION_STEP(Sentences::Rearrangement::tidy_up_ofs_and_froms, I"Sentences::Rearrangement::tidy_up_ofs_and_froms")
	COMPILATION_STEP(Sentences::RuleSubtrees::register_recently_lexed_phrases, I"Sentences::RuleSubtrees::register_recently_lexed_phrases")
	COMPILATION_STEP(StructuralSentences::declare_source_loaded, I"StructuralSentences::declare_source_loaded")
	COMPILATION_STEP(Kinds::Interpreter::include_templates_for_kinds, I"Kinds::Interpreter::include_templates_for_kinds")

	if (problem_count == 0) CoreMain::go_to_log_phase(I"Semantic analysis II");
	COMPILATION_STEP(ParseTreeUsage::verify, I"ParseTreeUsage::verify")
	COMPILATION_STEP(Extensions::Files::check_versions, I"Extensions::Files::check_versions")
	COMPILATION_STEP(Sentences::Headings::make_tree, I"Sentences::Headings::make_tree")
	COMPILATION_STEP(Sentences::Headings::write_as_xml, I"Sentences::Headings::write_as_xml")
	COMPILATION_STEP(Sentences::Headings::write_as_xml, I"Sentences::Headings::write_as_xml")
	COMPILATION_STEP(Modules::traverse_to_define, I"Modules::traverse_to_define")

	if (problem_count == 0) CoreMain::go_to_log_phase(I"Semantic analysis III");
	COMPILATION_STEP(Phrases::Adjectives::traverse, I"Phrases::Adjectives::traverse")
	COMPILATION_STEP(Equations::traverse_to_create, I"Equations::traverse_to_create")
	COMPILATION_STEP(Tables::traverse_to_create, I"Tables::traverse_to_create")
	COMPILATION_STEP(Phrases::Manager::traverse_for_names, I"Phrases::Manager::traverse_for_names")

@<Read the assertions in two passes@> =
	ProgressBar::update_progress_bar(2, 0);
	if (problem_count == 0) CoreMain::go_to_log_phase(I"First pass through assertions");
	if (problem_count == 0) Assertions::Traverse::traverse(1);
	COMPILATION_STEP(Tables::traverse_to_stock, I"Tables::traverse_to_stock")
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Second pass through assertions");
	if (problem_count == 0) Assertions::Traverse::traverse(2);
	COMPILATION_STEP(Kinds::RunTime::kind_declarations, I"Kinds::RunTime::kind_declarations")

@<Make the model world@> =
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Making the model world");
	COMPILATION_STEP(UseOptions::compile, I"UseOptions::compile")
	COMPILATION_STEP(Properties::emit, I"Properties::emit")
	COMPILATION_STEP(Properties::Emit::allocate_attributes, I"Properties::Emit::allocate_attributes")
	COMPILATION_STEP(PL::Actions::name_all, I"PL::Actions::name_all")
	COMPILATION_STEP(UseNouns::name_all, I"UseNouns::name_all")
	COMPILATION_STEP(World::complete, I"World::complete")
	COMPILATION_STEP(Properties::Measurement::validate_definitions, I"Properties::Measurement::validate_definitions")
	COMPILATION_STEP(BinaryPredicates::make_built_in_further, I"BinaryPredicates::make_built_in_further")
	COMPILATION_STEP(PL::Bibliographic::IFID::define_UUID, I"PL::Bibliographic::IFID::define_UUID")
	COMPILATION_STEP(PL::Figures::compile_ResourceIDsOfFigures_array, I"PL::Figures::compile_ResourceIDsOfFigures_array")
	COMPILATION_STEP(PL::Sounds::compile_ResourceIDsOfSounds_array, I"PL::Sounds::compile_ResourceIDsOfSounds_array")
	COMPILATION_STEP(PL::Player::InitialSituation, I"PL::Player::InitialSituation")

@<Tables and grammar@> =
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Tables and grammar");
	COMPILATION_STEP(Tables::check_tables_for_kind_clashes, I"Tables::check_tables_for_kind_clashes")
	COMPILATION_STEP(Tables::Support::compile_print_table_names, I"Tables::Support::compile_print_table_names")
	COMPILATION_STEP(PL::Parsing::traverse, I"PL::Parsing::traverse")
	COMPILATION_STEP(World::complete_additions, I"World::complete_additions")

@<Phrases and rules@> =
	ProgressBar::update_progress_bar(3, 0);
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Phrases and rules");
	COMPILATION_STEP(LiteralPatterns::define_named_phrases, I"LiteralPatterns::define_named_phrases")
	COMPILATION_STEP(Phrases::Manager::traverse, I"Phrases::Manager::traverse")
	COMPILATION_STEP(Phrases::Manager::register_meanings, I"Phrases::Manager::register_meanings")
	COMPILATION_STEP(Phrases::Manager::parse_rule_parameters, I"Phrases::Manager::parse_rule_parameters")
	COMPILATION_STEP(Phrases::Manager::add_rules_to_rulebooks, I"Phrases::Manager::add_rules_to_rulebooks")
	COMPILATION_STEP(Phrases::Manager::parse_rule_placements, I"Phrases::Manager::parse_rule_placements")
	COMPILATION_STEP(Equations::traverse_to_stock, I"Equations::traverse_to_stock")
	COMPILATION_STEP(Tables::traverse_to_stock, I"Tables::traverse_to_stock")
	COMPILATION_STEP(Properties::annotate_attributes, I"Properties::annotate_attributes")
	COMPILATION_STEP(Rulebooks::Outcomes::RulebookOutcomePrintingRule, I"Rulebooks::Outcomes::RulebookOutcomePrintingRule")
	COMPILATION_STEP(PL::Parsing::TestScripts::NO_TEST_SCENARIOS_constant, I"PL::Parsing::TestScripts::NO_TEST_SCENARIOS_constant")
	COMPILATION_STEP(Kinds::RunTime::compile_instance_counts, I"Kinds::RunTime::compile_instance_counts")

@ This is where we hand over to regular template files -- containing code
passed through as I6 source, as well as a few further commands -- starting
with "Output.i6t".

@<Generate inter@> =
	ProgressBar::update_progress_bar(4, 0);
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Generating inter");
	COMPILATION_STEP(UseOptions::compile_icl_commands, I"UseOptions::compile_icl_commands")
	COMPILATION_STEP(TemplateFiles::compile_build_number, I"TemplateFiles::compile_build_number")
	COMPILATION_STEP(Plugins::Manage::define_IFDEF_symbols, I"Plugins::Manage::define_IFDEF_symbols")
	COMPILATION_STEP(PL::Bibliographic::compile_constants, I"PL::Bibliographic::compile_constants")
	COMPILATION_STEP(Extensions::Files::ShowExtensionVersions_routine, I"Extensions::Files::ShowExtensionVersions_routine")
	COMPILATION_STEP(Kinds::Constructors::compile_I6_constants, I"Kinds::Constructors::compile_I6_constants")
	COMPILATION_STEP(PL::Score::compile_max_score, I"PL::Score::compile_max_score")
	COMPILATION_STEP(UseOptions::TestUseOption_routine, I"UseOptions::TestUseOption_routine")
	COMPILATION_STEP(Activities::compile_activity_constants, I"Activities::compile_activity_constants")
	COMPILATION_STEP(Activities::Activity_before_rulebooks_array, I"Activities::Activity_before_rulebooks_array")
	COMPILATION_STEP(Activities::Activity_for_rulebooks_array, I"Activities::Activity_for_rulebooks_array")
	COMPILATION_STEP(Activities::Activity_after_rulebooks_array, I"Activities::Activity_after_rulebooks_array")
	COMPILATION_STEP(Activities::Activity_atb_rulebooks_array, I"Activities::Activity_atb_rulebooks_array")
	COMPILATION_STEP(Relations::compile_defined_relation_constants, I"Relations::compile_defined_relation_constants")
	COMPILATION_STEP(Kinds::RunTime::compile_data_type_support_routines, I"Kinds::RunTime::compile_data_type_support_routines")
	COMPILATION_STEP(Kinds::RunTime::I7_Kind_Name_routine, I"Kinds::RunTime::I7_Kind_Name_routine")
	COMPILATION_STEP(World::Compile::compile, I"World::Compile::compile")
	COMPILATION_STEP(PL::Backdrops::write_found_in_routines, I"PL::Backdrops::write_found_in_routines")
	COMPILATION_STEP(PL::Map::write_door_dir_routines, I"PL::Map::write_door_dir_routines")
	COMPILATION_STEP(PL::Map::write_door_to_routines, I"PL::Map::write_door_to_routines")
	COMPILATION_STEP(PL::Parsing::Tokens::General::write_parse_name_routines, I"PL::Parsing::Tokens::General::write_parse_name_routines")
	COMPILATION_STEP(PL::Regions::write_regional_found_in_routines, I"PL::Regions::write_regional_found_in_routines")
	COMPILATION_STEP(Tables::complete, I"Tables::complete")
	COMPILATION_STEP(Tables::Support::compile, I"Tables::Support::compile")
	COMPILATION_STEP(Equations::compile, I"Equations::compile")
	COMPILATION_STEP(PL::Actions::Patterns::Named::compile, I"PL::Actions::Patterns::Named::compile")
	COMPILATION_STEP(PL::Actions::ActionData, I"PL::Actions::ActionData")
	COMPILATION_STEP(PL::Actions::ActionCoding_array, I"PL::Actions::ActionCoding_array")
	COMPILATION_STEP(PL::Actions::ActionHappened, I"PL::Actions::ActionHappened")
	COMPILATION_STEP(PL::Actions::compile_action_routines, I"PL::Actions::compile_action_routines")
	COMPILATION_STEP(PL::Parsing::Lines::MistakeActionSub_routine, I"PL::Parsing::Lines::MistakeActionSub_routine")
	COMPILATION_STEP(Phrases::Manager::compile_first_block, I"Phrases::Manager::compile_first_block")
	COMPILATION_STEP(Phrases::Manager::compile_rulebooks, I"Phrases::Manager::compile_rulebooks")
	COMPILATION_STEP(Phrases::Manager::rulebooks_array, I"Phrases::Manager::rulebooks_array")
	COMPILATION_STEP(PL::Scenes::DetectSceneChange_routine, I"PL::Scenes::DetectSceneChange_routine")
	COMPILATION_STEP(PL::Scenes::ShowSceneStatus_routine, I"PL::Scenes::ShowSceneStatus_routine")
	COMPILATION_STEP(PL::Files::arrays, I"PL::Files::arrays")
	COMPILATION_STEP(Rulebooks::rulebook_var_creators, I"Rulebooks::rulebook_var_creators")
	COMPILATION_STEP(Activities::activity_var_creators, I"Activities::activity_var_creators")
	COMPILATION_STEP(Relations::IterateRelations, I"Relations::IterateRelations")
	COMPILATION_STEP(Phrases::Manager::RulebookNames_array, I"Phrases::Manager::RulebookNames_array")
	COMPILATION_STEP(Phrases::Manager::RulePrintingRule_routine, I"Phrases::Manager::RulePrintingRule_routine")
	COMPILATION_STEP(PL::Parsing::Verbs::prepare, I"PL::Parsing::Verbs::prepare")
	COMPILATION_STEP(PL::Parsing::Verbs::compile_conditions, I"PL::Parsing::Verbs::compile_conditions")
	COMPILATION_STEP(PL::Parsing::Tokens::Values::number, I"PL::Parsing::Tokens::Values::number")
	COMPILATION_STEP(PL::Parsing::Tokens::Values::truth_state, I"PL::Parsing::Tokens::Values::truth_state")
	COMPILATION_STEP(PL::Parsing::Tokens::Values::time, I"PL::Parsing::Tokens::Values::time")
	COMPILATION_STEP(PL::Parsing::Tokens::Values::compile_type_gprs, I"PL::Parsing::Tokens::Values::compile_type_gprs")
	COMPILATION_STEP(NewVerbs::ConjugateVerb, I"NewVerbs::ConjugateVerb")
	COMPILATION_STEP(Adjectives::Meanings::agreements, I"Adjectives::Meanings::agreements")
	if ((this_is_a_release_compile == FALSE) || (this_is_a_debug_compile)) {
		COMPILATION_STEP(PL::Parsing::TestScripts::write_text, I"PL::Parsing::TestScripts::write_text")
		COMPILATION_STEP(PL::Parsing::TestScripts::TestScriptSub_routine, I"PL::Parsing::TestScripts::TestScriptSub_routine")
		COMPILATION_STEP(PL::Parsing::TestScripts::InternalTestCases_routine, I"PL::Parsing::TestScripts::InternalTestCases_routine")
	}

	COMPILATION_STEP(Lists::check, I"Lists::check")
	COMPILATION_STEP(Lists::compile, I"Lists::compile")
	COMPILATION_STEP(Phrases::Manager::compile_as_needed, I"Phrases::Manager::compile_as_needed")
	COMPILATION_STEP(Strings::compile_responses, I"Strings::compile_responses")
	COMPILATION_STEP(Lists::check, I"Lists::check")
	COMPILATION_STEP(Lists::compile, I"Lists::compile")
	COMPILATION_STEP(Relations::compile_defined_relations, I"Relations::compile_defined_relations")
	COMPILATION_STEP(Phrases::Manager::compile_as_needed, I"Phrases::Manager::compile_as_needed")
	COMPILATION_STEP(Strings::TextSubstitutions::allow_no_further_text_subs, I"Strings::TextSubstitutions::allow_no_further_text_subs")
	COMPILATION_STEP(PL::Parsing::Tokens::Filters::compile, I"PL::Parsing::Tokens::Filters::compile")
	COMPILATION_STEP(Chronology::past_actions_i6_routines, I"Chronology::past_actions_i6_routines")
	COMPILATION_STEP(Chronology::chronology_extents_i6_escape, I"Chronology::chronology_extents_i6_escape")
	COMPILATION_STEP(Chronology::past_tenses_i6_escape, I"Chronology::past_tenses_i6_escape")
	COMPILATION_STEP(Chronology::allow_no_further_past_tenses, I"Chronology::allow_no_further_past_tenses")
	COMPILATION_STEP(PL::Parsing::Verbs::compile_all, I"PL::Parsing::Verbs::compile_all")
	COMPILATION_STEP(PL::Parsing::Tokens::Filters::compile, I"PL::Parsing::Tokens::Filters::compile")
	COMPILATION_STEP(Properties::Measurement::compile_MADJ_routines, I"Properties::Measurement::compile_MADJ_routines")
	COMPILATION_STEP(Calculus::Propositions::Deferred::compile_remaining_deferred, I"Calculus::Propositions::Deferred::compile_remaining_deferred")
	COMPILATION_STEP(Calculus::Deferrals::allow_no_further_deferrals, I"Calculus::Deferrals::allow_no_further_deferrals")
	COMPILATION_STEP(Lists::check, I"Lists::check")
	COMPILATION_STEP(Lists::compile, I"Lists::compile")
	COMPILATION_STEP(Strings::TextLiterals::compile, I"Strings::TextLiterals::compile")
	COMPILATION_STEP(JumpLabels::compile_necessary_storage, I"JumpLabels::compile_necessary_storage")
	COMPILATION_STEP(Kinds::RunTime::compile_heap_allocator, I"Kinds::RunTime::compile_heap_allocator")
	COMPILATION_STEP(Phrases::Constants::compile_closures, I"Phrases::Constants::compile_closures")
	COMPILATION_STEP(Kinds::RunTime::compile_structures, I"Kinds::RunTime::compile_structures")
	COMPILATION_STEP(Rules::check_response_usages, I"Rules::check_response_usages")
	COMPILATION_STEP(Phrases::Timed::check_for_unused, I"Phrases::Timed::check_for_unused")
	COMPILATION_STEP(PL::Showme::compile_SHOWME_details, I"PL::Showme::compile_SHOWME_details")
	COMPILATION_STEP(Phrases::Timed::TimedEventsTable, I"Phrases::Timed::TimedEventsTable")
	COMPILATION_STEP(Phrases::Timed::TimedEventTimesTable, I"Phrases::Timed::TimedEventTimesTable")
	COMPILATION_STEP(Rules::export_named_rules, I"Rules::export_named_rules")

@<Convert inter to Inform 6@> =
	if ((problem_count == 0) && (existing_story_file == FALSE)) {
		CoreMain::go_to_log_phase(I"Converting inter to Inform 6");
		if (existing_story_file == FALSE) {
//			if (Emit::glob_count() > 0) internal_error("Glob count positive!");

			stage_set *SS = CodeGen::Stage::new_set();
			if ((import_mode) && (filename_of_SR_module))
				CodeGen::Stage::parse_into(SS, I"import:*",
					Filenames::get_leafname(filename_of_SR_module));
			else if ((export_mode) && (filename_of_SR_module))
				CodeGen::Stage::parse_into(SS, I"export:*",
					Filenames::get_leafname(filename_of_SR_module));
			CodeGen::Stage::parse_into(SS, inter_processing_chain,
				Filenames::get_leafname(filename_of_compiled_i6_code));
			CodeGen::Stage::follow(Filenames::get_path_to(filename_of_compiled_i6_code),
				SS, Emit::repository(), NO_FS_AREAS, pathname_of_i6t_files,
				pathname_of_i6t_files[INTERNAL_FS_AREA],
				pathname_of_i6t_files[INTERNAL_FS_AREA]);
		}
	}
	if (problem_count == 0) CoreMain::go_to_log_phase(I"Compilation now complete");

@ Metadata.

@<Generate metadata@> =
	PL::Bibliographic::Release::write_ifiction_and_blurb();
	if (problem_count == 0) {
		TemplateFiles::interpret(NULL, NULL, I"Index.i6t", -1);
	}

@<Post mortem logging@> =
	if (problem_count == 0) {
		TemplateReader::report_unacted_upon_interventions();
//		ParseTreeUsage::write_main_source_to_log();
//		Memory::log_statistics();
//		Preform::log_language();
//		Index::DocReferences::log_statistics();
//		NewVerbs::log_all();
	}

@<Shutdown and rennab@> =
	if (proceed) {
		Problems::write_reports(FALSE);

		LOG("Total of %d files written as streams.\n", total_file_writes);
		int cpu_time_used = ((int) (end - start)) / (CLOCKS_PER_SEC/100);
		LOG("CPU time: %d centiseconds\n", cpu_time_used);
		Writers::log_escape_usage();

		WRITE_TO(STDOUT, "%s has finished", HUMAN_READABLE_INTOOL_NAME);
		if (report_clock_time)
			WRITE_TO(STDOUT, ": %d centiseconds used", cpu_time_used);
		WRITE_TO(STDOUT, ".\n");
	}


@ =
int no_log_phases = 0;
void CoreMain::go_to_log_phase(text_stream *argument) {
	char *phase_names[] = {
		"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X",
		"XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI", "XXII" };
	Log::new_phase(phase_names[no_log_phases], argument);
	if (no_log_phases < 21) no_log_phases++;
}

@ =
void CoreMain::switch(int id, int val, text_stream *arg, void *state) {
	switch (id) {
		/* Miscellaneous boolean settings */
		case CENSUS_CLSW: census_mode = val; break;
		case CLOCK_CLSW: report_clock_time = val; break;
		case CRASHALL_CLSW: debugger_mode = val; crash_on_all_errors = val; break;
		case DEBUG_CLSW: this_is_a_debug_compile = val; break;
		case NOINDEX_CLSW: do_not_generate_index = val; break;
		case NOPROGRESS_CLSW: show_progress_indicator = val?FALSE:TRUE; break;
		case RELEASE_CLSW: this_is_a_release_compile = val; break;
		case RNG_CLSW:
			if (val) rng_seed_at_start_of_play = -16339;
			else rng_seed_at_start_of_play = 0;
			break;
		case SCORING_CLSW: default_scoring_setting = val; break;
		case SIGILS_CLSW: echo_problem_message_sigils = val; break;

		/* Other settings */
		case FORMAT_CLSW: story_filename_extension = Str::duplicate(arg); break;
		case CASE_CLSW: HTMLFiles::set_source_link_case(arg); break;
		case REQUIRE_PROBLEM_CLSW: Problems::Fatal::require(arg); break;
		case INTER_CLSW: inter_processing_chain = Str::duplicate(arg); break;

		/* Useful pathnames */
		case PROJECT_CLSW: Locations::set_project(arg); break;
		case INTERNAL_CLSW: Locations::set_internal(arg); break;
		case EXTERNAL_CLSW: Locations::set_external(arg); break;
		case TRANSIENT_CLSW: Locations::set_transient(arg); break;
		case IMPORT_CLSW: if (disable_import == FALSE) { import_mode = TRUE; Locations::set_SR_module(arg); } break;
		case EXPORT_CLSW: export_mode = TRUE; Locations::set_SR_module(arg); break;

		default: internal_error("unimplemented switch");
	}
}

void CoreMain::bareword(int id, text_stream *opt, void *state) {
	if (Locations::set_I7_source(opt) == FALSE)
		Errors::fatal_with_text("unknown command line argument: %S (see -help)", opt);
}

void CoreMain::disable_importation(void) {
	disable_import = TRUE;
	import_mode = FALSE;
}

void CoreMain::set_inter_chain(wording W) {
	inter_processing_chain = Str::new();
	WRITE_TO(inter_processing_chain, "%W", W);
	Str::delete_first_character(inter_processing_chain);
	Str::delete_last_character(inter_processing_chain);
	LOG("Setting chain %S\n", inter_processing_chain);
	int port = CodeGen::Stage::port(inter_processing_chain);
	if (port == 1) export_mode = TRUE;
	if ((port == -1) && (disable_import == FALSE)) import_mode = TRUE;
}