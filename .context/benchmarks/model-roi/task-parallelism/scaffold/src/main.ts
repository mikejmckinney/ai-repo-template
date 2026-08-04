import Phaser from "phaser";

class EmptyScene extends Phaser.Scene {}

new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  width: 1280,
  height: 720,
  scene: EmptyScene,
});
