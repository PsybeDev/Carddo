import * as P from 'phaser';
import { Player, PlayerConfig } from './Player';

// --- CONSTANTS FOR LAYOUT ---
const CARD_SCALE = 0.1; // Scale factor for card images
// Approximate displayed card dimensions after scaling (e.g. for a 700x950px card image)
const CARD_DISPLAY_WIDTH = 70;
const CARD_DISPLAY_HEIGHT = 95;
const CARD_SPACING = 15; // Spacing between cards in hand

const SIDE_X_OFFSET = 80;  // X-offset from the edge for side zones (deck, discard, etc.)
// DECK_X, DISCARD_X, EXILE_X, FACEDOWN_X will be determined in create() using SIDE_X_OFFSET

// const GRAVEYARD_X = SIDE_X_OFFSET; // Graveyard is handled by DISCARD_X (if it were on the left)
// const HAND_Y = 700; // Superseded by LOCAL/OPP.HAND_Y
// const PLAY_AREA_Y = 350; // Superseded by LOCAL/OPP.PLAY_AREA_Y
const BACKGROUND_COLOR = 0x2d2d2d; // Dark background

// --- CARD GAMEOBJECT ---
class Card extends P.GameObjects.Image {
    public isFaceUp: boolean = false;
    public originalPosition: { x: number; y: number } = { x: 0, y: 0 };
    public cardId: string;
    private lastClickTime = 0;

    constructor(scene: P.Scene, x: number, y: number, cardId: string, texture: string) {
        super(scene, x, y, texture);
        this.cardId = cardId;
        scene.add.existing(this);
        this.setScale(CARD_SCALE);
        this.setInteractive({ useHandCursor: true });
        this.setupInteractions(scene);
    }

    private setupInteractions(scene: P.Scene) {
        scene.input.setDraggable(this);
        this.on('pointerdown', (pointer: P.Input.Pointer) => {
            const currentTime = pointer.time;
            if (currentTime - this.lastClickTime < 300) {
                this.flip();
            }
            this.lastClickTime = currentTime;
        });
        this.on('rightdown', () => this.rotate());
    }

    public flip() {
        this.isFaceUp = !this.isFaceUp;
        this.setTexture(this.isFaceUp ? 'card_face' : 'card_back');
    }

    public rotate() {
        this.scene.add.tween({
            targets: this,
            angle: this.angle + 90,
            duration: 200,
            ease: 'Power2'
        });
    }
}

// --- INTERFACES ---
interface PlayerLayoutY {
    HAND_Y: number;
    PLAY_AREA_Y: number;
    DECK_Y: number;
    DISCARD_Y: number;
    FACEDOWN_Y: number;
    EXILE_Y: number;
}

// --- MAIN GAME BOARD SCENE ---
export class GameBoard extends P.Scene {
    private players: Player[];
    private localPlayerId: string;
    private currentPlayerId: string;
    private zoneGroups: Record<string, {
        hand: P.GameObjects.Group,
        deck: P.GameObjects.Group,
        discard: P.GameObjects.Group,
        playArea: P.GameObjects.Group
    }> = {};
    private deckCountTexts: Record<string, P.GameObjects.Text> = {};
    private playerIds: string[] = [];
    private actualPlayAreaHeight: number;
    private playAreaGraphics: Record<string, P.GameObjects.Graphics> = {};
    private localPlayerLayoutY: PlayerLayoutY;
    private opponentPlayerLayoutY: PlayerLayoutY;

    constructor() {
        super('GameBoard');
        // Always use two players: p1 (local) and p2 (opponent)
        this.playerIds = ['p1', 'p2'];
        this.players = this.playerIds.map(pid =>
            // create a dummy 60 card deck for each player
            new Player({ id: pid, name: `Player ${pid.slice(-1)}`, startingLife: 20, deckList: Array(60).fill('').map((_, i) => `card_${pid}_${i + 1}`) } as PlayerConfig)
        );
        this.localPlayerId = 'p1';
        this.currentPlayerId = 'p1';
    }

