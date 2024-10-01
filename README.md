# ray-tracing-fs

Ray Tracing (Path Tracing) in Fragment Shader using React Three Fiber, utilizing ShaderMaterial from Three.js.

Based on [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)

![preview](/resources/ray-tracing-fs-preview.png)

## Dependency
- Next.js
- Three.js
- React Three Fiber

## Running Development Server
```console
$ npm i
$ run npm dev
```

## Camera Controls
- Mouse Wheel : Change the vertical field of view
- Drag : Change the horizontal position of camera
- Key 'W' and 'S' : Change the focal length

## Shaders
The shader files are in `/shaders`.
- [Fragment Shader](/shaders/ray-tracing-fragment.glsl)
- [Vertex Shader](/shaders/ray-tracing-vertex.glsl)

## References
- [Ray Tracing in One Weekend](https://raytracing.github.io/books/RayTracingInOneWeekend.html)
