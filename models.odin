package fern

import "core:c"
import "core:fmt"
import "core:os"
import strings "core:strings"

model_context :: struct {
	api:              ^OrtApi,
	env:              ^OrtEnv,
	encoder_session:  ^OrtSession,
	decoder_session:  ^OrtSession,
	memory_info:      ^OrtMemoryInfo,
	image_embeddings: ^f32,
	embedding_dims:   [4]i64,
	model_width:      int,
	model_height:     int,
}


init_onnx_model :: proc(
	model_encoder_path: string,
	model_decoder_path: string,
) -> Maybe(^model_context) {

	ctx := new(model_context)
	if ctx == nil {
		fmt.println("Failed to allocate memory for model context")
		return nil
	}

	ctx.api = OrtGetApiBase().GetApi(ORT_API_VERSION)
	if ctx.api == nil {
		fmt.println("Failed to get API base")
		free(ctx)
		return nil
	}

	status := ctx.api.CreateEnv(.ORT_LOGGING_LEVEL_WARNING, "onnx_model", &ctx.env)

	if status != nil {
		fmt.println("Failed to create environment")
		ctx.api.ReleaseStatus(status)
		free(ctx)
		return nil

	}

	options: ^OrtSessionOptions
	status = ctx.api.CreateSessionOptions(&options)
	if status != nil {
		fmt.println("Failed to create session options")
		ctx.api.ReleaseStatus(status)
		ctx.api.ReleaseEnv(ctx.env)
		free(ctx)
		return nil
	}


	encoder_path_cstr := strings.clone_to_cstring(model_encoder_path, context.temp_allocator)
	fmt.printf("Attempting to load encoder model from: %s\n", encoder_path_cstr)

	status = ctx.api.CreateSession(ctx.env, encoder_path_cstr, options, &ctx.encoder_session)
	if status != nil {
		error_message := ctx.api.GetErrorMessage(status)
		fmt.printf("Failed to create encoder session: %s\n", error_message)

		if !os.exists(model_encoder_path) {
			fmt.printf("File does not exist: %s\n", model_encoder_path)
		}

		ctx.api.ReleaseStatus(status)
		ctx.api.ReleaseSessionOptions(options)
		ctx.api.ReleaseEnv(ctx.env)
		free(ctx)
		return nil
	}

	decoder_path_cstr := strings.clone_to_cstring(model_decoder_path, context.temp_allocator)
	fmt.printf("Attempting to load decoder model from: %s\n", decoder_path_cstr)

	status = ctx.api.CreateSession(ctx.env, decoder_path_cstr, options, &ctx.decoder_session)
	if status != nil {
		error_message := ctx.api.GetErrorMessage(status)
		fmt.printf("Failed to create encoder session: %s\n", error_message)

		if !os.exists(model_decoder_path) {
			fmt.printf("File does not exist: %s\n", model_decoder_path)
		}

		ctx.api.ReleaseStatus(status)
		ctx.api.ReleaseSession(ctx.encoder_session)
		ctx.api.ReleaseSessionOptions(options)
		ctx.api.ReleaseEnv(ctx.env)
		free(ctx)
		return nil
	}

	status = ctx.api.CreateCpuMemoryInfo(.OrtArenaAllocator, .OrtMemTypeDefault, &ctx.memory_info)

	if status != nil {
		fmt.println("Failed to create memory info")
		ctx.api.ReleaseStatus(status)
		ctx.api.ReleaseSession(ctx.encoder_session)
		ctx.api.ReleaseSession(ctx.decoder_session)
		ctx.api.ReleaseSessionOptions(options)
		ctx.api.ReleaseEnv(ctx.env)
		free(ctx)
		return nil
	}

	ctx.api.ReleaseSessionOptions(options)
	fmt.println("Model loaded successfully")

	return ctx

}


deinit_onnx_model :: proc(ctx: ^model_context) {
	if ctx == nil {
		return
	}

	if ctx.encoder_session != nil {
		ctx.api.ReleaseSession(ctx.encoder_session)
	}

	if ctx.decoder_session != nil {
		ctx.api.ReleaseSession(ctx.decoder_session)
	}

	if ctx.memory_info != nil {
		ctx.api.ReleaseMemoryInfo(ctx.memory_info)
	}

	if ctx.env != nil {
		ctx.api.ReleaseEnv(ctx.env)
	}

	if ctx.image_embeddings != nil {
		free(ctx.image_embeddings)
	}

	fmt.println("Model deinitialized successfully\n")
}
