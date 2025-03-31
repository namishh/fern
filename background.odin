package fern

import "core:c"
import "core:fmt"
import image "core:image"
import "core:slice"
import strings "core:strings"
import rl "vendor:raylib"

remove_background :: proc(item: ^image_item, model_ctx: ^model_context) {
    api := OrtGetApiBase().GetApi(ORT_API_VERSION)
    input_name: cstring

    fmt.println("Getting input and output names...")
    status := api.SessionGetInputName(model_ctx.session, 0, model_ctx.allocator, &input_name)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to get input name: %s", err_str)
        api.ReleaseStatus(status)
        return
    }
    defer api.AllocatorFree(model_ctx.allocator, cast(rawptr)input_name)

    output_name: cstring
    status = api.SessionGetOutputName(model_ctx.session, 0, model_ctx.allocator, &output_name)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to get output name: %s", err_str)
        api.ReleaseStatus(status)
        return
    }
    defer api.AllocatorFree(model_ctx.allocator, cast(rawptr)output_name)

    type_info: ^OrtTypeInfo
    status = api.SessionGetInputTypeInfo(model_ctx.session, 0, &type_info)
    if status != nil {
        fmt.println("Error: Failed to get input type info")
        return
    }
    defer api.ReleaseTypeInfo(type_info)

    tensor_info: ^OrtTensorTypeAndShapeInfo
    status = api.CastTypeInfoToTensorInfo(type_info, &tensor_info)
    if status != nil {
        fmt.println("Error: Failed to cast to tensor info")
        return
    }

    dim_count: c.size_t
    status = api.GetDimensionsCount(tensor_info, &dim_count)
    if status != nil || dim_count != 4 {
        fmt.println("Error: Unexpected input shape dimensions")
        return
    }

    dims: [4]c.int64_t
    status = api.GetDimensions(tensor_info, &dims[0], 4)
    if status != nil || dims[0] != 1 || dims[1] != 3 {
        fmt.println("Error: Failed to get dimensions or unexpected shape")
        return
    }
    model_height := int(dims[2])
    model_width := int(dims[3])

    width := int(item.width)
    height := int(item.height)
    channels := 4 // RGBA

    fmt.printfln("Image size: %d x %d", width, height)
    fmt.printfln("Model size: %d x %d", model_width, model_height)

    // Get raw pixel data
    pixels := slice.from_ptr(item.image_data, width * height * channels)
    if len(pixels) == 0 {
        fmt.println("Error: Invalid image data")
        return
    }

    fmt.println("Resizing image...")
    // Add error checking for resize operation
    resized_pixels, resize_ok := resize_raw_pixels_nearest_neighbor_safe(pixels, width, height, model_width, model_height, channels)
    if !resize_ok {
        fmt.println("Error: Failed to resize image")
        return
    }
    defer delete(resized_pixels)

    // Create input data for the model
    input_data := make([]f32, 1 * 3 * model_height * model_width)
    if len(input_data) == 0 {
        fmt.println("Error: Failed to allocate memory for input data")
        return
    }
    defer delete(input_data)

    // Preprocess image data
    mean := 128.0
    std := 256.0
    for h in 0..<model_height {
        for w in 0..<model_width {
            idx := (h * model_width + w) * channels
            if idx + 2 >= len(resized_pixels) {
                fmt.println("Error: Index out of bounds during preprocessing")
                return
            }
            r := f32(resized_pixels[idx + 0])
            g := f32(resized_pixels[idx + 1])
            b := f32(resized_pixels[idx + 2])
            
            // Calculate 1D indices with bounds checking
            r_idx := 0 * 3 * model_height * model_width + 0 * model_height * model_width + h * model_width + w
            g_idx := 0 * 3 * model_height * model_width + 1 * model_height * model_width + h * model_width + w
            b_idx := 0 * 3 * model_height * model_width + 2 * model_height * model_width + h * model_width + w
            
            if r_idx >= len(input_data) || g_idx >= len(input_data) || b_idx >= len(input_data) {
                fmt.println("Error: Calculated indices out of bounds")
                return
            }
            
            input_data[r_idx] = (r - f32(mean)) / f32(std) // R
            input_data[g_idx] = (g - f32(mean)) / f32(std) // G
            input_data[b_idx] = (b - f32(mean)) / f32(std) // B
        }
    }

    // Create tensor for model input
    shape := [4]c.int64_t{1, 3, c.int64_t(model_height), c.int64_t(model_width)}
    input_tensor: ^OrtValue
    memory_info: ^OrtMemoryInfo
    status = api.CreateCpuMemoryInfo(.OrtArenaAllocator, .OrtMemTypeDefault, &memory_info)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to create memory info: %s", err_str)
        api.ReleaseStatus(status)
        return
    }
    defer api.ReleaseMemoryInfo(memory_info)

    status = api.CreateTensorWithDataAsOrtValue(
        memory_info,
        &input_data[0],
        size_of(f32) * len(input_data),
        &shape[0],
        4,
        .ONNX_TENSOR_ELEMENT_DATA_TYPE_FLOAT,
        &input_tensor,
    )
    if status != nil {
        fmt.println("Error: Failed to create input tensor")
        return
    }
    defer api.ReleaseValue(input_tensor)

    // Run model inference
    fmt.println("Running model inference...")
    outputs: [1]^OrtValue
    inputs := []^OrtValue{input_tensor}
    status = api.Run(
        model_ctx.session,
        nil,
        &input_name,
        &inputs[0],
        1,
        &output_name,
        1,
        &outputs[0],
    )
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to run model: %s", err_str)
        api.ReleaseStatus(status)
        return
    }
    defer api.ReleaseValue(outputs[0])

    // Get output data
    output_data: ^f32
    status = api.GetTensorMutableData(outputs[0], cast(^rawptr)&output_data)
    if status != nil {
        fmt.println("Error: Failed to get output tensor data")
        return
    }

    total_elements := model_height * model_width
    output_slice := slice.from_ptr(output_data, total_elements)

    // Apply alpha mask to resized_pixels
    fmt.println("Applying alpha mask...")
    for h in 0..<model_height {
        for w in 0..<model_width {
            idx := (h * model_width + w)
            if idx >= len(output_slice) {
                fmt.println("Error: Output index out of bounds")
                return
            }
            alpha := output_slice[idx] * 255.0
            pixel_idx := idx * channels
            if pixel_idx + 3 >= len(resized_pixels) {
                fmt.println("Error: Pixel index out of bounds")
                return
            }
            resized_pixels[pixel_idx + 3] = u8(clamp(alpha, 0, 255))
        }
    }

    fmt.println("Resizing image back to original size...")
    processed_pixels, resize_back_ok := resize_raw_pixels_nearest_neighbor_safe(resized_pixels, model_width, model_height, width, height, channels)
    if !resize_back_ok {
        fmt.println("Error: Failed to resize image back to original size")
        return
    }
    defer delete(processed_pixels)

    fmt.println("Updating texture...")
    rl.UpdateTexture(item.texture, raw_data(processed_pixels))
    fmt.println("Background removal completed successfully")
}