    preload() {
        this.load.image('card_face', 'https://cards.scryfall.io/large/front/0/d/0d6245bc-e9c8-43fe-a606-e576e3928e88.jpg?1679771853');
        this.load.image('card_back', 'https://i.imgur.com/LdOBU1I.jpeg');
        this.load.image('bg_texture', 'https://static.wikia.nocookie.net/mtgsalvation_gamepedia/images/f/f8/Magic_card_back.jpg');
    }

    create() {
        const halfHeight = this.sys.scale.height / 2;
        const width = this.sys.scale.width;
        const height = this.sys.scale.height;
        const margin = 20; // General margin for elements from edges or each other

        // Calculate X positions for zones
        const DECK_X_POS = width - SIDE_X_OFFSET;       // Deck on the right
        const DISCARD_X_POS = SIDE_X_OFFSET;            // Discard on the left
        const EXILE_X_POS = SIDE_X_OFFSET;              // Exile on the left
        const FACEDOWN_X_POS = SIDE_X_OFFSET;           // Facedown on the left

        this.actualPlayAreaHeight = height * 0.30; // Play area will take 25% of total screen height

        // Define Y positions for local (bottom) and opponent (top) players
        const LOCAL_LAYOUT: PlayerLayoutY = {
            HAND_Y: height - (CARD_DISPLAY_HEIGHT / 2) - margin,
            PLAY_AREA_Y: halfHeight + (this.actualPlayAreaHeight / 2) + margin,
            DECK_Y: height - (CARD_DISPLAY_HEIGHT / 2) - margin,
            DISCARD_Y: height - (CARD_DISPLAY_HEIGHT / 2) - margin - CARD_DISPLAY_HEIGHT - margin,
            FACEDOWN_Y: height - (CARD_DISPLAY_HEIGHT / 2) - margin - (CARD_DISPLAY_HEIGHT + margin) * 2,
            EXILE_Y: height - (CARD_DISPLAY_HEIGHT / 2) - margin - (CARD_DISPLAY_HEIGHT + margin) * 3,
        };
        const OPP_LAYOUT: PlayerLayoutY = {
            HAND_Y: (CARD_DISPLAY_HEIGHT / 2) + margin,
            PLAY_AREA_Y: halfHeight - (this.actualPlayAreaHeight / 2) - margin,
            DECK_Y: (CARD_DISPLAY_HEIGHT / 2) + margin,
            DISCARD_Y: (CARD_DISPLAY_HEIGHT / 2) + margin + CARD_DISPLAY_HEIGHT + margin,
            FACEDOWN_Y: (CARD_DISPLAY_HEIGHT / 2) + margin + (CARD_DISPLAY_HEIGHT + margin) * 2,
            EXILE_Y: (CARD_DISPLAY_HEIGHT / 2) + margin + (CARD_DISPLAY_HEIGHT + margin) * 3,
        };
        this.localPlayerLayoutY = LOCAL_LAYOUT;
        this.opponentPlayerLayoutY = OPP_LAYOUT;

        // Draw initial hand for each player
        this.players.forEach(player => player.drawCard(5));

        // Add center dividing line
        const centerLineGraphics = this.add.graphics();
        centerLineGraphics.lineStyle(4, 0xaaaaaa, 0.5); // thickness, color, alpha
        centerLineGraphics.beginPath();
        centerLineGraphics.moveTo(0, halfHeight);
        centerLineGraphics.lineTo(width, halfHeight);
        centerLineGraphics.closePath();
        centerLineGraphics.strokePath();

        this.players.forEach((player, idx) => {
            const isLocal = player.id === this.localPlayerId;
            const isCurrent = player.id === this.currentPlayerId;
            const Y = isLocal ? this.localPlayerLayoutY : this.opponentPlayerLayoutY;

            // Initialize zone group for the player if it doesn't exist
            this.zoneGroups[player.id] = this.zoneGroups[player.id] || {
                hand: this.add.group(),
                deck: this.add.group(),
                discard: this.add.group(),
                playArea: this.add.group(),
            };

            // Groups for zones
            const handGroup = this.zoneGroups[player.id].hand;
            const deckGroup = this.zoneGroups[player.id].deck;
            const discardGroup = this.zoneGroups[player.id].discard;
            const playAreaGroup = this.zoneGroups[player.id].playArea;

            // --- ZONE LABELS ---
            const labelYOffset = CARD_DISPLAY_HEIGHT / 2 + 10; // Offset for labels from the center of the zone
            this.add.text(DECK_X_POS, Y.DECK_Y + (isLocal ? labelYOffset : -labelYOffset), 'Deck', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 0 : 1);
            this.add.text(DISCARD_X_POS, Y.DISCARD_Y + (isLocal ? labelYOffset : -labelYOffset), 'Discard', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 0 : 1);
            // Add Exile and Facedown labels if these zones are actively used and visualized
            this.add.text(EXILE_X_POS, Y.EXILE_Y + (isLocal ? labelYOffset : -labelYOffset), 'Exile', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 0 : 1);
            this.add.text(FACEDOWN_X_POS, Y.FACEDOWN_Y + (isLocal ? labelYOffset : -labelYOffset), 'Facedown', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 0 : 1);

            this.add.text(width / 2, Y.HAND_Y + (isLocal ? labelYOffset : -labelYOffset), 'Hand', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 0 : 1);
            this.add.text(width / 2, Y.PLAY_AREA_Y + (isLocal ? -(CARD_DISPLAY_HEIGHT + margin) : (CARD_DISPLAY_HEIGHT + margin)), 'Play Area', { fontSize: '16px', color: '#aaa' }).setOrigin(0.5, isLocal ? 1 : 0);

            // Deck visual
            this.createDeck(player, deckGroup, DECK_X_POS, Y.DECK_Y, isLocal, isCurrent);
            // Discard visual
            this.createDiscard(player, discardGroup, DISCARD_X_POS, Y.DISCARD_Y, isLocal);
            // Hand visual
            this.createHand(player, handGroup, Y.HAND_Y, isLocal, isCurrent, DISCARD_X_POS);
            // Play area graphics
            if (this.playAreaGraphics[player.id]) {
                this.playAreaGraphics[player.id].destroy();
            }
            this.playAreaGraphics[player.id] = this.add.graphics();
            // Play area visual
            this.createPlayArea(player, playAreaGroup, Y.PLAY_AREA_Y, this.actualPlayAreaHeight, this.playAreaGraphics[player.id]);

            // Life counter: only show for local player at bottom left, for opponents at top right
            const lifeCounterKey = `${player.id}_lifeCounter`;
            if (this[lifeCounterKey]) this[lifeCounterKey].destroy();
            if (isLocal) {
                this[lifeCounterKey] = this.add.text(50, height - 50, `${player.name}: ${player.lifePoints}`, {
                    fontSize: '24px', color: '#ffffff', align: 'left'
                }).setOrigin(0, 1);
            } else {
                this[lifeCounterKey] = this.add.text(width - 50, 50, `${player.name}: ${player.lifePoints}`, {
                    fontSize: '24px', color: '#ffffff', align: 'right'
                }).setOrigin(1, 0);
            }
        });
        // End turn button (only for local player)
        if (this.localPlayerId === this.currentPlayerId) {
            const endTurnButton = this.add.text(width - 10, height - CARD_DISPLAY_HEIGHT - 50, 'End Turn', {
                fontSize: '24px', color: '#ffffff', backgroundColor: '#444444', padding: { x: 10, y: 5 }
            });
            endTurnButton.setOrigin(1, 1);
            endTurnButton.setInteractive();
            endTurnButton.on('pointerdown', () => this.endTurn());
        }


    }

