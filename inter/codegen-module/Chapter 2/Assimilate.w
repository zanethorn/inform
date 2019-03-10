[CodeGen::Assimilate::] Assimilate Linked Matter.

To generate the initial state of storage for variables.

@h Parsing.

=
int assim_verb_count = 0;
void CodeGen::Assimilate::assimilate(inter_reading_state *IRS) {
	inter_repository *I = IRS->read_into;
//	inter_symbols_table *into_scope = Inter::Packages::scope(Inter::Packages::main(IRS->read_into));
	inter_frame P;
	LOOP_THROUGH_FRAMES(P, I) {
		inter_package *outer = Inter::Packages::container(P);
		inter_symbols_table *into_scope = Inter::Packages::scope(outer);
		if (((outer == NULL) || (outer->codelike_package == FALSE)) &&
			(P.data[ID_IFLD] == SPLAT_IST)) {
			IRS->current_package = outer;
			IRS->cp_indent = Inter::Packages::baseline(outer);
			inter_t baseline = (inter_t) IRS->cp_indent + 1;
			if (outer == NULL) baseline = 0;
			switch (P.data[PLM_SPLAT_IFLD]) {
				case PROPERTY_PLM:
					if (unchecked_kind_symbol) @<Assimilate definition@>;
					break;
				case ATTRIBUTE_PLM:
					if (truth_state_kind_symbol) @<Assimilate definition@>;
					break;
				case ROUTINE_PLM:
				case STUB_PLM:
					if ((unchecked_kind_symbol) && (unchecked_function_symbol)) @<Assimilate routine@>;
					break;
			}
		}
	}
	LOOP_THROUGH_FRAMES(P, I) {
		inter_package *outer = Inter::Packages::container(P);
		if (((outer == NULL) || (outer->codelike_package == FALSE)) &&
			(P.data[ID_IFLD] == SPLAT_IST)) {
			IRS->current_package = outer;
			inter_symbols_table *into_scope = Inter::Packages::scope(outer);
			IRS->cp_indent = Inter::Packages::baseline(outer);
			inter_t baseline = (inter_t) IRS->cp_indent + 1;
			if (outer == NULL) baseline = 0;
			switch (P.data[PLM_SPLAT_IFLD]) {
				case DEFAULT_PLM:
				case CONSTANT_PLM:
				case VERB_PLM:
					if (unchecked_kind_symbol) @<Assimilate definition@>;
					break;
				case ARRAY_PLM:
					if (list_of_unchecked_kind_symbol) @<Assimilate definition@>;
					break;
			}
		}
	}
	LOOP_THROUGH_FRAMES(P, I) {
		inter_package *outer = Inter::Packages::container(P);
		if (((outer == NULL) || (outer->codelike_package == FALSE)) &&
			(P.data[ID_IFLD] == SPLAT_IST)) {
			IRS->current_package = outer;
			IRS->cp_indent = Inter::Packages::baseline(outer);
			inter_symbols_table *into_scope = Inter::Packages::scope(outer);
			inter_t baseline = (inter_t) IRS->cp_indent + 1;
			if (outer == NULL) baseline = 0;
			switch (P.data[PLM_SPLAT_IFLD]) {
				case GLOBAL_PLM:
					if (unchecked_kind_symbol) @<Assimilate definition@>;
					break;
			}
		}
	}
}

@

@d MAX_ASSIMILATED_ARRAY_ENTRIES 2048

