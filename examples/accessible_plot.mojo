from sen import Plot


def main() raises:
    var x: List[Float64] = [0.0, 1.0, 2.0]
    var fit: List[Float64] = [1.0, 2.0, 3.0]
    var measured: List[Float64] = [0.9, 2.2, 2.8]
    var plot = (
        Plot()
        .with_line(x, fit, label="fit")
        .with_scatter(x, measured, label="measured")
        .with_title("Calibration")
        .with_xlabel("input")
        .with_ylabel("response")
        .with_description(
            "Input on the horizontal axis and response on the vertical axis. "
            "A line shows the fitted series; points show measured observations."
        )
    )
    plot.save_svg("output/accessible-calibration.svg")
