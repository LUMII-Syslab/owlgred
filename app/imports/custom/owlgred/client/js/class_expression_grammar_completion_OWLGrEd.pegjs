{
  /*
   * Completion-enabled class-expression grammar.
   * PEG.js 0.9.0 compatible style: ES5 helper code and brace-safe
   * completion marker actions.
   */

  var continuations = {};

  function ensureOffset(offset) {
    if (continuations[offset] == null) continuations[offset] = {};
  }

  function addContinuation(place, continuation, priority, spaceBefore, type, start_end) {
    var position = start_end || "start";
    var offset = place[position].offset;
    ensureOffset(offset);

    var previous = continuations[offset][continuation];
    if (previous === undefined || previous.priority > priority) {
      continuations[offset][continuation] = {
        name: continuation,
        priority: priority,
        type: type,
        spaceBefore: !!spaceBefore
      };
    }
  }

  function returnContinuation() {
    return JSON.stringify(continuations, null, 2);
  }

  /*
   * Application-specific providers.
   * Fill these manually in the ViziQuer environment.
   */
  function getClasses(place, priority) {
    var values = [
        "Person",
        "Student",
        "Employee",
        "Animal",
        "ex:Person"
    ];

    for (var i = 0; i < values.length; i++) {
        addContinuation(place, values[i], priority, false, 1);
    }
}


	function getProperties(place, priority) {
		var values = [
			"hasChild",
			"hasAge",
			"hasName",
			"worksFor",
			"ex:hasFriend"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 2);
		}
	}


	function getIndividuals(place, priority) {
		var values = [
			"John",
			"Mary",
			"Alice",
			"ex:john",
			"ex:mary"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 3);
		}
	}


	function getDatatypes(place, priority) {
		var values = [
			"xsd:string",
			"xsd:integer",
			"xsd:decimal",
			"xsd:boolean",
			"xsd:date",
			"xsd:dateTime",
			"ex:CustomDatatype"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 1);
		}
	}


	function getIRIs(place, priority) {
		var values = [
			"owl:Thing",
			"owl:Nothing",
			"rdf:type",
			"rdfs:label",
			"ex:Something"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 1);
		}
	}


	function getPrefixes(place, priority) {
		var values = [
			"rdf",
			"rdfs",
			"owl",
			"xsd",
			"ex"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 1);
		}
	}


	function getLanguageTags(place, priority) {
		var values = [
			"en",
			"lv",
			"de",
			"fr",
			"en-US",
			"en-GB"
		];

		for (var i = 0; i < values.length; i++) {
			addContinuation(place, values[i], priority, false, 1);
		}
	}

  /* Original semantic helpers retained for grammar actions. */
  function copyProps(dst, src) {
    if (!src) return dst;
    for (var k in src) {
      if (Object.prototype.hasOwnProperty.call(src, k)) dst[k] = src[k];
    }
    return dst;
  }

  function node(grammarProduction, items) {
    return { grammarProduction: grammarProduction, items: items || [] };
  }

  function listFromFirstTail(first, tail, pickIndex) {
    var out = [first];
    for (var i = 0; i < tail.length; i++) out.push(tail[i][pickIndex]);
    return out;
  }
}

/* =========================
   START
========================= */

Start
  = (WhitespaceStar ClassExpression WhitespaceStar)? end

/* =========================
   CLASS EXPRESSION (disjunction)
   classExpression <- conjunction ( 'or' conjunction )*
========================= */

ClassExpression
  = head:Conjunction tail:(WhitespacePlus or_c "or" WhitespacePlus Conjunction)*
    {
      var items = listFromFirstTail(head, tail, 4);
      return node("disjunction", items);
    }

/* =========================
   CONJUNCTION
   1) Class that R (and R)*
   2) Primary (and Primary)*
========================= */

Conjunction
  = // conjunctionWithRestrictions
    cls:ClassIRI WhitespacePlus that_c "that" WhitespacePlus
    r1:Restriction rtail:(WhitespacePlus and_c "and" WhitespacePlus Restriction)*
    {
      var restrictions = listFromFirstTail(r1, rtail, 4);
      return {
        grammarProduction: "conjunctionWithRestrictions",
        class: cls,
        restrictions: restrictions
      };
    }
  / // conjunctionNoRestrictions
    p1:Primary ptail:(WhitespacePlus and_c "and" WhitespacePlus Primary)*
    {
      var items = listFromFirstTail(p1, ptail, 4);
      return node("conjunctionNoRestrictions", items);
    }

