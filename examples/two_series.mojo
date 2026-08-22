from sen import Plot
from std.collections import List


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0, 4.0]
    var fitted: List[Float64] = [1.0, 2.0, 3.0, 4.0, 5.0]
    var measured: List[Float64] = [0.9, 2.2, 2.8, 4.1, 5.2]

    var plot = Plot()
    plot.line(x, fitted, label="fit")
    plot.scatter(x, measured, label="measured")
    plot.title("Calibration")
    plot.xlabel("input")
    plot.ylabel("response")
    plot.grid()

    plot.save_svg("output/two_series.svg", width=720.0, height=480.0)