@<Assimilate definition@> =
	text_stream *identifier = NULL;
	text_stream *value = NULL;
	match_results mr = Regexp::create_mr();
	text_stream *S = Inter::get_text(P.repo_segment->owning_repo, P.data[MATTER_SPLAT_IFLD]);
	if (P.data[PLM_SPLAT_IFLD] != VERB_PLM) {
		if (Regexp::match(&mr, S, L" *%C+ *(%C+?)(--> *%c*?) *;%c*")) {
			identifier = mr.exp[0]; value = mr.exp[1];
		} else if (Regexp::match(&mr, S, L" *%C+ *(%C+?)(-> *%c*?) *;%c*")) {
			identifier = mr.exp[0]; value = mr.exp[1];
		} else if (Regexp::match(&mr, S, L" *%C+ (%C*?) *;%c*")) {
			identifier = mr.exp[0];
		} else if (Regexp::match(&mr, S, L" *%C+ (%C*) *= *(%c*?) *;%c*")) {
			identifier = mr.exp[0]; value = mr.exp[1];
		} else if (Regexp::match(&mr, S, L" *%C+ (%C*) (%c*?) *;%c*")) {
			identifier = mr.exp[0]; value = mr.exp[1];
		} else LOG("Stuck on this! %S\n", S);
	} else {
		identifier = Str::new();
		WRITE_TO(identifier, "assim_verb_%d", ++assim_verb_count);
		if (Regexp::match(&mr, S, L" *%C+ (%c*?) *;%c*")) {
			value = mr.exp[0];
		} else LOG("Stuck on this! %S\n", S);
	}

		inter_reading_state ib = Inter::Bookmarks::snapshot(IRS);
		ib.in_frame_list = &(I->sequence);
		ib.pos = P_entry;

	if ((identifier) && (unchecked_kind_symbol)) {
		Str::trim_all_white_space_at_end(identifier);
		inter_t switch_on = P.data[PLM_SPLAT_IFLD];

		if (switch_on == DEFAULT_PLM) {
			inter_symbol *symbol = CodeGen::Link::find_name(I, identifier);
			if (symbol == NULL) switch_on = CONSTANT_PLM;
		}

		if (switch_on != DEFAULT_PLM) {
			inter_symbol *con_name = CodeGen::Assimilate::maybe_extern(I, identifier, into_scope);
			Inter::Symbols::annotate_i(I, con_name, ASSIMILATED_IANN, 1);

			if (con_name->equated_to) {
				inter_symbol *external_name = con_name->equated_to;
				external_name->equated_to = con_name;
				con_name->equated_to = NULL;
			}

			inter_t v1 = 0, v2 = 0;

			switch (switch_on) {
				case CONSTANT_PLM:
					@<Assimilate a value@>;
					CodeGen::Link::guard(Inter::Constant::new_numerical(&ib,
						Inter::SymbolsTables::id_from_symbol(I, outer, con_name),
						Inter::SymbolsTables::id_from_symbol(I, outer, unchecked_kind_symbol), v1, v2,
						baseline, NULL));
					break;
				case GLOBAL_PLM:
					@<Assimilate a value@>;
					CodeGen::Link::guard(Inter::Variable::new(&ib,
						Inter::SymbolsTables::id_from_symbol(I, outer, con_name),
						Inter::SymbolsTables::id_from_symbol(I, outer, unchecked_kind_symbol), v1, v2,
						baseline, NULL));
					break;
				case ATTRIBUTE_PLM:
					CodeGen::Link::guard(Inter::Property::new(&ib,
						Inter::SymbolsTables::id_from_symbol(I, outer, con_name),
						Inter::SymbolsTables::id_from_symbol(I, outer, truth_state_kind_symbol),
						baseline, NULL));
					Inter::Symbols::annotate_i(I, con_name, ATTRIBUTE_IANN, 1);
					Inter::Symbols::annotate_i(I, con_name, EITHER_OR_IANN, 1);
					Inter::Symbols::set_translate(con_name, con_name->symbol_name);
					break;
				case PROPERTY_PLM:
					CodeGen::Link::guard(Inter::Property::new(&ib,
						Inter::SymbolsTables::id_from_symbol(I, outer, con_name),
						Inter::SymbolsTables::id_from_symbol(I, outer, unchecked_kind_symbol),
						baseline, NULL));
					break;
				case VERB_PLM:
				case ARRAY_PLM: {
					inter_t annot = 0;
					match_results mr2 = Regexp::create_mr();
					text_stream *conts = NULL;
					if (P.data[PLM_SPLAT_IFLD] == ARRAY_PLM) {
						if (Regexp::match(&mr2, value, L" *--> *(%c*?) *")) conts = mr2.exp[0];
						else if (Regexp::match(&mr2, value, L" *-> *(%c*?) *")) { conts = mr2.exp[0]; annot = BYTEARRAY_IANN; }
						else if (Regexp::match(&mr2, value, L" *table *(%c*?) *")) { conts = mr2.exp[0]; annot = TABLEARRAY_IANN; }
						else if (Regexp::match(&mr2, value, L" *buffer *(%c*?) *")) { conts = mr2.exp[0]; annot = BUFFERARRAY_IANN; }
						else {
							LOG("Identifier = <%S>, Value = <%S>", identifier, value);
							TemplateReader::error("invalid Inform 6 array declaration in the template", NULL);
						}
					} else {
						conts = value; annot = VERBARRAY_IANN;
					}

					Inter::Symbols::annotate_i(I, con_name, MISCELLANY_IANN, 0);
					if (annot != 0) Inter::Symbols::annotate_i(I, con_name, annot, 1);

					inter_t v1_pile[MAX_ASSIMILATED_ARRAY_ENTRIES];
					inter_t v2_pile[MAX_ASSIMILATED_ARRAY_ENTRIES];
					int no_assimilated_array_entries = 0;

					string_position spos = Str::start(conts);
					int NT = 0, next_is_action = FALSE;
					while (TRUE) {
						TEMPORARY_TEXT(value);
						if (next_is_action) WRITE_TO(value, "##");
						@<Extract a token@>;
						if ((next_is_action) && (action_kind_symbol)) {
							if (CodeGen::Link::find_name(I, value) == NULL) {
								inter_symbol *asymb = CodeGen::Assimilate::maybe_extern(I, value, into_scope);
								CodeGen::Link::guard(Inter::Constant::new_numerical(&ib,
									Inter::SymbolsTables::id_from_symbol(I, outer, asymb),
									Inter::SymbolsTables::id_from_symbol(I, outer, action_kind_symbol),
									LITERAL_IVAL, 10000, baseline, NULL));
								Inter::Symbols::annotate_i(I, asymb, ACTION_IANN, 1);
							}
						}
						next_is_action = FALSE;
						if (P.data[PLM_SPLAT_IFLD] == ARRAY_PLM) {
							if (Str::eq(value, I"+")) TemplateReader::error("Inform 6 array declaration in the template using operator '+'", NULL);
							if (Str::eq(value, I"-")) TemplateReader::error("Inform 6 array declaration in the template using operator '-'", NULL);
							if (Str::eq(value, I"*")) TemplateReader::error("Inform 6 array declaration in the template using operator '*'", NULL);
							if (Str::eq(value, I"/")) TemplateReader::error("Inform 6 array declaration in the template using operator '/'", NULL);
						}
						if ((NT == 0) && (P.data[PLM_SPLAT_IFLD] == VERB_PLM) && (Str::eq(value, I"meta"))) {
							Inter::Symbols::annotate_i(I, con_name, METAVERB_IANN, 1);
						} else {
							@<Assimilate a value@>;
							if (Str::len(value) == 0) break;
							NT++;
							if (no_assimilated_array_entries >= MAX_ASSIMILATED_ARRAY_ENTRIES) {
								TemplateReader::error("excessively long Inform 6 array in the template", NULL);
								break;
							}
							v1_pile[no_assimilated_array_entries] = v1;
							v2_pile[no_assimilated_array_entries] = v2;
							no_assimilated_array_entries++;
							if ((P.data[PLM_SPLAT_IFLD] == VERB_PLM) && (verb_directive_result_symbol) &&
								(Inter::SymbolsTables::symbol_from_data_pair_and_table(v1, v2, into_scope) == verb_directive_result_symbol))
								next_is_action = TRUE;
						}
						DISCARD_TEXT(value);
					}

					inter_frame array_in_progress =
						Inter::Frame::fill_3(&ib, CONSTANT_IST,
							Inter::SymbolsTables::id_from_symbol(I, outer, con_name),
							Inter::SymbolsTables::id_from_symbol(I, outer, list_of_unchecked_kind_symbol),
							CONSTANT_INDIRECT_LIST, NULL, baseline);
					int pos = array_in_progress.extent;
					if (Inter::Frame::extend(&array_in_progress, (unsigned int) (2*no_assimilated_array_entries)) == FALSE)
						internal_error("can't extend frame");
					for (int i=0; i<no_assimilated_array_entries; i++) {
						array_in_progress.data[pos++] = v1_pile[i];
						array_in_progress.data[pos++] = v2_pile[i];
					}
					CodeGen::Link::guard(Inter::Defn::verify_construct(array_in_progress));
					Inter::Frame::insert(array_in_progress, &ib);
					break;
				}
			}
		}
		Inter::Nop::nop_out(I, P);
	}

