package main

import "core:encoding/json"

// types used for exporting and importing

Grid :: struct {
    w: int `json:"w"`,
    h: int `json:"h"`,
}

starting_Position :: struct {
    x: int `json:"x"`,
    y: int `json:"y"`,
    desired_visible: int `json:"desired_visible"`,
}

starting_Board :: struct {
    size: Grid `json:"size"`,
    seed: u64 `json:"seed"`,
    starting_positions: [dynamic]starting_Position `json:"starting_positions"`,
}

// types used for computation

VisibileState :: enum {
    NOT_OBSERVER,
    TOO_MANY,
    DESIRED,
    TOO_FEW
}

Position :: struct {
    x: int,
    y: int
}

BLANK :: struct {
}

BLACK :: struct {
}

WHITE :: struct {
    desired_visible: Maybe(int)
}

FieldState :: union {
    BLANK,
    BLACK,
    WHITE
}

Board :: struct {
    size: Grid,
    cells: [][]FieldState
}
