import Phaser from "phaser";
import { VectorSiegeScene } from "./game/vector-siege-scene";

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: 1280,
  height: 720,
  backgroundColor: "#08111f",
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 1280,
    height: 720,
  },
  fps: {
    target: 60,
    smoothStep: true,
  },
  input: {
    keyboard: true,
    mouse: true,
    touch: true,
    activePointers: 1,
  },
  disableContextMenu: true,
  scene: VectorSiegeScene,
});