/* =========================
   RESTRICTION
========================= */

Restriction
  = head:RestrictionHead tail:RestrictionTail
    {
      var o = {};
      copyProps(o, head);
      copyProps(o, tail);
      return o;
    }

RestrictionHead
  = inverse_c "inverse" WhitespacePlus lparen_c "(" prop:PropertyIRI rparen_c ")" WhitespacePlus
    { return { inverse: "true", property: prop }; }
  / inverse_c "inverse" WhitespacePlus prop:PropertyIRI WhitespacePlus
    { return { inverse: "true", property: prop }; }
  / prop:PropertyIRI WhitespacePlus
    { return { inverse: "false", property: prop }; }

RestrictionTail
  = quantifier_c kw:("some" / "only") WhitespacePlus v:SomePrimary
    { return { keyword: kw, value: v }; }
  / value_c "value" WhitespacePlus v:(StringLiteralNoLangBool / Individual / Literal)
    { return { keyword: "value", value: v }; }
  / self_c kw:(("Self" / "self") { return "Self"; })
    { return { keyword: kw }; }
  / cardinality_c kw:("min" / "max" / "exactly") WhitespacePlus c:NonNegInt v:(WhitespacePlus sp:SomePrimary { return sp; })?
    { return { keyword: kw, count: c, value: v === null ? null : v }; }

/* =========================
   PRIMARY (optionally 'not')
========================= */

Primary
  = n:Negation? body:(RestrictionOrAtomic)
    {
      return {
        negation: n === null ? "false" : "true",
        primaryType: body.primaryType,
        primary: body.primary
      };
    }

Negation
  = not_c "not" WhitespacePlus { return "true"; }

RestrictionOrAtomic
  = r:Restriction { return { primaryType: "restriction", primary: r }; }
  / a:Atomic      { return { primaryType: "atomic",      primary: a }; }

/* =========================
   ATOMIC
========================= */

Atomic
  = cls:ClassIRI
    { return { atomType: "class", class: cls }; }
  / lbrace_c "{" WhitespaceStar lst:IndividualList WhitespaceStar rbrace_c "}"
    { return { atomType: "individualList", list: lst }; }
  / lparen_c "(" WhitespaceStar e:ClassExpression WhitespaceStar rparen_c ")"
    { return { atomType: "expression", expression: e }; }

/* =========================
   SOME PRIMARY (unknown target kind)
   This matches your somePrimary shape exactly (unknownPrimaryType + payload)
========================= */

SomePrimary
  = lbrace_c "{" WhitespaceStar lst:LiteralList WhitespaceStar rbrace_c "}"
    { return { unknownPrimaryType: "literalList", list: lst }; }
  / lbrace_c "{" WhitespaceStar lst:IndividualList WhitespaceStar rbrace_c "}"
    { return { unknownPrimaryType: "individualList", list: lst }; }
  / lparen_c "(" WhitespaceStar ex:UnknownExpression WhitespaceStar rparen_c ")"
    { return { unknownPrimaryType: "expression", expression: ex }; }
  / r:Restriction
    { return { unknownPrimaryType: "restriction", restriction: r }; }
  / dr:DatatypeRestriction
    { return { unknownPrimaryType: "datatypeRestriction", restriction: dr }; }
  / iri:GeneralIRI
    { return { unknownPrimaryType: "IRI", IRI: iri }; }

/* =========================
   INDIVIDUALS
========================= */

IndividualList
  = first:Individual rest:(comma_c "," WhitespaceStar Individual)*
    {
      var out = [first];
      for (var i = 0; i < rest.length; i++) out.push(rest[i][3]);
      return out;
    }

Individual
  = iri:IndividualIRI
    { return { individualType: "IRI", individual: iri }; }
  / bn:BlankNode
    { return { individualType: "blank", individual: bn }; }

/* =========================
   UNKNOWN EXPRESSION (for some/only targets)
   unknownExpression <- unknownConjunction ( 'or' unknownConjunction )*
========================= */

UnknownExpression
  = head:UnknownConjunction tail:(WhitespacePlus or_c "or" WhitespacePlus UnknownConjunction)*
    {
      var items = listFromFirstTail(head, tail, 4);
      return node("unknownDisjunction", items);
    }

