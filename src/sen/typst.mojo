"""Bounded optional Typst compilation for mathematical SVG text."""

from std.math import isfinite
from std.pathlib import Path
from std.subprocess import run
from std.tempfile import TemporaryDirectory


struct TypstOptions(Copyable, Equatable):
    """Configuration for Sen's optional, local Typst compiler boundary.

    Plain text never uses these options or starts a process. Mathematical text
    is trusted Typst markup and is compiled inside a fresh temporary root.
    """

    var _executable: String
    var _timeout_seconds: Int
    var _max_source_bytes: Int
    var _max_output_bytes: Int
    var _id_prefix: String

    def __init__(
        out self,
        *,
        executable: StringSlice = "typst",
        timeout_seconds: Int = 10,
        max_source_bytes: Int = 65_536,
        max_output_bytes: Int = 8_388_608,
        id_prefix: StringSlice = "sen-typst",
    ):
        self._executable = String(executable)
        self._timeout_seconds = timeout_seconds
        self._max_source_bytes = max_source_bytes
        self._max_output_bytes = max_output_bytes
        self._id_prefix = String(id_prefix)

    def executable(self) -> String:
        """Return an owned copy of the configured executable path."""
        return self._executable.copy()

    def timeout_seconds(self) -> Int:
        """Return the wall-clock compiler timeout in whole seconds."""
        return self._timeout_seconds

    def max_source_bytes(self) -> Int:
        """Return the maximum accepted user-fragment size."""
        return self._max_source_bytes

    def max_output_bytes(self) -> Int:
        """Return the maximum accepted compiled SVG size."""
        return self._max_output_bytes

    def id_prefix(self) -> String:
        """Return the SVG ID prefix used for embedded Typst resources."""
        return self._id_prefix.copy()

    def with_id_prefix(self, id_prefix: StringSlice) raises -> Self:
        """Return a copy with a validated caller-owned SVG ID namespace."""
        var result = self.copy()
        result._id_prefix = String(id_prefix)
        result.validate()
        return result^

    def validate(self) raises:
        """Reject empty executable paths and unsafe resource limits."""
        if self._executable.byte_length() == 0:
            raise Error("Typst executable must not be empty")
        if self._timeout_seconds < 1 or self._timeout_seconds > 300:
            raise Error("Typst timeout must be within 1..300 seconds")
        if self._max_source_bytes < 1 or self._max_source_bytes > 1_048_576:
            raise Error("Typst source limit must be within 1..1048576 bytes")
        if self._max_output_bytes < 1 or self._max_output_bytes > 67_108_864:
            raise Error("Typst output limit must be within 1..67108864 bytes")
        if self._id_prefix.byte_length() == 0 or self._id_prefix.byte_length() > 64:
            raise Error("Typst ID prefix must contain 1..64 ASCII characters")
        var first = True
        for scalar in self._id_prefix.codepoint_slices():
            var is_letter = (scalar >= "A" and scalar <= "Z") or (
                scalar >= "a" and scalar <= "z"
            )
            var is_digit = scalar >= "0" and scalar <= "9"
            if (first and not is_letter and not scalar == "_") or (
                not first
                and not is_letter
                and not is_digit
                and not scalar == "_"
                and not scalar == "-"
            ):
                raise Error("Typst ID prefix must match [A-Za-z_][A-Za-z0-9_-]*")
            first = False

    def __eq__(self, other: Self) -> Bool:
        return (
            self._executable == other._executable
            and self._timeout_seconds == other._timeout_seconds
            and self._max_source_bytes == other._max_source_bytes
            and self._max_output_bytes == other._max_output_bytes
            and self._id_prefix == other._id_prefix
        )


def _shell_quote(value: StringSlice) -> String:
    """Quote exactly one argument for the POSIX shell used by ``run``."""
    var quoted = String("'")
    for scalar in value.codepoint_slices():
        if scalar == "'":
            quoted += "'\"'\"'"
        else:
            quoted += scalar
    quoted += "'"
    return quoted^


def _format_typst_decimal(value: Float64) raises -> String:
    """Format a finite positive point value without exponent notation."""
    if not isfinite(value) or value <= 0.0 or value > 1_000_000.0:
        raise Error("Typst geometry must be finite, positive, and at most 1000000")
    var scaled = Int(value * 1_000.0 + 0.5)
    var whole = scaled // 1_000
    var remainder = scaled % 1_000
    var result = String(whole)
    if remainder == 0:
        return result^
    var fractional = String(remainder)
    while fractional.byte_length() < 3:
        fractional = String("0") + fractional
    while fractional.endswith("0"):
        var shortened = String(fractional[byte = : fractional.byte_length() - 1])
        fractional = shortened^
    result += "."
    result += fractional
    return result^


def _typst_document(
    source: StringSlice,
    font_size_points: Float64,
    foreground: StringSlice,
    width_points: Float64,
    height_points: Float64,
) raises -> String:
    """Wrap trusted Typst markup in a fixed, transparent, centered page."""
    if foreground.byte_length() != 7 or not foreground.startswith("#"):
        raise Error("Typst foreground must use strict #RRGGBB form")
    return (
        "#set page(width: "
        + _format_typst_decimal(width_points)
        + "pt, height: "
        + _format_typst_decimal(height_points)
        + "pt, margin: 0pt, fill: none)\n#set text(size: "
        + _format_typst_decimal(font_size_points)
        + 'pt, fill: rgb("'
        + String(foreground)
        + '"), top-edge: "ascender", bottom-edge: "descender")\n'
        + "#align(center + horizon)[\n"
        + String(source)
        + "\n]\n"
    )


