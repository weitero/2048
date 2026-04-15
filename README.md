# 2048 (Godot 4)

A smooth, AI-assisted implementation of the classic 2048 puzzle game, built with **Godot 4.3**.

## Features

- **Clean & Minimalist**: UI is constructed programmatically for a crisp look.
- **Smooth Animations**: All tile movements and merges are animated with Tweens.
- **Persistent High Score**: Your best score is saved automatically.
- **Vibe-Coded Architecture**:
  - Separated logic (`board.gd`) and presentation (`tile.gd`).
  - No bloated scene files—everything is assembled at runtime.

## How to Run

1. **Download Godot 4.3** (or later) from the [official website](https://godotengine.org/).
2. Open Godot and click **Import**.
3. Select the `project.godot` file from this repository.
4. Once the project is open, press **F5** (or click the Play button) to start the game.

## Controls

- **Arrow Keys**: Move tiles (Up, Down, Left, Right)
- **R**: Restart the game

## Project Structure

- `scripts/game.gd`: Main controller, handles input and game state.
- `scripts/board.gd`: Core logic for the grid, tile movement, and merging algorithms.
- `scripts/tile.gd`: Visual node for individual tiles, handling animations and styling.
- `scenes/`: Contains the base scene nodes (Game, Board, Tile).

## License

MIT