resize_raw_pixels_nearest_neighbor_safe :: proc(
    src_pixels: []u8,
    src_width, src_height: int,
    dst_width, dst_height: int,
    channels: int,
    allocator := context.allocator,
) -> ([]u8, bool) {
    if src_width <= 0 || src_height <= 0 || dst_width <= 0 || dst_height <= 0 || channels <= 0 {
        fmt.println("Error: Invalid dimensions for resize")
        return nil, false
    }

    if len(src_pixels) < src_width * src_height * channels {
        fmt.println("Error: Source pixel buffer too small")
        return nil, false
    }

    dst_pixels, err := make([]u8, dst_width * dst_height * channels, allocator)
    if err != nil || dst_pixels == nil {
        fmt.println("Error: Failed to allocate memory for resized image")
        return nil, false
    }

    for y in 0..<dst_height {
        for x in 0..<dst_width {
            src_x: f32= f32(x) * f32(src_width) / f32(dst_width)
            src_y: f32= f32(y) * f32(src_height) / f32(dst_height)
            
            // Bounds check
            src_x =  clamp(f32(src_x), f32(0), f32(src_width-1))
            src_y = clamp(f32(src_y), f32(0), f32(src_height-1))
            
            src_idx := (int(src_y) * src_width + int(src_x)) * channels
            dst_idx := (y * dst_width + x) * channels
            
            if src_idx + channels > len(src_pixels) || dst_idx + channels > len(dst_pixels) {
                fmt.println("Error: Index out of bounds during resize")
                delete(dst_pixels)
                return nil, false
            }
            
            for c in 0..<channels {
                dst_pixels[dst_idx + c] = src_pixels[src_idx + c]
            }
        }
    }
    
    return dst_pixels, true
}