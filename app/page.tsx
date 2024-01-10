"use client";

import { useRef, useLayoutEffect, useContext, useMemo } from "react";
import * as THREE from "three";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import fragmentShader from "../shaders/ray-tracing-fragment.glsl";
import vertexShader from "../shaders/ray-tracing-vertex.glsl";

const RayTracing = ({ mousewheel }) => {
  const mesh = useRef();

  const uniforms = useMemo(
    () => ({
      u_time: {
        type: "f",
        value: 0.0,
      },
      u_resolution: { type: "v2", value: new THREE.Vector2() },
      u_mousepos: { type: "v2", value: new THREE.Vector2() },
      u_mousewheel: { type: "f", value: 0.0 },
    }),
    [],
  );

  const { gl } = useThree();

  useFrame((state) => {
    if (!mesh.current) return;
    const { clock, mouse, wheel } = state;
    mesh.current.material.uniforms.u_time.value = clock.getElapsedTime();
    const size = new THREE.Vector2();
    gl.getSize(size);
    mesh.current.material.uniforms.u_resolution.value.x = size.x;
    mesh.current.material.uniforms.u_resolution.value.y = size.y;
    mesh.current.material.uniforms.u_mousewheel.value =
      mousewheel.current / 40.0;
  });

  return (
    <mesh ref={mesh}>
      <planeGeometry args={[2, 2]} />
      <shaderMaterial
        fragmentShader={fragmentShader}
        vertexShader={vertexShader}
        uniforms={uniforms}
      />
    </mesh>
  );
};

const Home = () => {
  const mousewheel = useRef(0.0);
  const onWheel = (e) => {
    console.log(e.deltaY);
    mousewheel.current += e.deltaY;
  };
  return (
    <div style={{ display: "flex", justifyContent: "center" }}>
      <div style={{ width: "800px", height: "450px" }}>
        <Canvas onWheel={onWheel}>
          <RayTracing mousewheel={mousewheel} />
        </Canvas>
      </div>
    </div>
  );
};

export default Home;
