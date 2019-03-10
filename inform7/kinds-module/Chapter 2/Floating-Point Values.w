[Kinds::FloatingPoint::] Floating-Point Values.

To cope with promotions from integer to floating-point arithmetic.

@h Definitions.

@ If we do have floating-point arithmetic available, we need to be able to
play off between real and integer versions of the same kind -- for example,
using real arithmetic to approximately carry out integer calculations, or vice
versa.

=
typedef struct generalised_kind {
	struct kind *valid_kind; /* must be non-null */
	int promotion; /* |0| for no change, |1| for "a real version", |-1| for "an int version" */
} generalised_kind;

@ =
generalised_kind Kinds::FloatingPoint::new_gk(kind *K) {
	if (K == NULL) internal_error("can't generalise the null kind");
	generalised_kind gK;
	gK.valid_kind = K;
	gK.promotion = 0;
	return gK;
}

void Kinds::FloatingPoint::log_gk(generalised_kind gK) {
	LOG("$u", gK.valid_kind);
	if (gK.promotion == 1) { LOG("=>real"); }
	if (gK.promotion == -1) { LOG("=>int"); }
}

kind *Kinds::FloatingPoint::underlying(generalised_kind gK) {
	return gK.valid_kind;
}

int Kinds::FloatingPoint::is_real(generalised_kind gK) {
	if (gK.promotion == 1) return TRUE;
	if (Kinds::FloatingPoint::uses_floating_point(gK.valid_kind)) return TRUE;
	return FALSE;
}

generalised_kind Kinds::FloatingPoint::to_integer(generalised_kind gK) {
	if (Kinds::FloatingPoint::is_real(gK)) {
		if (gK.promotion == 1) gK.promotion = 0;
		else {
			kind *K = Kinds::FloatingPoint::integer_equivalent(gK.valid_kind);
			if (Kinds::FloatingPoint::uses_floating_point(K) == FALSE) gK.valid_kind = K;
			else gK.promotion = -1;
		}
	}
	if (Kinds::FloatingPoint::is_real(gK))
		internal_error("gK inconsistent");
	return gK;
}

generalised_kind Kinds::FloatingPoint::to_real(generalised_kind gK) {
	if (Kinds::FloatingPoint::is_real(gK) == FALSE) {
		if (gK.promotion == -1) gK.promotion = 0;
		else {
			kind *K = Kinds::FloatingPoint::real_equivalent(gK.valid_kind);
			if (Kinds::FloatingPoint::uses_floating_point(K)) gK.valid_kind = K;
			else gK.promotion = 1;
		}
	}
	if (Kinds::FloatingPoint::is_real(gK) == FALSE)
		internal_error("gK inconsistent");
	return gK;
}

@ =
void Kinds::FloatingPoint::begin_flotation(OUTPUT_STREAM, kind *K) {
	if (Kinds::Behaviour::scale_factor(K) != 1) WRITE("REAL_NUMBER_TY_Divide(");
	WRITE("NUMBER_TY_to_REAL_NUMBER_TY");
	WRITE("(");
}

void Kinds::FloatingPoint::end_flotation(OUTPUT_STREAM, kind *K) {
	WRITE(")");
	if (Kinds::Behaviour::scale_factor(K) != 1)
		WRITE(", NUMBER_TY_to_REAL_NUMBER_TY(%d))",
			Kinds::Behaviour::scale_factor(K));
}

void Kinds::FloatingPoint::begin_deflotation(OUTPUT_STREAM, kind *K) {
	WRITE("REAL_NUMBER_TY_to_NUMBER_TY(");
	if (Kinds::Behaviour::scale_factor(K) != 1) WRITE("REAL_NUMBER_TY_Times(");
}

void Kinds::FloatingPoint::end_deflotation(OUTPUT_STREAM, kind *K) {
	if (Kinds::Behaviour::scale_factor(K) != 1)
		WRITE(", NUMBER_TY_to_REAL_NUMBER_TY(%d))",
			Kinds::Behaviour::scale_factor(K));
	WRITE(")");
}

#ifdef CORE_MODULE
void Kinds::FloatingPoint::begin_flotation_emit(kind *K) {
	if (Kinds::Behaviour::scale_factor(K) != 1) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(REALNUMBERTYDIVIDE_EXNAMEF)));
		Emit::down();
	}
	Emit::inv_call(InterNames::to_symbol(InterNames::extern(NUMBERTYTOREALNUMBERTY_EXNAMEF)));
	Emit::down();
}

void Kinds::FloatingPoint::end_flotation_emit(kind *K) {
	Emit::up();
	if (Kinds::Behaviour::scale_factor(K) != 1) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(NUMBERTYTOREALNUMBERTY_EXNAMEF)));
		Emit::down();
			Emit::val(K_number, LITERAL_IVAL, (inter_t) Kinds::Behaviour::scale_factor(K));
		Emit::up();
		Emit::up();
	}
}

void Kinds::FloatingPoint::begin_deflotation_emit(kind *K) {
	Emit::inv_call(InterNames::to_symbol(InterNames::extern(REALNUMBERTYTONUMBERTY_EXNAMEF)));
	Emit::down();
	if (Kinds::Behaviour::scale_factor(K) != 1) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(REALNUMBERTYTIMES_EXNAMEF)));
		Emit::down();
	}
}

void Kinds::FloatingPoint::end_deflotation_emit(kind *K) {
	if (Kinds::Behaviour::scale_factor(K) != 1) {
		Emit::inv_call(InterNames::to_symbol(InterNames::extern(REALNUMBERTYTONUMBERTY_EXNAMEF)));
		Emit::down();
			Emit::val(K_number, LITERAL_IVAL, (inter_t) Kinds::Behaviour::scale_factor(K));
		Emit::up();
		Emit::up();
	}
	Emit::up();
}
#endif

int Kinds::FloatingPoint::uses_floating_point(kind *K) {
	if (K == NULL) return FALSE;
	return Kinds::Constructors::is_arithmetic_and_real(K->construct);
}

kind *Kinds::FloatingPoint::real_equivalent(kind *K) {
	if (Kinds::Compare::eq(K, K_number)) return K_real_number;
	return K;
}

kind *Kinds::FloatingPoint::integer_equivalent(kind *K) {
	if (Kinds::Compare::eq(K, K_real_number)) return K_number;
	return K;
}