UnknownConjunction
  = // same "Class that R and R" form
    cls:ClassIRI WhitespacePlus that_c "that" WhitespacePlus
    r1:Restriction rtail:(WhitespacePlus and_c "and" WhitespacePlus Restriction)*
    {
      var restrictions = listFromFirstTail(r1, rtail, 4);
      return {
        grammarProduction: "conjunctionWithRestrictions",
        class: cls,
        restrictions: restrictions
      };
    }
  / // unknownPrimary list
    p1:UnknownPrimary ptail:(WhitespacePlus and_c "and" WhitespacePlus UnknownPrimary)*
    {
      var items = listFromFirstTail(p1, ptail, 4);
      return node("unknownConjunction", items);
    }

UnknownPrimary
  = n:Negation? body:UnknownPrimaryBody
    {
      var o = { negation: n === null ? "false" : "true" };
      copyProps(o, body);
      return o;
    }

UnknownPrimaryBody
  = r:Restriction
    { return { unknownPrimaryType: "restriction", restriction: r }; }
  / dr:DatatypeRestriction
    { return { unknownPrimaryType: "datatypeRestriction", restriction: dr }; }
  / lbrace_c "{" WhitespaceStar lst:LiteralList WhitespaceStar rbrace_c "}"
    { return { unknownPrimaryType: "literalList", list: lst }; }
  / lbrace_c "{" WhitespaceStar lst:IndividualList WhitespaceStar rbrace_c "}"
    { return { unknownPrimaryType: "individualList", list: lst }; }
  / lparen_c "(" WhitespaceStar ex:UnknownExpression WhitespaceStar rparen_c ")"
    { return { unknownPrimaryType: "expression", expression: ex }; }
  / iri:GeneralIRI
    { return { unknownPrimaryType: "IRI", IRI: iri }; }

/* =========================
   DATA RANGE (copied semantics from your datatype grammar)
========================= */

DataRange
  = head:DataConjunction tail:(WhitespacePlus or_c "or" WhitespacePlus DataConjunction)*
    {
      var items = listFromFirstTail(head, tail, 4);
      return node("dataDisjunction", items);
    }

DataConjunction
  = head:DataPrimary tail:(WhitespacePlus and_c "and" WhitespacePlus DataPrimary)*
    {
      var items = listFromFirstTail(head, tail, 4);
      return node("dataConjunction", items);
    }

DataPrimary
  = n:Negation? body:DataPrimaryBody
    {
      var o = { negation: n === null ? "false" : "true" };
      copyProps(o, body);
      return o;
    }

DataPrimaryBody
  = r:DatatypeRestriction
    { return { dataPrimaryType: "datatypeRestriction", restriction: r }; }
  / d:Datatype
    { return { dataPrimaryType: "datatype", datatype: d }; }
  / lbrace_c "{" WhitespaceStar ll:LiteralList WhitespaceStar rbrace_c "}"
    { return { dataPrimaryType: "literalList", literalList: ll }; }
  / lparen_c "(" WhitespaceStar dr:DataRange WhitespaceStar rparen_c ")"
    { return { dataPrimaryType: "dataRange", dataRange: dr }; }

/* =========================
   DATATYPE / DATATYPE RESTRICTION
========================= */

Datatype
  = datatype_kw_c value:(
      "Literal"
    / "NCName"
    / "NMTOKEN"
    / "Name"
    / "PlainLiteral"
    / "XMLLiteral"
    / "anyURI"
    / "base64Binary"
    / "boolean"
    / "byte"
    / "date"
    / "dateTime"
    / "dateTimeStamp"
    / "decimal"
    / "double"
    / "float"
    / "hexBinary"
    / "int"
    / "integer"
    / "language"
    / "long"
    / "negativeInteger"
    / "nonNegativeInteger"
    / "nonPositiveInteger"
    / "normalizedString"
    / "positiveInteger"
    / "rational"
    / "real"
    / "short"
    / "string"
    / "time"
    / "token"
    / "unsignedByte"
    / "unsignedInt"
    / "unsignedLong"
    / "unsignedShort"
    )
    { return { type: "predefined", value: value }; }
  / iri:DatatypeIRI
    { return { type: "IRI", value: iri }; }

