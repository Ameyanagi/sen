from sen import Figure, render_svg, save_svg
from std.collections import List
from std.os import makedirs


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var fitted: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var measured: List[Float64] = [0.9, 2.2, 2.8, 4.1, 5.2]

    var figure = Figure()
    figure.line(x, fitted, label="fit")
    figure.scatter(x, measured, label="measured")
    figure.set_title("Calibration")
    figure.set_x_label("input")
    figure.set_y_label("response")
    figure.set_grid(True)

    makedirs("output", exist_ok=True)
    save_svg("output/two_series.svg", render_svg(figure, 720.0, 480.0))
