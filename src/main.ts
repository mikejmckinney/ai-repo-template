import Phaser from "phaser";
import "./styles.css";
import { VectorSiegeScene } from "./game/vector-siege-scene";

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  backgroundColor: "#08111f",
  banner: false,
  disableContextMenu: true,
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: 1280,
    height: 720,
    min: { width: 640, height: 360 },
    max: { width: 1920, height: 1080 },
  },
  fps: {
    target: 60,
    smoothStep: false,
  },
  input: {
    keyboard: true,
    mouse: true,
    touch: true,
    activePointers: 1,
  },
  scene: [VectorSiegeScene],
});