DatatypeRestriction
  = dt:Datatype WhitespaceStar lbracket_c "[" WhitespaceStar
    r1:DataRestriction rtail:(WhitespaceStar comma_c "," WhitespaceStar DataRestriction)*
    WhitespaceStar rbracket_c "]"
    {
      var restrictions = listFromFirstTail(r1, rtail, 4);
      return { datatype: dt, restrictions: restrictions };
    }

DataRestriction
  = f:Facet WhitespaceStar v:RestrictionValue
    { return { facet: f, value: v }; }

Facet
  = facets_c ("<=" / "<" / ">=" / ">" / "length" / "maxLength" / "minLength" / "pattern" / "langPattern")

RestrictionValue
  = Literal

/* =========================
   LITERALS
========================= */

LiteralList
  = first:Literal rest:(WhitespaceStar comma_c "," WhitespaceStar Literal)+
    { return listFromFirstTail(first, rest, 4); }

Literal
  = TypedLiteral
  / StringLiteralWithLang
  / StringLiteralNoLang
  / FloatLiteral
  / DecimalLiteral
  / IntegerLiteral

TypedLiteral
  = v:QuotedString double_caret_c "^^" dt:Datatype
    { return { type: "typed", value: v, datatype: dt }; }

StringLiteralNoLang
  = v:QuotedString
    { return { type: "stringNoLang", value: v }; }

// Matches your Lua mapping: true -> '"true"', false -> '"false"'
StringLiteralNoLangBool
  = v:(True / False)
    { return { type: "stringNoLang", value: v }; }

True  = true_false_c "true"  { return "\"true\""; }
False = true_false_c "false" { return "\"false\""; }

StringLiteralWithLang
  = v:QuotedString at_c "@" lang:LanguageTag
    { return { type: "stringWithLang", value: v, language: lang }; }

IntegerLiteral
  = v:$(Sign? Digit+)
    { return { type: "integer", value: v }; }

DecimalLiteral
  = v:$(Sign? Digit+ dot_c "." Digit+)
    { return { type: "decimal", value: v }; }

FloatLiteral
  = v:$(Sign? (Digit+ dot_c ".")? Digit+ Exponent float_suffix_c ("f" / "F"))
    { return { type: "float", value: v }; }

Exponent
  = exponent_c ("e" / "E") Sign? Digit+

Sign
  = sign_c ("+" / "-")

Digit
  = digit_c [0-9]

NonNegInt
  = $(Digit+)

/* =========================
   QUOTED STRING (your quotedStringChars)
   quotedStringChars = [\1-\33] / [\35-\91] / [\93-\255]
========================= */

QuotedString
  = s:$(quote_c "\"" QuotedStringInner* quote_c "\"") { return s; }

QuotedStringInner
  = QUOTED_STRING_CHARS
  / "\\\\"
  / "\\\""

QUOTED_STRING_CHARS
  = [\u0001-\u0021\u0023-\u005B\u005D-\u00FF]

/* =========================
   LANGUAGE TAG (your langTagChars*)
   langTagChars = [A-Z] / [a-z] / '-'
========================= */

LanguageTag
  = language_tag_c $(LANG_TAG_CHARS*)

LANG_TAG_CHARS
  = [A-Za-z\-]

/* =========================
   SEMANTIC IRI COMPLETION POSITIONS
========================= */

ClassIRI
  = classes_c iri:IRI { return iri; }

PropertyIRI
  = properties_c iri:IRI { return iri; }

IndividualIRI
  = individuals_c iri:IRI { return iri; }

DatatypeIRI
  = datatypes_c iri:IRI { return iri; }

GeneralIRI
  = iris_c iri:IRI { return iri; }

/* =========================
   IRI (your IRI forms)
========================= */

IRI
  = v:FullIRI
    { return { IRItype: "fullIRI", value: v }; }
  / v:PrefixedIRI
    { return { IRItype: "abbreviatedIRI", value: v }; }
  / v:AbbreviatedIRI
    { return { IRItype: "abbreviatedIRI", value: v }; }
  / v:FullNamespaceIRI
    { return { IRItype: "fullNamespaceIRI", value: v }; }
  / v:SimpleIRI
    { return { IRItype: "simpleIRI", value: v }; }

// fullIRIChars = [\33-\59] / '=' / [\63-\126] / [\128-\255]
FULL_IRI_CHARS
  = [\u0021-\u003B\u003D\u003F-\u007E\u0080-\u00FF]

