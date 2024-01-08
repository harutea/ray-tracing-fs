"use client";

import { useRef, useLayoutEffect, useContext, useMemo } from "react";
import * as THREE from "three";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import fragmentShader from "./shaders/ray-tracing-fragment.glsl";
import vertexShader from "./shaders/ray-tracing-vertex.glsl";

const RayTracing = () => {
  const mesh = useRef();

  const uniforms = useMemo(
    () => ({
      u_time: {
        type: "f",
        value: 0.0,
      },
      u_resolution: { type: "v2", value: new THREE.Vector2() },
      u_mouse: { type: "v2", value: new THREE.Vector2() },
    }),
    [],
  );

  const { gl } = useThree();
  useFrame((state) => {
    if (!mesh.current) return;
    const { clock } = state;
    mesh.current.material.uniforms.u_time.value = clock.getElapsedTime();
    const size = new THREE.Vector2();
    gl.getSize(size);
    mesh.current.material.uniforms.u_resolution.value.x = size.x;
    mesh.current.material.uniforms.u_resolution.value.y = size.y;
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
  return (
    <div style={{ width: "100vw", height: "100vh" }}>
      <Canvas>
        <RayTracing />
      </Canvas>
    </div>
  );
};

export default Home;
