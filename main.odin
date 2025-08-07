package main

import "core:fmt"
import "core:encoding/json"
import "core:os"
import "core:slice"
import "core:strings"
import "core:math/rand"
import "core:time"
import "core:strconv"
import "base:intrinsics"

visible_white :: proc(b: ^Board, pos: Position) -> (desired_matched: VisibileState, visible: int) {
    if pos.x < 0 || pos.x >= b.size.w || pos.y < 0 || pos.y >= b.size.h {
        return .TOO_FEW, INVALID_AMOUNT
    }

    cell, ok := b.cells[pos.x][pos.y].(WHITE)
    if !ok {
        return .NOT_OBSERVER, INVALID_AMOUNT
    }
    if cell.desired_visible == nil {
        desired_matched = .NOT_OBSERVER
    }

    visible = 1

    visible += check_direction_white(b, pos.x, pos.y, -1, 0)
    visible += check_direction_white(b, pos.x, pos.y, 1, 0)
    visible += check_direction_white(b, pos.x, pos.y, 0, -1)
    visible += check_direction_white(b, pos.x, pos.y, 0, 1)

    if (desired_matched != .NOT_OBSERVER) {
        if visible == cell.desired_visible.? {
            desired_matched = .DESIRED
        } else if visible > cell.desired_visible.? {
            desired_matched = .TOO_MANY
        } else {
            desired_matched = .TOO_FEW
        }
    }

    return
}

check_direction_white :: proc(b: ^Board, x, y, dx, dy: int) -> int {
    count := 0
    cx, cy := x + dx, y + dy
    for cx >= 0 && cx < b.size.w && cy >= 0 && cy < b.size.h {
        switch cell in b.cells[cx][cy] {
        case WHITE:
            count += 1
        case BLANK, BLACK:
            return count
        }
        cx += dx
        cy += dy
    }

    return count
}

neighbouring_black :: proc(b: ^Board, x, y: int) -> bool {
    directions := [4]Position{
        Position{ -1, 0 },
        Position{ 1, 0 },
        Position{ 0, -1 },
        Position{ 0, 1 },
    }

    for dir in directions {
        nx := x + dir.x
        ny := y + dir.y
        if nx >= 0 && nx < b.size.w && ny >= 0 && ny < b.size.h {
            _, is_black := b.cells[nx][ny].(BLACK)
            if is_black {
                return true
            }
        }
    }

    return false
}

print_board :: proc(b: ^Board) {
    print_buffer := strings.builder_make()
    print_buffer = strings.builder_init(&print_buffer)^
    defer strings.builder_destroy(&print_buffer)

    fmt.sbprint(&print_buffer, "✖")

    for i := 0; i < b.size.w; i += 1 {
        fmt.sbprint(&print_buffer, i + 1)
    }
    fmt.sbprint(&print_buffer, "\n")

    count := 1
    for x in b.cells {
        fmt.sbprint(&print_buffer, count)
        for y in x {
            switch v in y {
            case BLANK:
                fmt.sbprint(&print_buffer, "_")
            case BLACK:
                fmt.sbprint(&print_buffer, "■")
            case WHITE:
                if v.desired_visible != nil {
                    fmt.sbprint(&print_buffer, v.desired_visible)
                } else {
                    fmt.sbprint(&print_buffer, "□")
                }
            case nil:
                fmt.sbprint(&print_buffer, " ")
            }
        }
        fmt.sbprint(&print_buffer, "\n")
        count += 1
    }
    fmt.print(strings.to_string(print_buffer))
}

place_random_black :: proc(b: ^Board) {
    for i := 0; i < b.size.w; i += 1 {
        for j := 0; j < b.size.h; j += 1 {
            if random_percent(BLACK_CHANCE) {
                if !neighbouring_black(b, i, j) {
                    b.cells[i][j] = BLACK{ }
                    if !is_board_connected(b) {
                        b.cells[i][j] = nil
                    }
                }
            }
        }
    }
}

is_board_connected :: proc(b: ^Board) -> bool {
    visited := make([][]bool, b.size.w)
    for i in 0 ..< b.size.w {
        visited[i] = make([]bool, b.size.h)
    }

    start_found := false
    queue := make([dynamic]Position, 0)

    for x in 0 ..< b.size.w {
        for y in 0 ..< b.size.h {
            _, is_black := b.cells[x][y].(BLACK)
            if !is_black {
                append(&queue, Position{ x, y })
                visited[x][y] = true
                start_found = true
                break
            }
        }
        if start_found {
            break
        }
    }

    if !start_found {
        return false
    }

    directions := [4]Position{
        Position{ -1, 0 },
        Position{ 1, 0 },
        Position{ 0, -1 },
        Position{ 0, 1 }, }

    for len(queue) > 0 {
        current := queue[len(queue) - 1]
        remove_range(&queue, len(queue) - 1, len(queue))

        for dir in directions {
            nx := current.x + dir.x
            ny := current.y + dir.y

            if nx >= 0 && nx < b.size.w && ny >= 0 && ny < b.size.h &&
            !visited[nx][ny] {
                _, is_black := b.cells[nx][ny].(BLACK)
                if !is_black {
                    visited[nx][ny] = true
                    append(&queue, Position{ nx, ny })
                }
            }
        }
    }

    for x in 0 ..< b.size.w {
        for y in 0 ..< b.size.h {
            if !visited[x][y] {
                _, is_black := b.cells[x][y].(BLACK)
                if !is_black {
                    return false
                }
            }
        }
    }

    return true
}

