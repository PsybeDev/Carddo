import * as P from 'phaser';

export class Card extends P.Scene {
  card!: P.GameObjects.Plane;
  rotation = {
    y: 0
  }
  isFlipping: boolean = false

  constructor() {
    super('Card')
  }
  preload() {
    this.load.image('card_face', 'https://cards.scryfall.io/large/front/0/d/0d6245bc-e9c8-43fe-a606-e576e3928e88.jpg?1679771853');
    this.load.image('card_back', 'https://i.imgur.com/LdOBU1I.jpeg');
  }

  create() {
    this.card = this.add.plane(this.sys.scale.width / 2, this.sys.scale.height / 2, 'card_face')
    this.card.setScale(.1)

    this.add.tween({
      targets: this.rotation,
      ease: P.Math.Easing.Expo.Out,
      duration: 5000,
      y: (this.rotation.y === 180) ? 0 : 180,
      onStart: () => {
        this.isFlipping = true
        this.tweens.chain({
          targets: this.card,
          ease: P.Math.Easing.Expo.InOut,
          tweens: [
            {
              duration: 200,
              scale: .5
            },
            {
              duration: 300,
              scale: .5
            }
          ]
        })

      },
      onUpdate: () => {
        // @ts-ignore
        this.card.rotateY = 180 + this.rotation.y; // @ts-ignore
        const cardRotation = Math.floor(this.card.rotateY) % 360;
        if ((cardRotation >= 0 && cardRotation <= 90) || (cardRotation >= 270 && cardRotation <= 359)) {
          this.card.setTexture('card_face')
        } else {
          this.card.setTexture('card_back')
        }
      }
    })
  }
}

export class Hand extends P.Scene {
  constructor() {
    super('Hand')
  }
}

export class Deck extends P.Scene {
  constructor() {
    super('Deck')
  }
}

export class Discard extends P.Scene {
  constructor() {
    super('Discard')
  }
}

export class PlayArea extends P.Scene {
  constructor() {
    super('PlayArea')
  }
}

export class Game extends P.Scene {

}