def _compile_typst_svg(
    source: StringSlice,
    font_size_points: Float64,
    foreground: StringSlice,
    width_points: Float64,
    height_points: Float64,
    options: TypstOptions,
) raises -> String:
    """Compile one trusted fragment through a bounded local Typst process."""
    options.validate()
    if source.byte_length() == 0:
        raise Error("Typst math source must not be empty")
    if source.byte_length() > options._max_source_bytes:
        raise Error(
            "Typst source exceeds the configured byte limit; got ",
            source.byte_length(),
            ", limit ",
            options._max_source_bytes,
        )
    var document = _typst_document(
        source,
        font_size_points,
        foreground,
        width_points,
        height_points,
    )
    # The wrapper is bounded too, independent of the public fragment limit.
    if document.byte_length() > options._max_source_bytes + 1_024:
        raise Error("Typst wrapped source exceeds the internal byte limit")

    var result = String()
    var failure = String()

    # Own the temporary directory directly instead of entering its context.
    # Mojo 1.0's ``TemporaryDirectory.__exit__(Error) -> Bool`` reports cleanup
    # success as ``True``, which context-manager lowering interprets as
    # permission to suppress an unrelated error raised by Path or run below.
    # Direct ownership keeps destructor cleanup automatic while letting every
    # error escape normally.
    var temporary_directory = TemporaryDirectory(prefix="sen-typst-")
    var directory = temporary_directory.name.copy()
    var source_path = directory + "/fragment.typ"
    var svg_path = directory + "/fragment.svg"
    var diagnostic_path = directory + "/diagnostic.txt"
    var status_path = directory + "/status.txt"
    var timeout_path = directory + "/timed-out"
    Path(source_path).write_text(document)

    # Stable Mojo's shell helper does not expose the child status. A status
    # file and watchdog make both failure and wall-time bounds explicit.
    # Every dynamic shell argument is independently single-quoted.
    var command = (
        "exec 2>/dev/null; ( "
        + _shell_quote(options._executable)
        + " compile "
        + _shell_quote(source_path)
        + " "
        + _shell_quote(svg_path)
        + " --format svg --creation-timestamp 0 --root "
        + _shell_quote(directory)
        + " 2>"
        + _shell_quote(diagnostic_path)
        + " ) & sen_typst_pid=$!; "
        + '( sen_typst_tick=0; while [ "$sen_typst_tick" -lt '
        + String(options._timeout_seconds * 10)
        + ' ]; do sleep 0.1; if ! kill -0 "$sen_typst_pid" 2>/dev/null; '
        + "then exit 0; fi; sen_typst_tick=$((sen_typst_tick + 1)); done; "
        + 'if kill -0 "$sen_typst_pid" 2>/dev/null; then : >'
        + _shell_quote(timeout_path)
        + '; kill -TERM "$sen_typst_pid" 2>/dev/null; sleep 1; '
        + 'kill -KILL "$sen_typst_pid" 2>/dev/null; fi ) '
        + "</dev/null >/dev/null 2>&1 & "
        + 'sen_watchdog_pid=$!; wait "$sen_typst_pid"; sen_status=$?; '
        + 'kill "$sen_watchdog_pid" 2>/dev/null; '
        + 'wait "$sen_watchdog_pid" 2>/dev/null; '
        + "printf '%s' \"$sen_status\" >"
        + _shell_quote(status_path)
    )
    _ = run(command^)

    if Path(timeout_path).exists():
        failure = String("Typst compilation exceeded ")
        failure.write(options._timeout_seconds)
        failure += " seconds"
    elif not Path(status_path).exists():
        failure = String("Typst produced no status")
    elif Path(status_path).stat().st_size <= 0:
        failure = String("Typst produced an empty status")
    elif Path(status_path).stat().st_size > 16:
        failure = String("Typst status exceeds the internal byte limit")
    else:
        var status = Path(status_path).read_text()
        if status != "0":
            failure = String("Typst compilation failed with status ") + status
            if Path(diagnostic_path).exists():
                var observed = Path(diagnostic_path).stat().st_size
                if observed > 65_536:
                    failure += "; diagnostics exceed 65536 bytes"
                elif observed > 0:
                    failure += ": "
                    failure += Path(diagnostic_path).read_text()
        elif not Path(svg_path).exists():
            failure = String("Typst produced no SVG")
        elif Path(svg_path).stat().st_size <= 0:
            failure = String("Typst produced an empty SVG")
        elif Path(svg_path).stat().st_size > options._max_output_bytes:
            failure = String("Typst SVG exceeds the configured byte limit; got ")
            failure.write(Path(svg_path).stat().st_size)
            failure += ", limit "
            failure.write(options._max_output_bytes)
        else:
            result = Path(svg_path).read_text()
            if not result.startswith("<svg ") or (
                not result.endswith("</svg>") and not result.endswith("</svg>\n")
            ):
                failure = String("Typst produced an unsupported SVG document shape")
    if failure.byte_length() > 0:
        raise Error(failure)
    return result^