fill_with_white :: proc(b: ^Board) {
    for i := 0; i < b.size.w; i += 1 {
        for j := 0; j < b.size.h; j += 1 {
            if b.cells[i][j] == nil {
                b.cells[i][j] = WHITE{ }
            }
        }
    }
}

place_observers :: proc(b: ^Board) {
    for i := 0; i < b.size.w; i += 1 {
        for j := 0; j < b.size.h; j += 1 {
            cell, is_white := b.cells[i][j].(WHITE)
            if is_white && random_percent(OBSERVER_CHANCE) {
                s, visible := visible_white(b, { x = i, y = j })
                cell.desired_visible = visible
                b.cells[i][j] = cell
            }
        }
    }
}

transform_into_starting_pos :: proc(b: Board) -> (out: Board) {
    out.cells = make([][]FieldState, b.size.w)
    for &x in out.cells {
        x = make([]FieldState, b.size.h)
    }

    out.size = b.size

    for i := 0; i < b.size.w; i += 1 {
        for j := 0; j < b.size.h; j += 1 {
            cell, is_white :=  b.cells[i][j].(WHITE)
            if is_white {
                if b.cells[i][j].(WHITE).desired_visible != nil {
                    out.cells[i][j] = b.cells[i][j]
                } else {
                    out.cells[i][j] = BLANK{ }
                }
            } else {
                out.cells[i][j] = BLANK{ }
            }
        }
    }

    return
}

has_arg :: proc(arg: string) -> bool {
    if slice.contains(os.args, arg) {
        return true
    }
    return false
}

get_value :: proc(arg: string) -> Maybe(string) {
    for i := 0; i < len(os.args); i += 1 {
        if os.args[i] == arg {
            return os.args[i + 1]
        }
    }

    return nil
}

random_percent :: proc(percent: f64) -> bool {
    r := rand.float64_range(0.0, 1.0)
    if r < percent {
        return true
    }
    return false
}

convert_into_export_data :: proc(b: Board, seed: u64) -> (out: starting_Board) {
    out.size = b.size
    out.seed = seed

    for i := 0; i < b.size.w; i += 1 {
        for j := 0; j < b.size.h; j += 1 {
            cell, is_white :=  b.cells[i][j].(WHITE)
            if is_white {
                if b.cells[i][j].(WHITE).desired_visible != nil {
                    append(&out.starting_positions, starting_Position{
                        x = i,
                        y = j,
                        desired_visible = cell.desired_visible.?
                    })
                }
            }
        }
    }

    return
}

main :: proc() {
    defer free_all(context.allocator)
    s := time.Stopwatch{ }
    repeat := 1

    seed := u64(time.time_to_unix_nano(time.now()))
    seed ~= u64(intrinsics.read_cycle_counter())

    rand.reset(seed)

    if has_arg("-seed") {
        user_seed := get_value("-seed")
        if user_seed != nil {
            ok: bool
            seed, ok = strconv.parse_u64(user_seed.?)
            if !ok {
                os.exit(42069)
            }
            rand.reset(seed)
        }
    }

    if has_arg("-number") {
        user_number := get_value("-number")
        if user_number != nil {
            ok: bool
            repeat, ok = strconv.parse_int(user_number.?)
            if !ok {
                os.exit(42069)
            }
        }
    }

    for i in 0 ..< repeat {
        g := Grid{
            w = 9, h = 9
        }
        b := Board{
            size = g
        }
        b.cells = make([][]FieldState, g.w)
        for &x in b.cells {
            x = make([]FieldState, g.h)
        }

        time.stopwatch_reset(&s)
        time.stopwatch_start(&s)

        place_random_black(&b)
        fill_with_white(&b)
        place_observers(&b)

        starting_b := transform_into_starting_pos(b)

        time.stopwatch_stop(&s)

        fmt.println("original board:")
        print_board(&b)

        fmt.println("starting position:")
        print_board(&starting_b)

        export_b := convert_into_export_data(starting_b, seed)

        export_data := make([dynamic]starting_Board)

        f, open_err := os.open("generated.json", os.O_CREATE | os.O_WRONLY | os.O_RDWR )
        if open_err != nil {
            os.exit(42069)
        }

        d, ok := os.read_entire_file("generated.json")
        if !ok {
            os.exit(42069)
        }
        json.unmarshal(d, &export_data)

        append(&export_data, export_b)

        data, err := json.marshal(export_data, { pretty = true })
        if err != nil {
            os.exit(42069)
        }

        _, write_err := os.write(f, data)
        if write_err != nil {
            os.exit(42069)
        }

        fmt.printfln("board generated in %#v, using seed: %#v", time.stopwatch_duration(s), seed)
    }

    return
}
