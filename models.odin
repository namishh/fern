package fern

import "core:c"
import "core:fmt"
import strings "core:strings"

model_context :: struct {
    env:        ^OrtEnv,
    session:    ^OrtSession,
    allocator:  ^OrtAllocator,
    model_path: string,
}

init_onnx_model :: proc(model_path: string) -> (model_context, bool) {
    fmt.printfln("Loading model from: %s", string(model_path)) 

    ctx: model_context
    ctx.model_path = model_path

    api_base := OrtGetApiBase()
    api := api_base.GetApi(ORT_API_VERSION)

    status := api.CreateEnv(.ORT_LOGGING_LEVEL_WARNING, "fern", &ctx.env)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to create environment: %s", err_str)
        api.ReleaseStatus(status)
        return ctx, false
    }
    fmt.println("Environment created successfully")

    options: ^OrtSessionOptions
    status = api.CreateSessionOptions(&options)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to create session options: %s", err_str)
        api.ReleaseStatus(status)
        api.ReleaseEnv(ctx.env)
        return ctx, false
    }
    defer api.ReleaseSessionOptions(options)
    fmt.println("Session options created successfully")

    status = api.CreateSession(ctx.env, strings.clone_to_cstring(model_path), options, &ctx.session)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to create session: %s", err_str)
        api.ReleaseStatus(status)
        api.ReleaseEnv(ctx.env)
        return ctx, false
    }
    fmt.println("Session created successfully")

    status = api.GetAllocatorWithDefaultOptions(&ctx.allocator)
    if status != nil {
        err_msg := api.GetErrorMessage(status)
        err_str := strings.clone_from_cstring(err_msg)
        fmt.printfln("Failed to get allocator: %s", err_str)
        api.ReleaseStatus(status)
        api.ReleaseSession(ctx.session)
        api.ReleaseEnv(ctx.env)
        return ctx, false
    }

    fmt.printfln("Model loaded successfully: %s", string(model_path))
    return ctx, true
}

deinit_onnx_model :: proc(ctx: ^model_context) {
    api_base := OrtGetApiBase()
    api := api_base.GetApi(ORT_API_VERSION)
    if ctx.allocator != nil do api.ReleaseAllocator(ctx.allocator)
    if ctx.session != nil do api.ReleaseSession(ctx.session)
    if ctx.env != nil do api.ReleaseEnv(ctx.env)
}