import Phaser from "phaser";
import "./styles.css";
import { ArenaScene } from "./game/arena-scene";
import { COLORS, GAME_HEIGHT, GAME_WIDTH } from "./game/constants";
import { GameUi } from "./game/dom-ui";

const ui = new GameUi();
const scene = new ArenaScene(ui);

const game = new Phaser.Game({
  type: Phaser.AUTO,
  parent: "game",
  scale: {
    mode: Phaser.Scale.FIT,
    autoCenter: Phaser.Scale.CENTER_BOTH,
    width: GAME_WIDTH,
    height: GAME_HEIGHT,
  },
  backgroundColor: COLORS.background,
  render: {
    antialias: true,
    roundPixels: true,
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
  banner: false,
  scene,
  callbacks: {
    postBoot: (bootedGame) => {
      bootedGame.canvas.id = "game-canvas";
      bootedGame.canvas.dataset.testid = "game-canvas";
      bootedGame.canvas.setAttribute("aria-label", "Vector Siege arena");
    },
  },
});

declare global {
  interface Window {
    __vectorSiege?: {
      game: Phaser.Game;
      scene: ArenaScene;
    };
  }
}

window.__vectorSiege = { game, scene };
