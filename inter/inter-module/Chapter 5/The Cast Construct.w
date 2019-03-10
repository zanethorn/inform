[Inter::Cast::] The Cast Construct.

Defining the cast construct.

@

@e CAST_IST

=
void Inter::Cast::define(void) {
	inter_construct *IC = Inter::Defn::create_construct(
		CAST_IST,
		L"cast (%i+) <- (%i+)",
		&Inter::Cast::read,
		NULL,
		&Inter::Cast::verify,
		&Inter::Cast::write,
		NULL,
		&Inter::Cast::accept_child,
		&Inter::Cast::no_more_children,
		&Inter::Cast::show_dependencies,
		I"cast", I"casts");
	IC->min_level = 1;
	IC->max_level = 100000000;
	IC->usage_permissions = INSIDE_CODE_PACKAGE;
}

@

@d BLOCK_CAST_IFLD 2
@d TO_KIND_CAST_IFLD 3
@d FROM_KIND_CAST_IFLD 4
@d OPERANDS_CAST_IFLD 5

@d EXTENT_CAST_IFR 6

=
inter_error_message *Inter::Cast::read(inter_reading_state *IRS, inter_line_parse *ilp, inter_error_location *eloc) {
	if (ilp->no_annotations > 0) return Inter::Errors::plain(I"__annotations are not allowed", eloc);

	inter_error_message *E = Inter::Defn::vet_level(IRS, CAST_IST, ilp->indent_level, eloc);
	if (E) return E;

	inter_symbol *routine = Inter::Defn::get_latest_block_symbol();
	if (routine == NULL) return Inter::Errors::plain(I"'val' used outside function", eloc);

	inter_symbol *from_kind = Inter::Textual::find_symbol(IRS->read_into, eloc, Inter::Bookmarks::scope(IRS), ilp->mr.exp[1], KIND_IST, &E);
	if (E) return E;
	inter_symbol *to_kind = Inter::Textual::find_symbol(IRS->read_into, eloc, Inter::Bookmarks::scope(IRS), ilp->mr.exp[0], KIND_IST, &E);
	if (E) return E;

	return Inter::Cast::new(IRS, routine, from_kind, to_kind, (inter_t) ilp->indent_level, eloc);
}

inter_error_message *Inter::Cast::new(inter_reading_state *IRS, inter_symbol *routine, inter_symbol *from_kind, inter_symbol *to_kind, inter_t level, inter_error_location *eloc) {
	inter_frame P = Inter::Frame::fill_4(IRS, CAST_IST, 0, Inter::SymbolsTables::id_from_IRS_and_symbol(IRS, to_kind), Inter::SymbolsTables::id_from_IRS_and_symbol(IRS, from_kind), Inter::create_frame_list(IRS->read_into), eloc, (inter_t) level);
	inter_error_message *E = Inter::Defn::verify_construct(P); if (E) return E;
	Inter::Frame::insert(P, IRS);
	return NULL;
}

inter_error_message *Inter::Cast::verify(inter_frame P) {
	if (P.extent != EXTENT_CAST_IFR) return Inter::Frame::error(&P, I"extent wrong", NULL);
	inter_error_message *E = Inter::Verify::symbol(P, P.data[TO_KIND_CAST_IFLD], KIND_IST); if (E) return E;
	E = Inter::Verify::symbol(P, P.data[FROM_KIND_CAST_IFLD], KIND_IST); if (E) return E;
	return NULL;
}

inter_error_message *Inter::Cast::write(OUTPUT_STREAM, inter_frame P) {
	inter_symbols_table *locals = Inter::Packages::scope_of(P);
	if (locals == NULL) return Inter::Frame::error(&P, I"function has no symbols table", NULL);
	inter_symbol *from_kind = Inter::SymbolsTables::symbol_from_frame_data(P, FROM_KIND_CAST_IFLD);
	inter_symbol *to_kind = Inter::SymbolsTables::symbol_from_frame_data(P, TO_KIND_CAST_IFLD);
	if ((from_kind) && (to_kind)) {
		WRITE("cast %S <- %S", to_kind->symbol_name, from_kind->symbol_name);
	} else return Inter::Frame::error(&P, I"cannot write cast", NULL);
	return NULL;
}

void Inter::Cast::show_dependencies(inter_frame P, void (*callback)(struct inter_symbol *, struct inter_symbol *, void *), void *state) {
	inter_package *pack = Inter::Packages::container(P);
	inter_symbol *routine = pack->package_name;
	inter_symbol *from_kind = Inter::SymbolsTables::symbol_from_frame_data(P, FROM_KIND_CAST_IFLD);
	inter_symbol *to_kind = Inter::SymbolsTables::symbol_from_frame_data(P, TO_KIND_CAST_IFLD);
	if ((routine) && (from_kind) && (to_kind)) {
		(*callback)(routine, from_kind, state);
		(*callback)(routine, to_kind, state);
	}
}

inter_error_message *Inter::Cast::accept_child(inter_frame P, inter_frame C) {
	if ((C.data[0] != INV_IST) && (C.data[0] != VAL_IST) && (C.data[0] != CONCATENATE_IST) && (C.data[0] != CAST_IST))
		return Inter::Frame::error(&P, I"only inv, cast, concatenate and val can be under a cast", NULL);
	Inter::add_to_frame_list(Inter::find_frame_list(P.repo_segment->owning_repo, P.data[OPERANDS_CAST_IFLD]), C, NULL);
	return NULL;
}

inter_frame_list *Inter::Cast::children_of_frame(inter_frame P) {
	return Inter::find_frame_list(P.repo_segment->owning_repo, P.data[OPERANDS_CAST_IFLD]);
}

inter_error_message *Inter::Cast::no_more_children(inter_frame P) {
	inter_frame_list *ifl = Inter::find_frame_list(P.repo_segment->owning_repo, P.data[OPERANDS_CAST_IFLD]);
	int arity_as_invoked = Inter::size_of_frame_list(ifl);
	if (arity_as_invoked != 1)
		return Inter::Frame::error(&P, I"a cast should have exactly one child", NULL);
	return NULL;
}