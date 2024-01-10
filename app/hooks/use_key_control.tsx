import React from "react";
import { useState, useEffect } from "react";

const useKeyControl = () => {
  const keyMap = {
    KeyW: "forward",
    KeyS: "backward",
    KeyA: "left",
    KeyD: "right",
  };
  const keyToMove = (key) => keyMap[key];

  const [movement, setMovement] = useState({
    forward: false,
    backward: false,
    left: false,
    right: false,
  });

  useEffect(() => {
    const onKeyDown = (e) =>
      setMovement((prevState) => ({ ...prevState, [keyToMove(e.code)]: true }));
    const onKeyUp = (e) =>
      setMovement((prevState) => ({
        ...prevState,
        [keyToMove(e.code)]: false,
      }));

    document.addEventListener("keydown", onKeyDown);
    document.addEventListener("keyup", onKeyUp);

    return () => {
      document.removeEventListener("keydown", onKeyDown);
      document.removeEventListener("keyup", onKeyUp);
    };
  }, []);

  return movement;
};

export default useKeyControl;
