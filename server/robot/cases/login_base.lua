
return {
    name = "login_base",
    root = 1,
    nodes = {
        [1] = {
            type = "SOCK",
            ip = { type = "attr", value = "ip" },
            port = { type = "attr", value = "port" },
            next = 2
        },
        [2] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_ACCOUNT_LOGIN_REQ",
            inputs = {
                openid = { type = "attr", value = "open_id" },
                session = { type = "attr", value = "access_token" },
                device_id = { type = "attr", value = "device_id" },
                platform = { type = "lua", value = "1" }
            },
            outputs = {
                players = { type = "attr", value = "players" },
                user_id = { type = "attr", value = "user_id" },
            },
            next = 3
        },
        [3] = {
            type = "COND",
            cond = "#robot.players>0",
            result = { success = 4, failed = 5 }
        },
        [4] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_CHOOSE_REQ",
            inputs = {
                user_id = { type = "attr", value = "user_id" },
                player_id = { type = "lua", value = "robot.players[1].player_id" },
            },
            outputs = {
                lobby = { type = "attr", value = "lobby" },
                gate_port = { type = "attr", value = "port" },
                lobby_token = { type = "attr", value = "token" },
                player_id = { type = "attr", value = "player_id" },
                gate_ip = { type = "lua", value = "vars.addrs[1]" },
            },
            next = 6
        },
        [5] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_CREATE_REQ",
            inputs = {
                user_id = { type = "attr", value = "user_id" },
                name = { type = "lua", value = "codec.guid_encode()" },
                gender = { type = "lua", value = "math.random(1, 2)" },
                custom = { type = "lua", value = "quanta.protobuf_mgr:encode_byname('ncmd_cs.playermodel', {model=101, color=0, head=0 })" },
            },
            script = [[table.insert(robot.players, vars.player)]],
            next = 4
        },
        [6] = {
            type = "SOCK",
            ip = { type = "attr", value = "gate_ip" },
            port = { type = "attr", value = "gate_port" },
            next = 7
        },
        [7] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_LOGIN_REQ",
            inputs = {
                lobby = { type = "attr", value = "lobby" },
                token = { type = "attr", value = "lobby_token" },
                user_id = { type = "attr", value = "user_id" },
                open_id = { type = "attr", value = "open_id" },
                player_id = { type = "attr", value = "player_id" },
            },
            outputs = {
                lobby_token = { type = "attr", value = "token" },
            },
            next = 8
        },
        [8] = {
            type = "NTF",
            cmd_id = "NID_ENTITY_ENTER_SCENE_NTF",
            cond = "res.id==robot.player_id",
            outputs = {
                login_success = { type = "lua", value = "true" },
            },
        },
    }
}