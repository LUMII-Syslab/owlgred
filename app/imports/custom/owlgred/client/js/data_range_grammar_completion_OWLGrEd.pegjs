{
  /*
   * Completion-enabled version of data_range_grammar_OWLGrEd(1).pegjs.
   *
   * Principle: completion marker rules consume no input. They record a
   * candidate immediately before PEG.js attempts the real syntax. PEG
   * backtracking then discovers all grammatically valid candidates.
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
   * Replace these no-op implementations manually when integrating the
   * grammar with the editor/schema environment.
   */
  function getIRIs(place, priority) {}
  function getPrefixes(place, priority) {}
  function getLanguageTags(place, priority) {}

  /* Kept from the original grammar because semantic actions below use them. */
  function tbl(items, props) {
    const a = Array.isArray(items) ? items : (items === null ? [] : [items]);
    if (props) Object.assign(a, props);
    return a;
  }

  function seqFirstTail(first, tail, pickIndex) {
    const out = [first];
    for (const t of tail) out.push(t[pickIndex]);
    return out;
  }

  function node(props, items) {
    return Object.assign({}, props || {}, { items: items || [] });
  }

  function listFromFirstTail(first, tail, pickIndex) {
    const out = [first];
    for (const t of tail) out.push(t[pickIndex]);
    return out;
  }
}

/*
 * Completion start rule.
 * The normal expression is optional so incomplete input can still reach
 * `end`. `end` deliberately throws the collected continuation set.
 */
Start
  = (_ Expression _)? end

Expression
  = dr:DataRange? !. { return dr; }

/* -------------------------
   dataRange / conjunction / primary
-------------------------- */

DataRange
  = head:DataConjunction
    tail:(WhitespacePlus or_c "or" WhitespacePlus DataConjunction)*
    {
      const items = listFromFirstTail(head, tail, 4);
      return node({ grammarProduction: "dataDisjunction" }, items);
    }

DataConjunction
  = head:DataPrimary
    tail:(WhitespacePlus and_c "and" WhitespacePlus DataPrimary)*
    {
      const items = listFromFirstTail(head, tail, 4);
      return node({ grammarProduction: "dataConjunction" }, items);
    }

DataPrimary
  = neg:Negation? body:DataPrimaryBody
    {
      return Object.assign(
        { negation: neg || "false" },
        body
      );
    }

Negation
  = not_c "not" WhitespacePlus { return "true"; }

DataPrimaryBody
  = r:DatatypeRestriction
    { return { dataPrimaryType: "datatypeRestriction", restriction: r }; }
  / d:Datatype
    { return { dataPrimaryType: "datatype", datatype: d }; }
  / lbrace_c "{" WhitespaceStar ll:LiteralList WhitespaceStar rbrace_c "}"
    { return { dataPrimaryType: "literalList", literalList: ll }; }
  / lparen_c "(" WhitespaceStar dr:DataRange WhitespaceStar rparen_c ")"
    { return { dataPrimaryType: "dataRange", dataRange: dr }; }

/* -------------------------
   datatype / restrictions
-------------------------- */

