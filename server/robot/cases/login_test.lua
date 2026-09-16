return {
    name = "login_test",
    root = 1,
    nodes = {
        [1] = {
            type = "CASE",
            case = "login_base",
            in_args = {},
            name = "账号登陆",
            next = 2,
        },
        [2] = {
            type = "WAIT",
            time = 1000,
            name = "WAIT1秒",
            next = 3,
        },
        [3] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PLAYER_LOGOUT_REQ",
            inputs = {
                player_id = { type = "attr", value = "player_id" },
            },
            outputs = {},
            name = "账号登出",
        },
    },
}