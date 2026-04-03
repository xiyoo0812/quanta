
return {
    name = "login_ai",
    root = 1,
    rewind = 1,
    nodes = {
        [1] = {
            type = "CASE",
            case = "login_base",
            next = 2
        },
        [2] = {
            type = "WAIT",
            time = 500,
            next = 3
        },
        [3] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PLAYER_LOGOUT_REQ",
            inputs = {
                player_id = { type = "attr", value = "player_id" },
            },
        },
    }
}