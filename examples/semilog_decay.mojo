from sen import AxisKind, Figure, render_svg, save_svg
from std.collections import List
from std.os import makedirs


def main() raises:
    var time: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var amplitude: List[Float64] = [1000.0, 100.0, 10.0, 1.0, 0.1]

    var figure = Figure()
    figure.line(time, amplitude, label="decay")
    figure.set_y_scale(AxisKind.LOG10)
    figure.set_title("Exponential decay")
    figure.set_x_label("time")
    figure.set_y_label("amplitude")
    figure.set_grid(True)

    makedirs("output", exist_ok=True)
    save_svg("output/semilog_decay.svg", render_svg(figure, 720.0, 480.0))