@<Extract a token@> =
	int squoted = FALSE, dquoted = FALSE, bracketed = 0;
	while ((Str::in_range(spos)) && (Characters::is_whitespace(Str::get(spos))))
		spos = Str::forward(spos);
	while (Str::in_range(spos)) {
		wchar_t c = Str::get(spos);
		if ((Characters::is_whitespace(c)) && (squoted == FALSE) && (dquoted == FALSE) && (bracketed == 0)) break;
		if ((c == '\'') && (dquoted == FALSE)) squoted = (squoted)?FALSE:TRUE;
		if ((c == '\"') && (squoted == FALSE)) dquoted = (dquoted)?FALSE:TRUE;
		if ((c == '(') && (dquoted == FALSE) && (squoted == FALSE)) bracketed++;
		if ((c == ')') && (dquoted == FALSE) && (squoted == FALSE)) bracketed--;
		PUT_TO(value, c);
		spos = Str::forward(spos);
	}

@<Assimilate a value@> =
	if (Str::len(value) > 0) {
		CodeGen::Assimilate::value(I, outer, value, &v1, &v2,
			(switch_on == VERB_PLM)?TRUE:FALSE);
	} else {
		v1 = LITERAL_IVAL; v2 = 0;
	}

@<Assimilate routine@> =
	text_stream *identifier = NULL;
	text_stream *chain = NULL;
	text_stream *body = NULL;
	match_results mr = Regexp::create_mr();
	text_stream *S = Inter::get_text(P.repo_segment->owning_repo, P.data[MATTER_SPLAT_IFLD]);
	if (P.data[PLM_SPLAT_IFLD] == ROUTINE_PLM) {
		if (Regexp::match(&mr, S, L" *%[ *(%i+) *; *(%c*)")) {
			identifier = mr.exp[0]; body = mr.exp[1];
		} else if (Regexp::match(&mr, S, L" *%[ *(%i+) *(%c*?); *(%c*)")) {
			identifier = mr.exp[0]; chain = mr.exp[1]; body = mr.exp[2];
		} else {
			TemplateReader::error("invalid Inform 6 routine declaration in the template", NULL);
		}
	} else {
		if (Regexp::match(&mr, S, L" *%C+ *(%i+) (%d+);%c*")) {
			identifier = mr.exp[0];
			chain = Str::new();
			int N = Str::atoi(mr.exp[1], 0);
			if ((N<0) || (N>15)) N = 1;
			for (int i=1; i<=N; i++) WRITE_TO(chain, "x%d ", i);
			body = Str::duplicate(I"rfalse; ];");
		} else TemplateReader::error("invalid Inform 6 Stub declaration in the template", NULL);
	}
	if (identifier) {
		TEMPORARY_TEXT(bname);
		WRITE_TO(bname, "%S_B", identifier);
		inter_symbol *block_name = Inter::SymbolsTables::create_with_unique_name(into_scope, bname);
		DISCARD_TEXT(bname);

		inter_reading_state ib = Inter::Bookmarks::snapshot(IRS);
		ib.in_frame_list = &(I->sequence);
		ib.pos = P_entry;

		inter_package *IP = NULL;
		CodeGen::Link::guard(Inter::Package::new_package(&ib, block_name,
			code_packagetype, baseline, NULL, &IP));

		Inter::Defn::set_current_package(&ib, IP);
		inter_reading_state block_bookmark = ib;

		int var_count = 0;
		if (chain) {
			string_position spos = Str::start(chain);
			while (TRUE) {
				TEMPORARY_TEXT(value);
				@<Extract a token@>;
				if (Str::len(value) == 0) break;
				var_count++;

				inter_symbol *loc_name = Inter::SymbolsTables::create_with_unique_name(Inter::Package::local_symbols(block_name), value);
				CodeGen::Link::guard(Inter::Local::new(&ib, block_name, loc_name, unchecked_kind_symbol, 0, baseline+1, NULL));

				DISCARD_TEXT(value);
			}
		}

		inter_symbol *begin_name = Inter::SymbolsTables::create_with_unique_name(Inter::Package::local_symbols(block_name), I".begin");
		inter_symbol *end_name = Inter::SymbolsTables::create_with_unique_name(Inter::Package::local_symbols(block_name), I".end");
		Inter::Symbols::label(begin_name);
		Inter::Symbols::label(end_name);

		CodeGen::Link::guard(Inter::Label::new(&ib, block_name, begin_name, baseline+1, NULL));

		if (Str::len(body) > 0) {
			int L = Str::len(body) - 1;
			while ((L>0) && (Str::get_at(body, L) != ']')) L--;
			while ((L>0) && (Characters::is_whitespace(Str::get_at(body, L-1)))) L--;
			Str::truncate(body, L);
			CodeGen::Link::entire_splat(&ib, NULL, body, baseline+2, block_name);
		}

		CodeGen::Link::guard(Inter::Label::new(&ib, block_name, end_name, baseline+1, NULL));

		CodeGen::Link::guard(Inter::Defn::pass2(I, FALSE, &block_bookmark, TRUE, (int) baseline));

		Inter::Defn::unset_current_package(&ib, IP, 0);

		inter_symbol *rsymb = CodeGen::Assimilate::maybe_extern(I, identifier, into_scope);
		Inter::Symbols::annotate_i(I, rsymb, ASSIMILATED_IANN, 1);
		CodeGen::Link::guard(Inter::Constant::new_function(&ib,
			Inter::SymbolsTables::id_from_symbol(I, outer, rsymb), Inter::SymbolsTables::id_from_symbol(I, outer, unchecked_function_symbol),
			Inter::SymbolsTables::id_from_symbol(I, outer, block_name), baseline, NULL));

		Inter::Nop::nop_out(I, P);
	}