FullIRI
  = s:$(less_c "<" FULL_IRI_CHARS+ greater_c ">") { return s; }

PrefixedIRI
  = prefix:PrefixLabel colon_c ":" name:LocalName
    { return { name: name, prefix: prefix }; }

/* A prefix label cannot consume the ':' separator or end in '.'. */
PrefixLabel
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." &PN_CHARS)*)

AbbreviatedIRI
  = name:LocalName lbrace_c "{" prefix:Prefix rbrace_c "}"
    { return { name: name, prefix: prefix }; }

FullNamespaceIRI
  = name:LocalName lbrace_c "{" prefix:PrefixNamespace rbrace_c "}"
    { return { name: name, prefix: prefix }; }

// pn_chars_base = [A-Z] / [a-z] / [\128-\214] / [\216-\246] / [\248-\255]
PN_CHARS_BASE
  = [A-Za-z\u0080-\u00D6\u00D8-\u00F6\u00F8-\u00FF]

// pn_chars = pn_chars_base / '_' / '-' / [0-9]
PN_CHARS
  = [A-Za-z0-9_\-\u0080-\u00D6\u00D8-\u00F6\u00F8-\u00FF]

// prefix = %pn_chars_base (%pn_chars / '.' / '/' / ':')*
Prefix
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." / slash_c "/" / colon_c ":")*)

// same as Prefix in your grammar
PrefixNamespace
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." / slash_c "/" / colon_c ":")*)

LocalName
  = $( (PN_CHARS_BASE / underscore_c "_" / Digit) (PN_CHARS / dot_c ".")* )

SimpleIRI
  = LocalName

BlankNode
  = s:$(blank_node_c "_:" LocalName) { return s; }

/* =========================
   WHITESPACE
========================= */

Whitespace
  = [ \t\r\n]

WhitespacePlus
  = required_space_c Whitespace+

WhitespaceStar
  = Whitespace*

/* =========================================================
   COMPLETION MARKER RULES
   ========================================================= */

/* logical / class-expression keywords */
or_c
  = "" { addContinuation(location(), "or", 20, true, 4); }

and_c
  = "" { addContinuation(location(), "and", 20, true, 4); }

that_c
  = "" { addContinuation(location(), "that", 20, true, 4); }

inverse_c
  = "" { addContinuation(location(), "inverse", 25, false, 4); }

not_c
  = "" { addContinuation(location(), "not", 20, false, 4); }

quantifier_c
  = "" {
      addContinuation(location(), "some", 25, false, 4);
      addContinuation(location(), "only", 25, false, 4);
    }

value_c
  = "" { addContinuation(location(), "value", 25, false, 4); }

self_c
  = "" {
      addContinuation(location(), "Self", 25, false, 4);
      addContinuation(location(), "self", 25, false, 4);
    }

cardinality_c
  = "" {
      addContinuation(location(), "min", 25, false, 4);
      addContinuation(location(), "max", 25, false, 4);
      addContinuation(location(), "exactly", 25, false, 4);
    }

/* predefined datatypes */
datatype_kw_c
  = "" {
      addContinuation(location(), "Literal", 30, false, 4);
      addContinuation(location(), "NCName", 30, false, 4);
      addContinuation(location(), "NMTOKEN", 30, false, 4);
      addContinuation(location(), "Name", 30, false, 4);
      addContinuation(location(), "PlainLiteral", 30, false, 4);
      addContinuation(location(), "XMLLiteral", 30, false, 4);
      addContinuation(location(), "anyURI", 30, false, 4);
      addContinuation(location(), "base64Binary", 30, false, 4);
      addContinuation(location(), "boolean", 30, false, 4);
      addContinuation(location(), "byte", 30, false, 4);
      addContinuation(location(), "date", 30, false, 4);
      addContinuation(location(), "dateTime", 30, false, 4);
      addContinuation(location(), "dateTimeStamp", 30, false, 4);
      addContinuation(location(), "decimal", 30, false, 4);
      addContinuation(location(), "double", 30, false, 4);
      addContinuation(location(), "float", 30, false, 4);
      addContinuation(location(), "hexBinary", 30, false, 4);
      addContinuation(location(), "int", 30, false, 4);
      addContinuation(location(), "integer", 30, false, 4);
      addContinuation(location(), "language", 30, false, 4);
      addContinuation(location(), "long", 30, false, 4);
      addContinuation(location(), "negativeInteger", 30, false, 4);
      addContinuation(location(), "nonNegativeInteger", 30, false, 4);
      addContinuation(location(), "nonPositiveInteger", 30, false, 4);
      addContinuation(location(), "normalizedString", 30, false, 4);
      addContinuation(location(), "positiveInteger", 30, false, 4);
      addContinuation(location(), "rational", 30, false, 4);
      addContinuation(location(), "real", 30, false, 4);
      addContinuation(location(), "short", 30, false, 4);
      addContinuation(location(), "string", 30, false, 4);
      addContinuation(location(), "time", 30, false, 4);
      addContinuation(location(), "token", 30, false, 4);
      addContinuation(location(), "unsignedByte", 30, false, 4);
      addContinuation(location(), "unsignedInt", 30, false, 4);
      addContinuation(location(), "unsignedLong", 30, false, 4);
      addContinuation(location(), "unsignedShort", 30, false, 4);
    }