    private createDeck(player: Player, group: P.GameObjects.Group, xPos: number, yOffset: number, isLocal: boolean, isCurrent: boolean) {
        group.clear(true, true);

        if (player.deck.length === 0) {
            // Show empty deck visual
            const emptyDeckRect = this.add.rectangle(xPos, yOffset, CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT, 0xff0000, 0.5);
            emptyDeckRect.setStrokeStyle(2, 0xcc0000);
            group.add(emptyDeckRect);

            const emptyDeckText = this.add.text(xPos, yOffset, 'X', {
                fontSize: `${CARD_DISPLAY_HEIGHT * 0.6}px`, // Scale X size with card height
                color: '#ff0000',
                stroke: '#660000',
                strokeThickness: 3,
                align: 'center'
            }).setOrigin(0.5, 0.5);
            group.add(emptyDeckText);
        } else {
            // Show deck stack and clickable top card
            for (let i = 0; i < Math.min(player.deck.length, 5); i++) {
                const offset = i * 2; // Small offset for stacked look
                const stackCard = new Card(this, xPos + offset, yOffset + offset, 'deck_stack_visual', 'card_back');
                stackCard.isFaceUp = false;
                group.add(stackCard);
            }
            const deckTop = new Card(this, xPos, yOffset, 'deck_interactive_top', 'card_back');
            deckTop.isFaceUp = false;
            group.add(deckTop);
            if (isLocal && isCurrent) { // Only local, current player can draw
                deckTop.on('pointerdown', () => this.drawCard(player));
            }
        }
        this.deckCountTexts[player.id] = this.add.text(xPos - (CARD_DISPLAY_WIDTH / 2) - 5, yOffset, String(player.deck.length), { fontSize: '24px', color: '#fff' }); // Positioned to the left of the deck
        this.deckCountTexts[player.id].setOrigin(1, 0.5);
        // Make deck a drop zone
        const deckZone = this.add.zone(xPos, yOffset, CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT).setRectangleDropZone(CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT);
        deckZone.setData('zone', 'deck');
        deckZone.setData('playerId', player.id);
    }