@ =
inter_symbol *CodeGen::Assimilate::maybe_extern(inter_repository *I, text_stream *identifier, inter_symbols_table *into_scope) {
	inter_symbol *rsymb = CodeGen::Link::find_name(I, identifier);
	if (rsymb) {
		if (Inter::Symbols::is_extern(rsymb)) {
			if (rsymb->definition_status == DEFINED_ISYMD) {
				inter_frame Q = Inter::Symbols::defining_frame(rsymb);
				Inter::Symbols::undefine(rsymb);
				Inter::Nop::nop_out(I, Q);
				if (rsymb->owning_table != into_scope) {
					inter_symbol *nsymb = Inter::SymbolsTables::create_with_unique_name(into_scope, identifier);
					Inter::SymbolsTables::equate(rsymb, nsymb);
					rsymb = nsymb;
				}
			} else {
				if (rsymb->owning_table != into_scope) {
					inter_symbol *nsymb = Inter::SymbolsTables::create_with_unique_name(into_scope, identifier);
					Inter::SymbolsTables::equate(rsymb, nsymb);
					rsymb = nsymb;
				}
			}
		} else {
			if (rsymb->owning_table != into_scope) {
				inter_frame Q = Inter::Symbols::defining_frame(rsymb);
				if (Inter::Frame::valid(&Q)) {
					Inter::Symbols::undefine(rsymb);
					Inter::Nop::nop_out(I, Q);
				}
				inter_symbol *nsymb = Inter::SymbolsTables::create_with_unique_name(into_scope, identifier);
				Inter::SymbolsTables::equate(rsymb, nsymb);
				rsymb = nsymb;
			}
			if (Inter::Symbols::is_predeclared(rsymb)) return rsymb;
			rsymb = NULL;
		}
	}
	if (rsymb == NULL) {
		rsymb = Inter::SymbolsTables::create_with_unique_name(into_scope, identifier);
	}
	return rsymb;
}

