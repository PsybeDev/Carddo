/**
 * Initialize game engine with Phaser. Game will have cards, a deck, and general play area
 */

import Phaser from 'phaser';

const GameEngine = new Phaser.Game({
  type: Phaser.AUTO,
  width: 800,
  height: 600,
  parent: 'game_area',
  scene: {
    create: () => {
      this.add.text(0, 0, 'Hello World!')
    }
  }
})

export default GameEngine
