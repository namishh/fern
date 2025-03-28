<samp>

## fern - a (wip) fast raylib image editor

![png](https://iili.io/3uv104S.png)

### steps to run locally

1. install odin, install raylib, install onnx
2. copy `onnxruntime.lib` (windows) to the root directory of the project
3. download the models

```bash
$ mkdir -p models
$ curl  "https://github.com/imgly/background-removal-js/raw/4306d99530d3ae9ec11a892a23802be28f367518/bundle/models/medium" -o "models/rmbg.onnx"
```

4. run the project

```bash
$ odin run .
```

</samp>