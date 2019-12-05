using PyCall

scanfile = "/data/datasets/Riegel-Scans/calib/calib.e57"

PyCall.pythonenv(`conda remove pdal`) |> run

const pdal = pyimport_conda("pdal", "pdal")

pyimport("pdal")

const e57 = pyimport("pye57")
