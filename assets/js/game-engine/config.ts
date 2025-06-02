import * as P from 'phaser';
import { GameBoard } from './main';

export const GameConfig: P.Types.Core.GameConfig = {
    type: P.AUTO,
    scale: {
        mode: P.Scale.RESIZE,
        parent: 'game',
        width: '100%',
        height: P.Scale.FIT,
        autoCenter: P.Scale.CENTER_BOTH
    },
    backgroundColor: '#2d2d2d',
    scene: GameBoard,
    dom: {
        createContainer: true
    },
    physics: {
        default: 'arcade',
        arcade: {
            debug: false
        }
    }
};