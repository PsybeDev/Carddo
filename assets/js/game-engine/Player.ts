import * as P from 'phaser';

export interface PlayerConfig {
    id: string;
    name: string;
    startingLife: number;
    deckList: string[];
}

export class Player {
    public id: string;
    public name: string;
    public lifePoints: number;
    public deck: string[];
    public hand: string[];
    public discardPile: string[];
    public playArea: string[];

    constructor(config: PlayerConfig) {
        this.id = config.id;
        this.name = config.name;
        this.lifePoints = config.startingLife;
        this.deck = [...config.deckList];
        this.hand = [];
        this.discardPile = [];
        this.playArea = [];
    }

    public drawCard(amount: number = 1): string[] {
        const drawnCards: string[] = [];
        for (let i = 0; i < amount; i++) {
            if (this.deck.length === 0) return drawnCards;
            const card = this.deck.pop();
            if (card) {
                drawnCards.push(card);
                this.hand.push(card);
            }
        }
        return drawnCards;
    }

    public playCard(cardIndex: number): string | null {
        if (cardIndex < 0 || cardIndex >= this.hand.length) return null;
        const [card] = this.hand.splice(cardIndex, 1);
        this.playArea.push(card);
        return card;
    }

    public discardCard(cardIndex: number): string | null {
        if (cardIndex < 0 || cardIndex >= this.hand.length) return null;
        const [card] = this.hand.splice(cardIndex, 1);
        this.discardPile.push(card);
        return card;
    }

    public discardFromPlay(cardIndex: number): string | null {
        if (cardIndex < 0 || cardIndex >= this.playArea.length) return null;
        const [card] = this.playArea.splice(cardIndex, 1);
        this.discardPile.push(card);
        return card;
    }

    public modifyLife(amount: number): number {
        this.lifePoints += amount;
        return this.lifePoints;
    }

    public shuffleDeck(): void {
        for (let i = this.deck.length - 1; i > 0; i--) {
            const j = Math.floor(Math.random() * (i + 1));
            [this.deck[i], this.deck[j]] = [this.deck[j], this.deck[i]];
        }
    }
}