    private createDiscard(player: Player, group: P.GameObjects.Group, xPos: number, yOffset: number, isLocal: boolean) {
        group.clear(true, true);
        if (player.discardPile.length > 0) {
            const lastCardId = player.discardPile[player.discardPile.length - 1];
            const discardCard = new Card(this, xPos, yOffset, lastCardId, 'card_face');
            discardCard.isFaceUp = true;
            group.add(discardCard);
        }
        // Make discard a drop zone
        const discardZone = this.add.zone(xPos, yOffset, CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT).setRectangleDropZone(CARD_DISPLAY_WIDTH, CARD_DISPLAY_HEIGHT);
        discardZone.setData('zone', 'discard');

        discardZone.setData('playerId', player.id);
    }
    private createHand(player: Player, group: P.GameObjects.Group, yOffset: number, isLocal: boolean, isCurrent: boolean, discardXPos: number) {
        group.clear(true, true);
        const handWidth = player.hand.length * (CARD_DISPLAY_WIDTH + CARD_SPACING) - CARD_SPACING;
        const startX = (this.sys.scale.width - handWidth) / 2;

        player.hand.forEach((cardId, index) => {
            const card = new Card(this, startX + (index * (CARD_DISPLAY_WIDTH + CARD_SPACING)), yOffset, cardId, isLocal ? 'card_face' : 'card_back');
            card.isFaceUp = isLocal; // Local player's hand is face up, opponent's is face down
            group.add(card);
            if (isLocal && isCurrent) {
                card.on('drag', (pointer: P.Input.Pointer, dragX: number, dragY: number) => {
                    card.x = dragX;
                    card.y = dragY;
                });
                card.on('dragend', () => {
                    const dropY = card.y;
                    const dropX = card.x;
                    const yLayoutConstants = isLocal ? this.localPlayerLayoutY : this.opponentPlayerLayoutY; // Get correct Y scheme

                    // Check drop in Play Area
                    // This logic needs to be more robust, checking against actual play area zone boundaries
                    // For now, using a simplified check based on Y position relative to hand and play area centers
                    if (Math.abs(dropY - yLayoutConstants.PLAY_AREA_Y) < CARD_DISPLAY_HEIGHT) { // Simplified check
                        // Remove from hand, add to play area
                        const idx = player.hand.indexOf(card.cardId);
                        if (idx !== -1) player.hand.splice(idx, 1);
                        player.playArea = player.playArea || [];
                        player.playArea.push(card.cardId);
                        this.createHand(player, this.zoneGroups[player.id].hand, yLayoutConstants.HAND_Y, isLocal, isCurrent, discardXPos); // Redraw hand
                        this.createPlayArea(player, this.zoneGroups[player.id].playArea, yLayoutConstants.PLAY_AREA_Y, this.actualPlayAreaHeight, this.playAreaGraphics[player.id]); // Redraw play area
                    }
                    // Check drop in Discard Pile
                    else if (Math.abs(dropX - discardXPos) < CARD_DISPLAY_WIDTH && Math.abs(dropY - yLayoutConstants.DISCARD_Y) < CARD_DISPLAY_HEIGHT) {
                        // Remove from hand, add to discard
                        const idx = player.hand.indexOf(card.cardId);
                        if (idx !== -1) player.hand.splice(idx, 1);
                        player.discardPile.push(card.cardId);
                        this.createHand(player, this.zoneGroups[player.id].hand, yLayoutConstants.HAND_Y, isLocal, isCurrent, discardXPos); // Redraw hand
                        this.createDiscard(player, this.zoneGroups[player.id].discard, discardXPos, yLayoutConstants.DISCARD_Y, isLocal); // Redraw discard
                    }
                    // Snap back to hand if not dropped in a valid zone
                    else {
                        // Snap back to hand
                        this.createHand(player, this.zoneGroups[player.id].hand, yLayoutConstants.HAND_Y, isLocal, isCurrent, discardXPos); // Redraw hand
                    }
                });
            }
        });
    }

