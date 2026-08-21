from sen import Figure, MissingPolicy
from std.collections import List


def main() raises:
    var nan = Float64("nan")
    var time: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0]
    var signal: List[Float64] = [0.0, 0.8, nan, nan, -0.4, 0.3, 0.9]

    var figure = Figure()
    figure.line(time, signal, missing=MissingPolicy.SEGMENT)
    figure.set_title("Gapped signal")
    figure.set_x_label("time")
    figure.set_y_label("signal")
    figure.set_grid(True)

    figure.save_svg("output/gapped_signal.svg", width=720, height=480)
