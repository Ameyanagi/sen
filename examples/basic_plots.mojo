from sen import Plot, StepMode
from std.collections import List
from std.os import makedirs


def main() raises:
    makedirs("output", exist_ok=True)

    var x: List[Float64] = [0.0, 1.0, 2.0, 3.0]
    var response: List[Float64] = [1.0, 2.5, 1.75, 3.0]
    var uncertainty: List[Float64] = [0.15, 0.25, 0.2, 0.3]
    var stepped = Plot()
    stepped.step(x, response, mode=StepMode.POST, label="held response")
    stepped.errorbar(x, response, uncertainty, cap_size=0.12, label="uncertainty")
    stepped.title("Stepped measurements")
    stepped.xlabel("sample")
    stepped.ylabel("response")
    stepped.legend()
    stepped.save_svg("output/basic-step-errorbar.svg", 720.0, 420.0)

    var categories: List[String] = ["control", "variant A", "variant B"]
    var scores: List[Float64] = [72.0, 84.0, 91.0]
    var bars = Plot()
    bars.bar(categories, scores, label="score")
    bars.title("Experiment score")
    bars.ylabel("percent")
    bars.save_svg("output/basic-bars.svg", 640.0, 420.0)

    var samples: List[Float64] = [
        0.2,
        0.4,
        0.6,
        0.7,
        0.9,
        1.0,
        1.1,
        1.3,
        1.4,
        1.8,
    ]
    var histogram = Plot()
    histogram.histogram(samples, 0.0, 2.0, bins=5, label="observations")
    histogram.title("Response distribution")
    histogram.xlabel("response")
    histogram.ylabel("count")
    histogram.save_svg("output/basic-histogram.svg", 640.0, 420.0)

    var envelope = Plot()
    envelope.area(x, response, baseline=0.0, label="integrated response")
    envelope.title("Filled response envelope")
    envelope.xlabel("sample")
    envelope.ylabel("response")
    envelope.grid()
    envelope.save_svg("output/basic-area.svg", 720.0, 420.0)