    private createPlayArea(player: Player, group: P.GameObjects.Group, yOffset: number, playAreaHeight: number, graphics: P.GameObjects.Graphics) {
        group.clear(true, true);
        graphics.clear(); // Clear previous border

        const dropZoneWidth = this.sys.scale.width * 0.8;
        const dropZoneHeight = playAreaHeight;
        const dropZoneX = this.sys.scale.width / 2;
        const dropZoneY = yOffset;
        graphics.lineStyle(2, 0x00ff00, 0.3);
        graphics.strokeRect(
            dropZoneX - dropZoneWidth / 2,
            dropZoneY - dropZoneHeight / 2,
            dropZoneWidth,
            dropZoneHeight
        );
        // Render cards in play area
        if (player.playArea && player.playArea.length > 0) {
            player.playArea.forEach((cardId, idx) => {
                const card = new Card(this, (dropZoneX - dropZoneWidth/2 + CARD_DISPLAY_WIDTH/2) + idx * (CARD_DISPLAY_WIDTH + CARD_SPACING), dropZoneY, cardId, 'card_face');
                card.isFaceUp = true;
                group.add(card);
            });
        }
        // Make play area a drop zone
        const zone = this.add.zone(dropZoneX, dropZoneY, dropZoneWidth, dropZoneHeight).setRectangleDropZone(dropZoneWidth, dropZoneHeight);
        zone.setData('zone', 'playArea');
        zone.setData('playerId', player.id);
    }

    private drawCard(player: Player) {
        if (player.deck.length > 0) {
            player.drawCard(); // Already adds to hand

            const isLocal = player.id === this.localPlayerId;
            const isCurrent = player.id === this.currentPlayerId;
            const yLayout = isLocal ? this.localPlayerLayoutY : this.opponentPlayerLayoutY;

            const deckXPos = this.sys.scale.width - SIDE_X_OFFSET;
            const discardXPos = SIDE_X_OFFSET;

            this.createHand(player, this.zoneGroups[player.id].hand, yLayout.HAND_Y, isLocal, isCurrent, discardXPos);
            this.deckCountTexts[player.id].setText(String(player.deck.length));
            this.createDeck(player, this.zoneGroups[player.id].deck, deckXPos, yLayout.DECK_Y, isLocal, isCurrent);
        }
    }

    private endTurn() {
        // Implement turn logic, update this.currentPlayerId, and re-render as needed
    }

    update() {
        this.players.forEach(player => {
            const lifeCounterKey = `${player.id}_lifeCounter`;
            if (this[lifeCounterKey]) this[lifeCounterKey].setText(`${player.name}: ${player.lifePoints}`);
        });
    }
}

// --- END OF GAME LOGIC ---
// Multiplayer/socket code removed. This is now a local two-player mock game.
