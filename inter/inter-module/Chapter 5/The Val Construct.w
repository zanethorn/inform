[Inter::Val::] The Val Construct.

Defining the val construct.

@

@e VAL_IST

=
void Inter::Val::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		VAL_IST,
		L"val (%i+) (%c+)",
		&Inter::Val::read,
		NULL,
		&Inter::Val::verify,
		&Inter::Val::write,
		NULL,
		NULL,
		NULL,
		&Inter::Val::show_dependencies,
		I"val", I"vals");
	IC->min_level = 1;
	IC->max_level = 100000000;
	IC->usage_permissions = INSIDE_CODE_PACKAGE;
}

@

@d BLOCK_VAL_IFLD 2
@d KIND_VAL_IFLD 3
@d VAL1_VAL_IFLD 4
@d VAL2_VAL_IFLD 5

@d EXTENT_VAL_IFR 6

=
inter_error_message *Inter::Val::read(inter_reading_state *IRS, inter_line_parse *ilp, inter_error_location *eloc) {
	if (ilp->no_annotations > 0) return Inter::Errors::plain(I"__annotations are not allowed", eloc);

	inter_error_message *E = Inter::Defn::vet_level(IRS, VAL_IST, ilp->indent_level, eloc);
	if (E) return E;

	inter_symbol *routine = Inter::Defn::get_latest_block_symbol();
	if (routine == NULL) return Inter::Errors::plain(I"'val' used outside function", eloc);
	inter_symbols_table *locals = Inter::Package::local_symbols(routine);
	if (locals == NULL) return Inter::Errors::plain(I"function has no symbols table", eloc);

	inter_symbol *val_kind = Inter::Textual::find_symbol(IRS->read_into, eloc, Inter::Bookmarks::scope(IRS), ilp->mr.exp[0], KIND_IST, &E);
	if (E) return E;

	inter_t val1 = 0;
	inter_t val2 = 0;

	inter_symbol *kind_as_value = Inter::Textual::find_symbol(IRS->read_into, eloc, Inter::Bookmarks::scope(IRS), ilp->mr.exp[1], KIND_IST, &E);
	E = NULL;
	if (kind_as_value) {
		Inter::Symbols::to_data(IRS->read_into, IRS->current_package, kind_as_value, &val1, &val2);
	} else {
		E = Inter::Types::read(ilp->line, eloc, IRS->read_into, IRS->current_package, val_kind, ilp->mr.exp[1], &val1, &val2, locals);
		if (E) return E;
	}

	return Inter::Val::new(IRS, routine, val_kind, ilp->indent_level, val1, val2, eloc);
}

inter_error_message *Inter::Val::new(inter_reading_state *IRS, inter_symbol *routine, inter_symbol *val_kind, int level, inter_t val1, inter_t val2, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_4(IRS, VAL_IST, 0, Inter::SymbolsTables::id_from_IRS_and_symbol(IRS, val_kind), val1, val2, eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P); if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

inter_error_message *Inter::Val::verify(inter_frame P) {
	if (P.extent != EXTENT_VAL_IFR) return Inter::Frame::error(&P, I"extent wrong", NULL);
	inter_symbols_table *locals = Inter::Packages::scope_of(P);
	if (locals == NULL) return Inter::Frame::error(&P, I"function has no symbols table", NULL);
	inter_error_message *E = Inter::Verify::symbol(P, P.data[KIND_VAL_IFLD], KIND_IST); if (E) return E;
	inter_symbol *val_kind = Inter::SymbolsTables::symbol_from_frame_data(P, KIND_VAL_IFLD);
	E = Inter::Verify::local_value(P, VAL1_VAL_IFLD, val_kind, locals); if (E) return E;
	return NULL;
}

inter_error_message *Inter::Val::write(OUTPUT_STREAM, inter_frame P) {
	inter_symbols_table *locals = Inter::Packages::scope_of(P);
	if (locals == NULL) return Inter::Frame::error(&P, I"function has no symbols table", NULL);
	inter_symbol *val_kind = Inter::SymbolsTables::symbol_from_frame_data(P, KIND_VAL_IFLD);
	if (val_kind) {
		WRITE("val %S ", val_kind->symbol_name);
		Inter::Types::write(OUT, P.repo_segment->owning_repo, val_kind, P.data[VAL1_VAL_IFLD], P.data[VAL2_VAL_IFLD], locals, FALSE);
	} else return Inter::Frame::error(&P, I"cannot write val", NULL);
	return NULL;
}

void Inter::Val::show_dependencies(inter_frame P, void (*callback)(struct inter_symbol *, struct inter_symbol *, void *), void *state) {
	inter_package *pack = Inter::Packages::container(P);
	inter_symbol *routine = pack->package_name;
	inter_symbol *val_kind = Inter::SymbolsTables::symbol_from_frame_data(P, KIND_VAL_IFLD);
	if ((routine) && (val_kind)) {
		(*callback)(routine, val_kind, state);
		inter_t v1 = P.data[VAL1_VAL_IFLD], v2 = P.data[VAL2_VAL_IFLD];
		inter_symbol *S = Inter::SymbolsTables::symbol_from_data_pair_and_frame(v1, v2, P);
		if (S) (*callback)(routine, S, state);
		if (v1 == GLOB_IVAL) {
			text_stream *S = Inter::get_text(P.repo_segment->owning_repo, v2);
			Inter::Splat::show_dependencies_from(routine, P, S, callback, state);
		}
	}
}