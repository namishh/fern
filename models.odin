package fern

import "core:fmt"
import "core:os"
import strings "core:strings"

model_context :: struct {
	env:        ^OrtEnv,
	session:    ^OrtSession,
	allocator:  ^OrtAllocator,
	model_path: string,
}

init_onnx_model :: proc(model_path: string) -> (model_context, bool) {
	fmt.printfln("Loading model from: %s", model_path)

	model_data, ok := os.read_entire_file(model_path)
	if !ok {
		fmt.println("Failed to read model file:", model_path)
		return model_context{}, false
	}
	defer delete(model_data)

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

	status = api.CreateSessionFromArray(
		ctx.env,
		raw_data(model_data),
		len(model_data),
		options,
		&ctx.session,
	)
	if status != nil {
		err_msg := api.GetErrorMessage(status)
		err_str := strings.clone_from_cstring(err_msg)
		fmt.printfln("Failed to create session from array: %s", err_str)
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

	fmt.printfln("Model loaded successfully: %s", model_path)
	return ctx, true
}

deinit_onnx_model :: proc(ctx: ^model_context) {
    api_base := OrtGetApiBase()
    api := api_base.GetApi(ORT_API_VERSION)
    
    api.ReleaseAllocator(ctx.allocator)
    fmt.println("Allocator released")
    api.ReleaseSession(ctx.session)
    fmt.println("Session released")
    api.ReleaseEnv(ctx.env)
    fmt.println("Environment released")
    
    
    ctx.allocator = nil
    ctx.session = nil
    ctx.env = nil
    delete(ctx.model_path)
    free(ctx)
}