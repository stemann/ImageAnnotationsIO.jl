# ImageAnnotationsIO

[![Build Status](https://github.com/IHPSystems/ImageAnnotationsIO.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/IHPSystems/ImageAnnotationsIO.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/IHPSystems/ImageAnnotationsIO.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/IHPSystems/ImageAnnotationsIO.jl)
[![Code Style: Blue](https://img.shields.io/badge/code%20style-blue-4495d1.svg)](https://github.com/invenia/BlueStyle)

ImageAnnotationsIO provides methods for loading and saving [image annotations](https://github.com/IHPSystems/ImageAnnotations.jl) using common formats, like the [CVAT XML annotation format](https://opencv.github.io/cvat/docs/manual/advanced/xml_format/), or the [LabelMe XML format](https://github.com/CSAILVision/LabelMeAnnotationTool/blob/master/Annotations/example_folder/img1.xml).

There is currently support for loading and saving:

- Bounding box annotations (for object detection).
- Image annotations (for image classification).
- Oriented bounding box annotations (for object detection).
- Polygon annotations (for object detection).

## Usage

### CVAT XML using decimal floating-point coordinates

The following example loads and saves CVAT XML using decimal floating-point representation of coordinates:

```julia
using DecFP
using ImageAnnotationsIO

cvat_xml_serializer = CVATXMLSerializer{Dec128}()

dataset = load(input_path, cvat_xml_serializer)

save(output_path, dataset, cvat_xml_serializer)
```

### Converting LabelMe XML to CVAT XML

The following example loads a dataset in the form of directories containing LabelMe XML format files, and saves it in the form of a single CVAT XML file.

```julia
using Downloads
using ImageAnnotations
using ImageAnnotationsIO
using ImageIO

base_path = mktempdir()

# Download LabelMe XML dummy data
input_path = joinpath(base_path, "example_folder")
mkdir(input_path)
Downloads.download("https://raw.githubusercontent.com/CSAILVision/LabelMeAnnotationTool/master/Annotations/example_folder/img1.xml", joinpath(input_path, "img1.xml"))
Downloads.download("https://raw.githubusercontent.com/CSAILVision/LabelMeAnnotationTool/master/Images/example_folder/img1.jpg", joinpath(input_path, "img1.jpg"))

output_path = joinpath(base_path, "example_folder_cvat.xml")

labelme_xml_serializer = LabelMeXMLSerializer{Float64}() # Serialize/Deserialize LabelMe XML using Float64 coordinate type
cvat_xml_serializer = CVATXMLSerializer{Float64}() # Serialize/Deserialize CVAT XML using Float64 coordinate type

data_set = load_dataset_dir(input_path, labelme_xml_serializer; base_path = base_path, image_base_path = base_path)

save(output_path, data_set, cvat_xml_serializer)
```

Please note that the example will issue a few warnings related to the current lack of support for object segmentation annotations.
