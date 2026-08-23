"""Plain text and explicitly optional Typst mathematical markup."""


struct TextKind(Copyable, Equatable, ImplicitlyCopyable):
    """A nominal discriminator for Sen's deliberately small text vocabulary."""

    var _value: Int

    comptime PLAIN = TextKind(_value=0)
    comptime TYPST_MATH = TextKind(_value=1)

    def __init__(out self, *, _value: Int):
        """Construct a text-kind discriminant for library-defined constants."""
        self._value = _value

    def __eq__(self, other: Self) -> Bool:
        """Return whether both values select the same text interpretation."""
        return self._value == other._value

    def validate(self) raises:
        """Reject discriminants outside Sen's fixed text vocabulary."""
        if self._value < 0 or self._value > 1:
            raise Error("text kind is outside Sen's vocabulary")


struct Text(Copyable, Equatable, ImplicitlyCopyable):
    """Owned text plus an explicit, renderer-independent interpretation.

    ``plain`` is the dependency-free default path. ``typst_math`` marks trusted
    Typst markup for compilation only when SVG rendering reaches that value;
    construction does not parse, execute, normalize, or alter the source.
    """

    var _kind: TextKind
    var _source: String

    def __init__(out self, *, _kind: TextKind, _source: StringSlice):
        """Construct internal storage while preserving ``_source`` exactly."""
        self._kind = _kind
        self._source = String(_source)

    @staticmethod
    def plain(source: StringSlice) -> Self:
        """Own and return dependency-free plain text without normalization."""
        return Self(_kind=TextKind.PLAIN, _source=source)

    @staticmethod
    def typst_math(source: StringSlice) -> Self:
        """Mark trusted Typst markup, including its ``$...$`` math delimiters."""
        return Self(_kind=TextKind.TYPST_MATH, _source=source)

    def kind(self) -> TextKind:
        """Return the exact nominal text interpretation without raising."""
        return self._kind

    def source(self) -> String:
        """Return an owned copy of the exactly preserved source."""
        return self._source.copy()

    def validate(self) raises:
        """Validate the embedded text interpretation explicitly."""
        self._kind.validate()

    def __eq__(self, other: Self) -> Bool:
        """Return exact kind-and-source equality without raising."""
        return self._kind == other._kind and self._source == other._source
