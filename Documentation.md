# ARG Web Tracker & Grid Puzzle - Project Specification

## 1. Project Overview
This application is a highly interactive, single-user web experience serving as the tracker and finale of an Alternate Reality Game (ARG). It consists of a secure login, a visual mapping phase built around a central pentagram, and a final 6x8 modular grid puzzle featuring 6 distinct mathematical/visual decryptor tools. 

**Tech Stack:** * Frontend: Flutter Web (Utilizing `CustomPaint` for the map and `Draggable`/`DragTarget` for the grid).
* Backend & State: Supabase (Postgres, Auth, Storage, Realtime).

## 2. Database Schema (Supabase)
The app relies on three strict tables. Do not alter this schema; the frontend must conform to it.
* `items`: Static dictionary of all puzzle pieces (`item_id`, `title`, `code`, `concept`, `secret_letter`).
* `unlocked_codes`: Chronological ledger of user progress (`id`, `user_id`, `item_id`, `unlocked_at`, `image_path`).
* `game_state`: A single-row table storing the live puzzle state (`user_id`, `grid_layout` as JSONB array of 48 slots, `active_tool` integer 0-6, `start_date`).

## 3. Core Mechanics & Phases

### Phase 0: Authentication Layer
* A minimalist landing page with a single input field.
* Validates a master password against Supabase Auth (using a hardcoded backend user).
* Issues a secure JWT. All subsequent database calls must use this authenticated session.

### Phase 1: The Pentagram Map Visualizer
* **UI:** A persistent text box at the top, an interactive canvas below. 
* **The Hook:** The canvas immediately displays a central pentagram upon entry. This is the core visual anchor.
* **Canvas Zoning:** The canvas is divided into 5 invisible radial zones, projecting outward from each of the 5 points of the pentagram.
* **Logic:** When a code is entered, validate it against the `items` table. If valid, prompt the user to upload a photo (compress client-side before uploading to Supabase Storage). Record the entry in `unlocked_codes`.
* **Visuals:** * Standard items spawn strictly within the invisible zone corresponding to their related ending/concept. 
    * When an "Ending" code is entered, its corresponding node on the central pentagram lights up with its specific concept color (Púrpura, Azul, Verde, Naranja, or Rojo).
* **The Transition:** Upon unlocking the 5th and final "Ending" code, the `game_state.start_date` timestamp is set. The pentagram shape scales up to fill the screen, its lines morphing to form the borders of the Phase 2 grid.

### Phase 2: The 6x8 Modular Grid
* **UI:** A responsive 6 columns by 8 rows grid.
* **Logic:** Populate the grid using the `game_state.grid_layout` JSON. Ensure robust drag-and-drop mechanics. Snap items to the grid. Instantly sync state to `localStorage` and Supabase on every drop.
* **Validation:** Silently check the current grid array against the master solved array on every move. Trigger the ending sequence upon a perfect match.

### Phase 3: The Decryptor Tools & Hints
* **The UI:** A 5-pointed star graphic. Clicking the 5 outer points toggles Tools 1-5. Clicking the center of the star toggles Tool 6. Only one tool can be active at a time. The active state is synced via `game_state.active_tool`.
* **The Tools (Transformations):** These tools transform the visual data in the grid to help solve it.
    * *Tool 1 (Color Validation):* Checks the distribution of concept colors. Visually shows a green outline outside a colored code if there is only one color in that entire column. Shows a red outline if there are two (or more) of the same colors in the same row.
    * *Tool 2 (Modulo 36 Math):* Calculates column sums based on specific digit values evaluated under mod 36. Shows a green indicator for every sum that equals exactly 0, and a red indicator otherwise.
    * *Tool 3 (Alphanumeric Balance):* Evaluates row balance. Displays a live count of the number of letters and the number of digits on every row. Shows green if the count is perfectly equal, and red if they are not.
    * *Tool 4 (Adjacency):* Checks if a cell has more than one matching integer or letter with its orthogonal neighbors (2, 3, or 4 neighbors depending on grid placement). Visually turns the text of correct codes to green and incorrect codes to red.
    * *Tool 5 (Quadrant Symmetry):* Divides the 6x8 grid into four 3x4 smaller grids. Rule: The corner cell closest to the center of the big grid MUST be the reverse string of the opposite outer corner within that same 3x4 grid. Visually shows 4 thick outlines enclosing each smaller grid, painted green if the rule is met, and red if incorrect.
    * *Tool 6 (Semantic Core):* Replaces all images on the grid with the `items.secret_letter` value, rendered purely in high-contrast white/black text.
* **Time-Gated Hints:** Do not use database cron jobs. Calculate `days_elapsed` on the client using `floor((current_time - game_state.start_date) / 86400)`. Reveal a hardcoded array of text hints based on this integer.

## 4. Development Constraints & Guidelines
1. **Performance:** Prioritize 60fps interactivity. The grid drag-and-drop and `CustomPaint` map animations must be flawless. Use client-side image compression (e.g., `flutter_image_compress`) to prevent memory bloat.
2. **Dual-Layer Persistence:** All user actions (code entry, grid movement) must save to browser storage immediately and sync to Supabase asynchronously.
3. **Developer God Mode:** Include a hidden URL parameter (e.g., `?dev=true`) to bypass Phase 1 and instantly load a mock 48-item grid for testing the endgame logic and tools.