[Phrases::] Introduction to Phrases.

An exposition of the data structures used inside Inform to hold
phrases, rules and rulebooks.

@ A good deal of Inform source text consists of phrase declarations of one
kind or another, consisting of a preamble, then a colon (except in a few
cases where commas are permitted) and then a list of instructions about what
to do, which is normally a series of phrase invocations divided by
semicolons.

The usual dictionary definition of "phrase" is "a small group of words
standing together as a conceptual unit, typically forming a component of a
clause", but we've used the word "excerpt" for that. Instead, every Inform
phrase definition reads back grammatically as a single complete sentence,
even when quite long and written out in a tabulated, computer language sort
of form: rather as Philip Larkin's poem {\it MCMIV} is a single sentence
through all four stanzas. For example:

>> To award (N - a number) points: increase the score by N; say "Well done!"

is a phrase definition. When we talk about "award (N - a number) points",
we will call it a "phrase". When we run into a specific usage of it, like

>> award 21 points;

this is called an "invocation" of the phrase rather than being the phrase
itself. The difference between a phrase and an invocation is like the
difference in conventional programming languages between a function and
a function call.

"Award (N - a number) points" is called a "To... phrase", because it is
defined using "To", and takes effect only when it's invoked from another
phrase. But not all phrases look like this. There are also rules:

>> Before eating the cake, say "Look out! Marzipan!"

This example isn't as different as it looks, and the main difference
is simply that "To..." phrases take effect when invoked whereas rule phrases
take effect when the circumstances laid out in the preamble are found --
in this case, just before the action "eating the cake" is about be tried.
Inside Inform, "To..." phrases and rules have much in common, and both
are stored in "phrase" structures.

@ Every phrase is defined either as a list of invocations of phrases to
do something, or as a piece of primitive I6 code. The latter case is rare,
and mostly confined to the Standard Rules. But here is an example:

>> To alter score by (N - number): |(- score = score + {N}; -)|.

When we compile an invocation of a phrase like "award (N - a number) points",
it becomes a call to an I6 function, say |R_231(N);|. To make that work, of
course, we need to turn the definition into a function looking something
like this:

	|[ R_231 N;|
	|	increase the score by N;|
	|	say "Well done!";|
	|	rtrue;|
	|];|

Devising this |R_231| function is called "compiling" the phrase. On the
other hand, compiling an invocation of "alter score by (some - number)"
is done inline rather than by a function call: the I6 code from its definition
is used directly. So there is no such thing as "compiling" such a phrase.

Rule phrases cannot be given inline definitions, but they can be defined
as being the same as I6 routines from the template. So both kinds of phrase
can be defined in either a high-level way, invoking a series of other
phrases to get something done, or in a low-level way, as primitives written
directly in I6 code.

@ Each declaration corresponds to a |phrase| structure. This is an anthology
of five sub-structures for different purposes: PHUD, PHTD, PHSF, PHRCD and
PHOD. The data in these structures is used to represent the information
in the preamble, and also information needed during compilation of the
body of the declaration (local variable names which come and go, for
instance).

Further structures represent individual local variables (|local_variable|)
within PHSFs, and individual phrase options (|phrase_option|) within PHODs.

In the case of rules, the |phrase| structure is associated with a |rule|
structure. Not all rules are placed in rulebooks, but for those that are,
a structure called a |booking| is used to keep track of this. Rulebooks
are in turn stored as |rulebook| structures. The next chapter goes into
this much more fully.

@ So the |phrase| structure has five substructures, whose names are
abbreviated as PHUD, PHTD, PHSF, PHRCD and PHOD.

(i) The phrase usage data (PHUD) contains the results of parsing the
preamble of the declaration to see what kind of phrase is to be created.
For "To..." phrases, little is recorded. For rules, the PHUD contains
all the information needed to place the rule within its rulebook.

(ii) Conversely, the phrase type data (PHTD) is primarily useful for
"To..." phrases. It records the pattern of text to be registered as
an excerpt with the excerpt parser, and the kinds required for the
tokens in the definition. For example, it records that the kind of
"alter score by (N - number)" is:

	|phrase number -> nothing|

and that the first "token", the number supplied, is called "N".

(iii) The phrase options data (PHOD) contains the names of phrase options,
if any apply, and whether or not they are mutually exclusive. It is used
only for "To..." phrases, and is separated from the PHTD because it
is parsed separately and isn't used in kind-checking.

(iv) The phrase run-time context data (PHRCD) contains data structures
which store the fully-parsed preamble. This is of use only with rules,
and contains (for instance) the parameter to be used when placing the
rule into its rulebook -- an action pattern structure. When such phrases
are created, they sometimes become rules which are bound up into rulebooks.
Rules in rulebooks are sorted into order of specificity, and this judgement
is made on the contents of the PHRCD alone. As we'll see, it's possible
for the same phrase to appear as several different rules in different
rulebooks; or, in the case of "To..." phrases, not to be a rule at all.

(v) The phrase stack frame (PHSF) contains the local named values valid in a
given compilation context. (Names of phrase options can also be used locally
and for this the PHOD is used, but they are conditions not values.) These
named values include both local variables created with invocations like
"let F be 10;" and token names such as "N".

Uniquely of the five substructures of |phrase|, the PHSF can exist
independently of any |phrase| structure in more than a temporary way.
Free-standing PHSF stack frames are used when compiling text which
contains substitutions, and for other code-compilation purposes where
code does not arise explicitly from phrase declarations in the source.

To sum up, a "to..." phrase makes use of a PHUD (minimally), a PHTD
(for sorting, registration and type-checking), a PHOD, and a PHSF.
A rule phrase makes use of a PHUD (more heavily), a PHRCD (for sorting
and to compile checks on applicability), and a PHSF.

The obvious simplification in this scheme would be to include the
PHRCD within the PHUD, and the PHOD within the PHTD, thus reducing the
picture to just three structures. We do not do this because there are
significant timing difficulties.