[Inter::Errors::] Inter Errors.

To issue error messages.

@h Reading textual inter.

=
typedef struct inter_error_location {
	struct text_file_position *error_tfp;
	struct text_stream *error_line;
	struct filename *error_interb;
	size_t error_offset;
	struct inter_frame error_frame;
	MEMORY_MANAGEMENT
} inter_error_location;

inter_error_location Inter::Errors::file_location(text_stream *line, text_file_position *tfp) {
	inter_error_location eloc;
	eloc.error_tfp = tfp;
	eloc.error_line = line;
	eloc.error_interb = NULL;
	eloc.error_offset = 0;
	eloc.error_frame = Inter::Frame::around(NULL, -1);
	return eloc;
}

inter_error_location Inter::Errors::interb_location(filename *F, size_t at) {
	inter_error_location eloc;
	eloc.error_tfp = NULL;
	eloc.error_line = NULL;
	eloc.error_interb = F;
	eloc.error_offset = at;
	eloc.error_frame = Inter::Frame::around(NULL, -1);
	return eloc;
}

typedef struct inter_error_message {
	struct inter_error_location error_at;
	struct text_stream *error_body;
	struct text_stream *error_quote;
	MEMORY_MANAGEMENT
} inter_error_message;

inter_error_message *Inter::Errors::quoted(text_stream *err, text_stream *quote, inter_error_location *eloc) {
	inter_error_message *iem = Inter::Errors::plain(err, eloc);
	iem->error_quote = Str::duplicate(quote);
	return iem;
}

inter_error_message *Inter::Errors::plain(text_stream *err, inter_error_location *eloc) {
	inter_error_message *iem = CREATE(inter_error_message);
	iem->error_body = Str::duplicate(err);
	iem->error_quote = NULL;
	if (eloc) iem->error_at = *eloc;
	return iem;
}

void Inter::Errors::issue(inter_error_message *iem) {
	if (iem == NULL) internal_error("no error to issue");
	Inter::Errors::issue_to(STDERR, iem);
	#ifdef CORE_MODULE
	LOG("Inter error:\n");
	Inter::Errors::issue_to(DL, iem);
	#endif
}

void Inter::Errors::issue_to(OUTPUT_STREAM, inter_error_message *iem) {
	TEMPORARY_TEXT(E);
	WRITE_TO(E, "%S", iem->error_body);
	if (iem->error_quote)
		WRITE_TO(E, ": '%S'", iem->error_quote);
	inter_error_location eloc = iem->error_at;
	if (eloc.error_interb) {
		WRITE("%f, position %08x: ", eloc.error_interb, eloc.error_offset);
	}
	if (eloc.error_tfp)
		Errors::in_text_file_S(E, eloc.error_tfp);
	else
		Errors::in_text_file_S(E, NULL);
	if (eloc.error_line)
		WRITE(">--> %S\n", eloc.error_line);
	DISCARD_TEXT(E);
}

inter_error_message *Inter::Errors::gather_first(inter_error_message *E, inter_error_message *F) {
	if (E) return E;
	return F;
}