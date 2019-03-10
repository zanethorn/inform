Title: core
Author: Graham Nelson
Purpose: The core of the Inform compiler, as a module.
Language: InC
Declare Section Usage: Off
Web Syntax Version: 2
Licence: Artistic License 2.0

Chapter 1: Configuration and Control
"The chief executive: the main routine through which Inform 7 begins
execution, and which reads command-line switches supplied by its customers."
	Main Routine
	Core Module
	Progress Percentages
	Where Everything Lives

Chapter 2: Bridge to Problems Module
"The issuing of Problem messages, and the debugging log file."
	Using Problems
	Supplementary Quotes
	Supplementary Issues

Chapter 3: Bridge to Words Module
"Reading source text as a stream of characters and dividing it up into words."
	Read Source Text
	Natural Languages
	Plural Dictionary

Chapter 4: Bridge to Linguistics Module
"Miscellaneous grammatical features other than nouns, verbs and adjectives."
	Introduction to Semantics
	Adjective Meanings

Chapter 5: Nouns
"Nouns, mainly proper, and notations for constant values such as 10:03 AM, six,
34 kg, and so on."
	Literal Patterns
	Times of Day
	Using Excerpt Meanings
	Unicode Translations
	Using Nametags
	Instances
	Nonlocal Variables
	Index Physical World

Chapter 6: Verbs
"Verbs which establish relationships between nouns, and which give meaning
to binary predicates."
	Binary Predicates
	Relations
	Explicit Relations
	The Universal Relation
	New Verbs

Chapter 7: Sentences
"In which the stream of words is broken up into sentences and built into a
parse tree, recording primary verbs, noun phrases and some sub-clauses; and in
which these sentences are collected under a hierarchy of headings, with
material intended only for certain target virtual machines included or
excluded as need be."
	Parse Tree Usage
	Structural Sentences
	Headings
	Nonstructural Sentences
	Of and From
	Rule Subtrees

Chapter 8: Extensions
"Extensions of more sentences must be Included as requested; because of
which, we also handle extension installation, uninstallation and
documentation here."
	Extension Files
	Including Extensions
	Extension Identifiers
	Extension Census
	Extension Dictionary
	Extension Documentation

Chapter 9: The A-Parser
"We work through the assertion sentences in the parse tree one by one, and
formulate logical propositions which must be true statements about the model
world."
	Introduction to Assertions
	Traverse for Assertions
	To Be and To Have
	Refine Parse Tree
	The Creator
	Make Assertions
	Property Knowledge
	Relation Knowledge
	Assemblies
	Implications
	Property Declarations

Chapter 10: The S-Parser
"In which the S-parser is put to work: excerpts of several words at a time
are assigned meanings, and compound statements formed of these are parsed,
producing lists of possible interpretations."
	Architecture of the S-Parser
	Parse Literals
	Constants and Descriptions
	Type Expressions and Values
	Verbal and Relative Clauses
	Conditions and Phrases

Chapter 11: Predicate Calculus
"In which the meaning of an S-parsed sentence is converted to a statement
in predicate calculus, so that verbs and prepositions become relations, while
determiners express quantifiers; this produces a mathematical proposition
which can be simplified according to logical rules which change its form
but not its meaning."
	Introduction to Predicate Calculus
	Terms
	Atomic Propositions
	Propositions
	Binding and Substitution
	Tree Conversions
	Sentence Conversions
	Simplifications
	Type Check Propositions

Chapter 12: Use of Propositions
"This is where the propositions generated by the A-parser and the S-parser
are at last acted upon, either immediately (generating inferences) or at
run-time (by causing code to be compiled which will some day test or assert
the truth of the proposition)."
	The Equality Relation
	Quasinumeric Relations
	Assert Propositions
	I6 Schemas
	Compile Atoms
	Deciding to Defer
	Cinders and Deferrals
	Compile Deferred Propositions

