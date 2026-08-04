import Phaser from "phaser";
import "./style.css";

import ArenaScene from "./game/ArenaScene";

export const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: 1280,
  height: 720,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 1280,
    height: 720,
  },
  fps: {
    target: 60,
    smoothStep: false,
  },
  render: {
    antialias: true,
    roundPixels: true,
  },
  input: {
    keyboard: true,
    mouse: true,
    activePointers: 1,
  },
  backgroundColor: "#08111f",
  banner: false,
  scene: ArenaScene,
});
