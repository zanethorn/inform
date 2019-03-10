[CodeGen::ReconcileVerbs::] Reconcile Verbs.

To reconcile clashes between assimilated and originally generated verbs.

@h Parsing.

=
void CodeGen::ReconcileVerbs::reconcile(inter_repository *I) {
	dictionary *observed_verbs = Dictionaries::new(1024, TRUE);

	inter_frame P;
	LOOP_THROUGH_FRAMES(P, I)
		if (P.data[ID_IFLD] == CONSTANT_IST) {
			inter_symbol *con_name = Inter::SymbolsTables::symbol_from_frame_data(P, DEFN_CONST_IFLD);
			if ((Inter::Symbols::read_annotation(con_name, VERBARRAY_IANN) == 1) &&
				(Inter::Symbols::read_annotation(con_name, METAVERB_IANN) != 1))
				@<Attend to the verb@>;
		}
	LOOP_THROUGH_FRAMES(P, I)
		if (P.data[ID_IFLD] == CONSTANT_IST) {
			inter_symbol *con_name = Inter::SymbolsTables::symbol_from_frame_data(P, DEFN_CONST_IFLD);
			if ((Inter::Symbols::read_annotation(con_name, VERBARRAY_IANN) == 1) &&
				(Inter::Symbols::read_annotation(con_name, METAVERB_IANN) == 1))
				@<Attend to the verb@>;
		}
}

@<Attend to the verb@> =
	if (P.extent > DATA_CONST_IFLD+1) {
		inter_t V1 = P.data[DATA_CONST_IFLD], V2 = P.data[DATA_CONST_IFLD+1];
		if (V1 == DWORD_IVAL) {
			text_stream *glob_text = Inter::get_text(I, V2);
			if (Dictionaries::find(observed_verbs, glob_text)) {
				TEMPORARY_TEXT(nv);
				WRITE_TO(nv, "!%S", glob_text);
				Str::clear(glob_text);
				Str::copy(glob_text, nv);
				DISCARD_TEXT(nv);
			}
			Dictionaries::create(observed_verbs, glob_text);
		}
	}