Chapter 13: Bridge to Kinds Module
"In which values are categorised by their natures, and these in turn occupy
a hierarchy."
	Knowledge about Kinds
	Compile Arithmetic
	Runtime Support for Kinds
	Kinds Index

Chapter 14: Specifications
"In which the meanings of excerpts are systematically catalogued according to
what they specify; a categorisation much broader than working out kinds of
value, since it applies to a much broader range of excerpts than values."
	Value Holsters
	Specifications
	Rvalues
	Lvalues
	Conditions
	Descriptions
	Compiling from Specifications
	Dash

Chapter 15: Properties
"Properties are named values attached to elements of the world model; not only
objects, but also other enumerated constant values, and so on."
	Properties
	Either-Or Properties
	Valued Properties
	Condition Properties
	Indefinite Appearance
	The Provision Relation
	Measurement Adjectives
	Comparative Relations
	Same Property Relation
	Setting Property Relation
	Properties of Values
	Emit Property Values

Chapter 16: Inference and Model
"Having now essentially disposed of the original assertion sentences by
converting them to propositions, which in turn generated basic inferences
about the model world, we must now resolve this mass of facts, applying
Occam's Razor to construct the simplest explicit model of the world which
fits this knowledge."
	Inference Subjects
	Property Permissions
	Inferences
	Complete Model World
	Compile Model World
	Instance Counting

Chapter 17: Text Data
"Text literals, which may be constant strings, or may be functions in order
to implement substitutions."
	Text Literals
	Text Substitutions
	Responses

Chapter 18: List Data
"List literals."
	List Constants

Chapter 19: Table Data
"Inform's preferred data structure for small initialised databases."
	Table Columns
	Tables
	Runtime Support for Tables
	Tables of Definitions
	Listed-In Relations

Chapter 20: Equations
"Simple mathematical or scientific equations, which can be solved at run-time."
	Equations

Chapter 21: Rules and Rulebooks
"Rules are named phrases which are invoked in a particular way, and rulebooks
a way to organise lists of them."
	Rules
	Rule Bookings
	Rulebooks
	Focus and Outcome
	Rule Placement Sentences
	Stacked Variables
	Activities

Chapter 22: Phrases
"In which rules, To... phrases (and similar explicit instructions to do
with specific changes in the world) have their preambles parsed and their
premisses worked out, and are then collected together into rulebooks, before
being compiled as a great mass of Inform 6 routines and arrays."
	Introduction to Phrases
	Construction Sequence
	Phrases
	Phrase Usage
	Phrase Runtime Context Data
	Phrase Type Data
	Describing Phrase Type Data
	Phrase Options
	Phrases as Values
	To Phrases
	Timed Phrases
	Phrasebook Index

Chapter 23: Calculated Adjectives
"Adjectives whose truth or falsity at run-time has to be determined by
running code."
	Adjectival Definitions
	Adjectives by Raw Phrase
	Adjectives by Raw Condition
	Adjectives by Phrase
	Adjectives by Condition

Chapter 24: Compilation Context
"Preparing a context at run-time in which code can be executed: creating
local variables, and so on."
	Local Variables
	Phrase Blocks
	Stack Frames
	Chronology

Chapter 25: Compilation
"Generating code to perform individual phrases."
	Invocations
	Parse Invocations
	Compile Invocations
	Compile Invocations As Calls
	Compile Invocations Inline
	Compile Phrases

Chapter 26: Compilation Utilities
"Mainly low-level utilities for compiling code."
	Virtual Machines
	Inform 6 Inclusions
	Use Options
	List Together
	Jump Labels
	Compiled Text
	Routines
	Translate to Identifiers
	I6 Template Interpreter
	Plugins
	Plugin Calls
	Test Scripts

Chapter 27: Bridge to Inter Module
"Emitting Inter code ready for the code-generator."
	Inter Schemas
	Emit
	Compilation Modules
	Inter Namespace
	Packaging