/* datatype restriction facets */
facets_c
  = "" {
      addContinuation(location(), "<=", 30, false, 4);
      addContinuation(location(), "<", 30, false, 4);
      addContinuation(location(), ">=", 30, false, 4);
      addContinuation(location(), ">", 30, false, 4);
      addContinuation(location(), "length", 30, false, 4);
      addContinuation(location(), "maxLength", 30, false, 4);
      addContinuation(location(), "minLength", 30, false, 4);
      addContinuation(location(), "pattern", 30, false, 4);
      addContinuation(location(), "langPattern", 30, false, 4);
    }

/* literal values */
true_false_c
  = "" {
      addContinuation(location(), "true", 30, false, 4);
      addContinuation(location(), "false", 30, false, 4);
    }

/* punctuation / operators */
lbrace_c       = "" { addContinuation(location(), "{", 10, false, 4); /* } */ }
rbrace_c       = "" { addContinuation(location(), /* { */ "}", 10, false, 4); }
lparen_c       = "" { addContinuation(location(), "(", 10, false, 4); }
rparen_c       = "" { addContinuation(location(), ")", 10, false, 4); }
lbracket_c     = "" { addContinuation(location(), "[", 10, false, 4); }
rbracket_c     = "" { addContinuation(location(), "]", 10, false, 4); }
comma_c        = "" { addContinuation(location(), ",", 10, false, 4); }
double_caret_c = "" { addContinuation(location(), "^^", 15, false, 4); }
at_c           = "" { addContinuation(location(), "@", 15, false, 4); }
less_c         = "" { addContinuation(location(), "<", 10, false, 4); }
greater_c      = "" { addContinuation(location(), ">", 10, false, 4); }
colon_c        = "" { addContinuation(location(), ":", 15, false, 4); }
dot_c          = "" { addContinuation(location(), ".", 15, false, 4); }
slash_c        = "" { addContinuation(location(), "/", 15, false, 4); }
underscore_c   = "" { addContinuation(location(), "_", 40, false, 4); }
blank_node_c   = "" { addContinuation(location(), "_:", 40, false, 4); }
quote_c        = "" { addContinuation(location(), "\"", 10, false, 4); }

sign_c
  = "" {
      addContinuation(location(), "+", 40, false, 4);
      addContinuation(location(), "-", 40, false, 4);
    }

exponent_c
  = "" {
      addContinuation(location(), "e", 40, false, 4);
      addContinuation(location(), "E", 40, false, 4);
    }

float_suffix_c
  = "" {
      addContinuation(location(), "f", 40, false, 4);
      addContinuation(location(), "F", 40, false, 4);
    }

required_space_c
  = "" { addContinuation(location(), " ", 1, false, 4); }

digit_c
  = "" { addContinuation(location(), "", 100, false, 4); }

/* dynamic application hooks */
classes_c
  = "" { getClasses(location(), 100); }

properties_c
  = "" { getProperties(location(), 100); }

individuals_c
  = "" { getIndividuals(location(), 100); }

datatypes_c
  = "" { getDatatypes(location(), 95); }

iris_c
  = "" { getIRIs(location(), 90); }

prefix_c
  = "" { getPrefixes(location(), 90); }

language_tag_c
  = "" { getLanguageTags(location(), 90); }

/* completion result transport */
end
  = "" { error(returnContinuation()); }

