#!/usr/bin/env python3
"""Terminal Snake Game - Use arrow keys or WASD to play, Q to quit"""

import curses
import random
from collections import deque

def main(stdscr):
    # Setup
    curses.curs_set(0)  # Hide cursor
    stdscr.nodelay(1)   # Non-blocking input
    stdscr.timeout(100) # Refresh rate (ms) - controls game speed
    
    # Colors
    curses.start_color()
    curses.init_pair(1, curses.COLOR_GREEN, curses.COLOR_BLACK)   # Snake
    curses.init_pair(2, curses.COLOR_RED, curses.COLOR_BLACK)     # Food
    curses.init_pair(3, curses.COLOR_YELLOW, curses.COLOR_BLACK)  # Score
    curses.init_pair(4, curses.COLOR_CYAN, curses.COLOR_BLACK)    # Border
    
    # Get screen dimensions
    sh, sw = stdscr.getmaxyx()
    
    # Game area (leave space for border and score)
    game_h, game_w = sh - 4, sw - 4
    offset_y, offset_x = 2, 2
    
    if game_h < 10 or game_w < 20:
        stdscr.addstr(0, 0, "Terminal too small! Need at least 24x14")
        stdscr.refresh()
        stdscr.getch()
        return
    
    # Initial snake position (middle of screen)
    snake = deque()
    start_y, start_x = game_h // 2, game_w // 4
    for i in range(3):
        snake.append((start_y, start_x - i))
    
    # Initial direction (moving right)
    direction = curses.KEY_RIGHT
    
    # Place first food
    def place_food():
        while True:
            fy = random.randint(0, game_h - 1)
            fx = random.randint(0, game_w - 1)
            if (fy, fx) not in snake:
                return (fy, fx)
    
    food = place_food()
    score = 0
    
    # Direction mappings
    opposite = {
        curses.KEY_UP: curses.KEY_DOWN,
        curses.KEY_DOWN: curses.KEY_UP,
        curses.KEY_LEFT: curses.KEY_RIGHT,
        curses.KEY_RIGHT: curses.KEY_LEFT,
    }
    
    wasd_map = {
        ord('w'): curses.KEY_UP,
        ord('W'): curses.KEY_UP,
        ord('s'): curses.KEY_DOWN,
        ord('S'): curses.KEY_DOWN,
        ord('a'): curses.KEY_LEFT,
        ord('A'): curses.KEY_LEFT,
        ord('d'): curses.KEY_RIGHT,
        ord('D'): curses.KEY_RIGHT,
    }
    
    def draw_border():
        # Draw border
        stdscr.attron(curses.color_pair(4))
        for x in range(sw - 2):
            stdscr.addch(1, x + 1, '─')
            stdscr.addch(sh - 2, x + 1, '─')
        for y in range(sh - 3):
            stdscr.addch(y + 2, 0, '│')
            stdscr.addch(y + 2, sw - 1, '│')
        stdscr.addch(1, 0, '┌')
        stdscr.addch(1, sw - 1, '┐')
        stdscr.addch(sh - 2, 0, '└')
        stdscr.addch(sh - 2, sw - 1, '┘')
        stdscr.attroff(curses.color_pair(4))
    
    # Game loop
    while True:
        stdscr.clear()
        
        # Draw title and score
        title = "🐍 SNAKE GAME 🐍"
        stdscr.attron(curses.color_pair(3) | curses.A_BOLD)
        stdscr.addstr(0, (sw - len(title)) // 2, title)
        stdscr.attroff(curses.color_pair(3) | curses.A_BOLD)
        
        draw_border()
        
        # Draw score
        score_text = f" Score: {score} "
        stdscr.attron(curses.color_pair(3))
        stdscr.addstr(1, 3, score_text)
        stdscr.attroff(curses.color_pair(3))
        
        # Draw controls hint
        hint = " Q:Quit  ↑↓←→/WASD:Move "
        stdscr.addstr(sh - 1, (sw - len(hint)) // 2, hint)
        
        # Draw food
        fy, fx = food
        stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
        stdscr.addch(fy + offset_y, fx + offset_x, '●')
        stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
        
        # Draw snake
        stdscr.attron(curses.color_pair(1))
        for i, (y, x) in enumerate(snake):
            char = '█' if i == 0 else '▓'
            try:
                stdscr.addch(y + offset_y, x + offset_x, char)
            except curses.error:
                pass  # Ignore if out of bounds
        stdscr.attroff(curses.color_pair(1))
        
        stdscr.refresh()
        
        # Get input
        key = stdscr.getch()
        
        # Quit
        if key in (ord('q'), ord('Q')):
            break
        
        # Convert WASD to arrow keys
        if key in wasd_map:
            key = wasd_map[key]
        
        # Change direction (prevent 180° turns)
        if key in (curses.KEY_UP, curses.KEY_DOWN, curses.KEY_LEFT, curses.KEY_RIGHT):
            if key != opposite.get(direction):
                direction = key
        
        # Calculate new head position
        head_y, head_x = snake[0]
        if direction == curses.KEY_UP:
            head_y -= 1
        elif direction == curses.KEY_DOWN:
            head_y += 1
        elif direction == curses.KEY_LEFT:
            head_x -= 1
        elif direction == curses.KEY_RIGHT:
            head_x += 1
        
        new_head = (head_y, head_x)
        
        # Check wall collision
        if head_y < 0 or head_y >= game_h or head_x < 0 or head_x >= game_w:
            break
        
        # Check self collision
        if new_head in snake:
            break
        
        # Move snake
        snake.appendleft(new_head)
        
        # Check food collision
        if new_head == food:
            score += 10
            food = place_food()
            # Speed up slightly
            timeout = max(50, 100 - score // 20)
            stdscr.timeout(timeout)
        else:
            snake.pop()
    
    # Game over screen
    stdscr.nodelay(0)
    stdscr.clear()
    
    game_over = [
        "╔═══════════════════════╗",
        "║      GAME OVER!       ║",
        f"║    Final Score: {score:4}  ║",
        "║                       ║",
        "║  Press any key to     ║",
        "║       exit...         ║",
        "╚═══════════════════════╝",
    ]
    
    start_y = (sh - len(game_over)) // 2
    start_x = (sw - len(game_over[0])) // 2
    
    stdscr.attron(curses.color_pair(2) | curses.A_BOLD)
    for i, line in enumerate(game_over):
        stdscr.addstr(start_y + i, start_x, line)
    stdscr.attroff(curses.color_pair(2) | curses.A_BOLD)
    
    stdscr.refresh()
    stdscr.getch()

if __name__ == "__main__":
    try:
        curses.wrapper(main)
        print("Thanks for playing Snake! 🐍")
    except KeyboardInterrupt:
        print("\nGame interrupted. Goodbye!")