@ =
void CodeGen::Assimilate::value(inter_repository *I, inter_package *pack, text_stream *S, inter_t *val1, inter_t *val2, int Verbal) {
	int sign = 1, base = 10, from = 0, to = Str::len(S)-1, bad = FALSE;
	if ((Str::get_at(S, from) == '\'') && (Str::get_at(S, to) == '\'')) {
		from++;
		to--;
		TEMPORARY_TEXT(dw);
		LOOP_THROUGH_TEXT(pos, S) {
			if (pos.index < from) continue;
			if (pos.index > to) continue;
			int c = Str::get(pos);
			PUT_TO(dw, c);
		}
		inter_t ID = Inter::create_text(I);
		text_stream *glob_storage = Inter::get_text(I, ID);
		Str::copy(glob_storage, dw);
		*val1 = DWORD_IVAL; *val2 = ID;
		DISCARD_TEXT(dw);
		return;
	}
	if ((Str::get_at(S, from) == '"') && (Str::get_at(S, to) == '"')) {
		from++;
		to--;
		TEMPORARY_TEXT(dw);
		LOOP_THROUGH_TEXT(pos, S) {
			if (pos.index < from) continue;
			if (pos.index > to) continue;
			int c = Str::get(pos);
			PUT_TO(dw, c);
		}
		inter_t ID = Inter::create_text(I);
		text_stream *glob_storage = Inter::get_text(I, ID);
		Str::copy(glob_storage, dw);
		*val1 = LITERAL_TEXT_IVAL; *val2 = ID;
		DISCARD_TEXT(dw);
		return;
	}
	if ((Str::get_at(S, from) == '(') && (Str::get_at(S, to) == ')')) { from++; to--; }
	while (Characters::is_whitespace(Str::get_at(S, from))) from++;
	while (Characters::is_whitespace(Str::get_at(S, to))) to--;
	if (Str::get_at(S, from) == '-') { sign = -1; from++; }
	else if (Str::get_at(S, from) == '$') {
		from++; base = 16;
		if (Str::get_at(S, from) == '$') {
			from++; base = 2;
		}
	}
	long long int N = 0;
	LOOP_THROUGH_TEXT(pos, S) {
		if (pos.index < from) continue;
		if (pos.index > to) continue;
		int c = Str::get(pos), d = 0;
		if ((c >= 'a') && (c <= 'z')) d = c-'a'+10;
		else if ((c >= 'A') && (c <= 'Z')) d = c-'A'+10;
		else if ((c >= '0') && (c <= '9')) d = c-'0';
		else { bad = TRUE; break; }
		if (d > base) { bad = TRUE; break; }
		N = base*N + (long long int) d;
		if (pos.index > 34) { bad = TRUE; break; }
	}
	if (bad == FALSE) {
		N = sign*N;
		*val1 = LITERAL_IVAL; *val2 = (inter_t) N; return;
	}
	if (Str::eq(S, I"true")) {
		*val1 = LITERAL_IVAL; *val2 = 1; return;
	}
	if (Str::eq(S, I"false")) {
		*val1 = LITERAL_IVAL; *val2 = 0; return;
	}
	if (Verbal) {
		if ((Str::eq(S, I"*")) && (verb_directive_divider_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_divider_symbol, val1, val2); return;
		}
		if ((Str::eq(S, I"->")) && (verb_directive_result_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_result_symbol, val1, val2); return;
		}
		if ((Str::eq(S, I"reverse")) && (verb_directive_reverse_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_reverse_symbol, val1, val2); return;
		}
		if ((Str::eq(S, I"/")) && (verb_directive_slash_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_slash_symbol, val1, val2); return;
		}
		if ((Str::eq(S, I"special")) && (verb_directive_special_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_special_symbol, val1, val2); return;
		}
		if ((Str::eq(S, I"number")) && (verb_directive_number_symbol)) {
			Inter::Symbols::to_data(I, pack, verb_directive_number_symbol, val1, val2); return;
		}
		match_results mr = Regexp::create_mr();
		if (Regexp::match(&mr, S, L"scope=(%i+)")) {
			inter_symbol *symb = CodeGen::Link::find_name(I, mr.exp[0]);
			if (symb) {
				if (Inter::Symbols::read_annotation(symb, SCOPE_FILTER_IANN) != 1)
					Inter::Symbols::annotate_i(I, symb, SCOPE_FILTER_IANN, 1);
				Inter::Symbols::to_data(I, pack, symb, val1, val2); return;
			}
		}
		if (Regexp::match(&mr, S, L"noun=(%i+)")) {
			inter_symbol *symb = CodeGen::Link::find_name(I, mr.exp[0]);
			if (symb) {
				if (Inter::Symbols::read_annotation(symb, NOUN_FILTER_IANN) != 1)
					Inter::Symbols::annotate_i(I, symb, NOUN_FILTER_IANN, 1);
				Inter::Symbols::to_data(I, pack, symb, val1, val2); return;
			}
		}
	}

	inter_symbol *symb = CodeGen::Link::find_name(I, S);
	if (symb) {
		Inter::Symbols::to_data(I, pack, symb, val1, val2); return;
	}
	LOG("Glob: %S\n", S);
	CodeGen::Link::log_search_path();
	inter_t ID = Inter::create_text(I);
	text_stream *glob_storage = Inter::get_text(I, ID);
	Str::copy(glob_storage, S);
	*val1 = GLOB_IVAL; *val2 = ID;
}