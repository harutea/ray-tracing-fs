"use client";

import { useRef, useLayoutEffect, useContext, useMemo } from "react";
import * as THREE from "three";
import { Canvas, useFrame, useThree } from "@react-three/fiber";
import fragmentShader from "../shaders/ray-tracing-fragment.glsl";
import vertexShader from "../shaders/ray-tracing-vertex.glsl";
import useKeyControl from "./hooks/use_key_control";

const RayTracing = ({ mouseWheel, pointerDiff }) => {
  const mesh = useRef();
  const keyMove = useKeyControl();

  const uniforms = useMemo(
    () => ({
      u_time: {
        type: "f",
        value: 0.0,
      },
      u_resolution: { type: "v2", value: new THREE.Vector2() },
      u_pointerdiff: { type: "v2", value: new THREE.Vector2() },
      u_mousewheel: { type: "f", value: 0.0 },
      u_keymove: { type: "v2", value: new THREE.Vector2() },
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
    mesh.current.material.uniforms.u_mousewheel.value =
      mouseWheel.current / 40.0;
    mesh.current.material.uniforms.u_pointerdiff.value.x +=
      pointerDiff.x.current / 200.0;
    mesh.current.material.uniforms.u_pointerdiff.value.y +=
      pointerDiff.y.current / 400.0;
    mesh.current.material.uniforms.u_keymove.value.x +=
      0.1 * (Number(keyMove.right) - Number(keyMove.left));
    mesh.current.material.uniforms.u_keymove.value.y +=
      0.1 * (Number(keyMove.forward) - Number(keyMove.backward));
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
  const mouseWheel = useRef(0.0);

  const pointerDown = useRef(false);
  const startX = useRef(0);
  const startY = useRef(0);
  const diffX = useRef(0);
  const diffY = useRef(0);

  const onWheel = (e) => {
    mouseWheel.current += e.deltaY;
  };

  const onPointerDown = (e) => {
    pointerDown.current = true;
    startX.current = e.clientX;
    startY.current = e.clientY;
  };

  const onPointerUp = (e) => {
    pointerDown.current = false;
    diffX.current = 0;
    diffY.current = 0;
  };

  const onPointerMove = (e) => {
    if (!pointerDown.current) return;

    diffX.current = e.clientX - startX.current;
    diffY.current = e.clientY - startY.current;
  };

  return (
    <div style={{ display: "flex", justifyContent: "center" }}>
      <div style={{ width: "800px", height: "640px" }}>
        <Canvas
          onWheel={onWheel}
          onPointerMove={onPointerMove}
          onPointerDown={onPointerDown}
          onPointerUp={onPointerUp}
        >
          <RayTracing
            mouseWheel={mouseWheel}
            pointerDiff={{ x: diffX, y: diffY }}
          />
        </Canvas>
      </div>
    </div>
  );
};

export default Home;
