return {
    name = "login_base",
    root = 1,
    nodes = {
        [1] = {
            type = "SOCK",
            ip = { type = "attr", value = "ip" },
            port = { type = "attr", value = "port" },
            name = "连接Login",
            next = 2,
        },
        [2] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_ACCOUNT_LOGIN_REQ",
            inputs = {
                openid = { type = "attr", value = "open_id" },
                session = { type = "string", value = "123456" },
                platform = { type = "number", value = 1 },
                device_id = { type = "attr", value = "device_id" },
            },
            outputs = {
                players = { type = "attr", value = "players" },
                user_id = { type = "attr", value = "user_id" },
            },
            before = "robot.players = {}",
            name = "账号登陆",
            next = 3,
        },
        [3] = {
            type = "COND",
            cond = "#robot.players > 0",
            name = "是否创建角色",
            result = {
                success = 4,
                failed = 5,
            },
        },
        [4] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PLAYER_CHOOSE_REQ",
            inputs = {
                user_id = { type = "attr", value = "user_id" },
                player_id = { type = "lua", value = "robot.players[1].player_id" },
            },
            outputs = {
                gate_port = { type = "attr", value = "gate_port" },
                gate_ip = { type = "attr", value = "gate_ip" },
                verify_code = { type = "attr", value = "verify_code" },
                player_id = { type = "attr", value = "player_id" },
                lobby_id = { type = "attr", value = "lobby_id" },
            },
            name = "选择角色",
            next = 6,
        },
        [5] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PLAYER_CREATE_REQ",
            inputs = {
                gender = { type = "number", value = 1 },
                user_id = { type = "attr", value = "user_id" },
                name = { type = "string", value = "test_001" },
            },
            after = "table.insert(robot.players, res.player)",
            name = "创建角色",
            next = 4,
        },
        [6] = {
            type = "SOCK",
            ip = { type = "attr", value = "gate_ip" },
            port = { type = "attr", value = "gate_port" },
            after = "",
            name = "连接Gateway",
            next = 12,
        },
        [7] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PLAYER_LOGIN_REQ",
            inputs = {
                open_id = { type = "attr", value = "open_id" },
                player_id = { type = "attr", value = "player_id" },
            },
            name = "角色登陆",
            next = 8,
        },
        [8] = {
            type = "NTF",
            cmd_id = "NID_ENTITY_ENTER_SCENE_NTF",
            outputs = {
                login_success = { type = "attr", value = "true" },
            },
            name = "进入场景",
        },
        [11] = {
            type = "NTF",
            cmd_id = "NID_GATE_VERIFY_CODE_NTF",
            outputs = {
                verify_code = { type = "attr", value = "verify_code" },
            },
            name = "验证码",
            next = 7,
        },
        [12] = {
            type = "REQ",
            cmd_id = "NID_GATE_BIND_CLIENT_REQ",
            inputs = {
                client_id = { type = "attr", value = "player_id" },
                server_id = { type = "attr", value = "lobby_id" },
                verify_code = { type = "attr", value = "verify_code" },
            },
            outputs = {},
            after = "robot:change_service(\"lobby\")",
            name = "绑定Gateway",
            next = 11,
        },
    },
}