Datatype
  = iri:IRI
    { return { type: "IRI", value: iri }; }
  / datatype_kw_c value:(
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

DatatypeRestriction
  = dt:Datatype
    WhitespaceStar lbracket_c "[" WhitespaceStar
    head:DataRestriction
    tail:(WhitespaceStar comma_c "," WhitespaceStar DataRestriction)*
    WhitespaceStar rbracket_c "]"
    {
      const restrictions = listFromFirstTail(head, tail, 4);
      return { datatype: dt, restrictions };
    }

DataRestriction
  = f:Facet WhitespaceStar v:RestrictionValue
    { return { facet: f, value: v }; }

Facet
  = facets_c ("<=" / "<" / ">=" / ">"
  / "length" / "maxLength" / "minLength"
  / "pattern" / "langPattern")

RestrictionValue
  = Literal

/* -------------------------
   literals
-------------------------- */

LiteralList
  = first:Literal rest:(WhitespaceStar comma_c "," WhitespaceStar Literal)+
    {
      return listFromFirstTail(first, rest, 4);
    }

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

/* -------------------------
   EXACT char-classes from the source grammar
-------------------------- */

PN_CHARS_BASE
  = [A-Za-z\x80-\xD6\xD8-\xF6\xF8-\xFF]

PN_CHARS
  = [A-Za-z0-9_\-\x80-\xD6\xD8-\xF6\xF8-\xFF]

QUOTED_STRING_CHARS
  = [\x01-\x21\x23-\x5B\x5D-\xFF]

LANG_TAG_CHARS
  = [A-Za-z\-]

FULL_IRI_CHARS
  = [\x21-\x3B\x3D\x3F-\x7E\x80-\xFF]

/* -------------------------
   quoted string
-------------------------- */

QuotedString
  = s:$(quote_c "\"" QuotedStringInner* quote_c "\"") { return s; }

QuotedStringInner
  = QUOTED_STRING_CHARS
  / "\\\\"
  / "\\\""

/* -------------------------
   language tag
-------------------------- */

LanguageTag
  = language_tag_c $(LANG_TAG_CHARS*)

/* -------------------------
   IRI
-------------------------- */

IRI
  = iri_c v:FullIRI
    { return { IRItype: "fullIRI", value: v }; }
  / iri_c v:PrefixedIRI
    { return { IRItype: "abbreviatedIRI", value: v }; }
  / iri_c v:AbbreviatedIRI
    { return { IRItype: "abbreviatedIRI", value: v }; }
  / iri_c v:FullNamespaceIRI
    { return { IRItype: "fullNamespaceIRI", value: v }; }
  / iri_c v:SimpleIRI
    { return { IRItype: "simpleIRI", value: v }; }

FullIRI
  = s:$(less_c "<" FULL_IRI_CHARS+ greater_c ">") { return s; }

PrefixedIRI
  = prefix:PrefixLabel colon_c ":" name:LocalName
    { return { name: name, prefix: prefix }; }

PrefixLabel
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." &PN_CHARS)*)

AbbreviatedIRI
  = name:LocalName lbrace_c "{" prefix:Prefix rbrace_c "}"
    { return { name: name, prefix: prefix }; }

FullNamespaceIRI
  = name:LocalName lbrace_c "{" prefix:PrefixNamespace rbrace_c "}"
    { return { name: name, prefix: prefix }; }

Prefix
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." / slash_c "/" / colon_c ":")*)

PrefixNamespace
  = prefix_c $(PN_CHARS_BASE (PN_CHARS / dot_c "." / slash_c "/" / colon_c ":")*)

LocalName
  = $( (PN_CHARS_BASE / underscore_c "_" / Digit) (PN_CHARS / dot_c ".")* )

SimpleIRI
  = LocalName

BlankNode
  = blank_node_c "_:" LocalName

/* -------------------------
   whitespace
-------------------------- */

Whitespace
  = [ \t\r\n]

WhitespacePlus
  = required_space_c Whitespace+

WhitespaceStar
  = Whitespace*

_
  = Whitespace*

/* =========================================================
   Completion marker rules
   ========================================================= */

/* logical syntax */
or_c
  = "" {
      addContinuation(location(), "or", 20, true, 4);
    }

and_c
  = "" {
      addContinuation(location(), "and", 20, true, 4);
    }

not_c
  = "" {
      addContinuation(location(), "not", 20, false, 4);
    }

/* predefined datatypes */
datatype_kw_c = ""
{
    addContinuation(location(), "Literal", 10, false, 4);
    addContinuation(location(), "NCName", 10, false, 4);
    addContinuation(location(), "NMTOKEN", 10, false, 4);
    addContinuation(location(), "Name", 10, false, 4);
    addContinuation(location(), "PlainLiteral", 10, false, 4);
    addContinuation(location(), "XMLLiteral", 10, false, 4);
    addContinuation(location(), "anyURI", 10, false, 4);
    addContinuation(location(), "base64Binary", 10, false, 4);
    addContinuation(location(), "boolean", 10, false, 4);
    addContinuation(location(), "byte", 10, false, 4);
    addContinuation(location(), "date", 10, false, 4);
    addContinuation(location(), "dateTime", 10, false, 4);
    addContinuation(location(), "dateTimeStamp", 10, false, 4);
    addContinuation(location(), "decimal", 10, false, 4);
    addContinuation(location(), "double", 10, false, 4);
    addContinuation(location(), "float", 10, false, 4);
    addContinuation(location(), "hexBinary", 10, false, 4);
    addContinuation(location(), "int", 10, false, 4);
    addContinuation(location(), "integer", 10, false, 4);
    addContinuation(location(), "language", 10, false, 4);
    addContinuation(location(), "long", 10, false, 4);
    addContinuation(location(), "negativeInteger", 10, false, 4);
    addContinuation(location(), "nonNegativeInteger", 10, false, 4);
    addContinuation(location(), "nonPositiveInteger", 10, false, 4);
    addContinuation(location(), "normalizedString", 10, false, 4);
    addContinuation(location(), "positiveInteger", 10, false, 4);
    addContinuation(location(), "rational", 10, false, 4);
    addContinuation(location(), "real", 10, false, 4);
    addContinuation(location(), "short", 10, false, 4);
    addContinuation(location(), "string", 10, false, 4);
    addContinuation(location(), "time", 10, false, 4);
    addContinuation(location(), "token", 10, false, 4);
    addContinuation(location(), "unsignedByte", 10, false, 4);
    addContinuation(location(), "unsignedInt", 10, false, 4);
    addContinuation(location(), "unsignedLong", 10, false, 4);
    addContinuation(location(), "unsignedShort", 10, false, 4);
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
iri_c
  = "" { getIRIs(location(), 90); }

prefix_c
  = "" { getPrefixes(location(), 90); }

language_tag_c
  = "" { getLanguageTags(location(), 90); }

/* completion result transport */
end
  = "" { error(returnContinuation()); }
