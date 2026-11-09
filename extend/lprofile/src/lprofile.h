#pragma once

#include <chrono>
#include <fstream>
#include <sstream>
#include <unordered_set>

#include "lua_kit.h"

using namespace std;
using namespace luakit;
using namespace std::chrono;

namespace lprofile {
    
    static thread_local bool t_profilable = false;

    static constexpr uint64_t flame_suspend_key = (std::numeric_limits<uint64_t>::max)();
    static constexpr size_t flame_max_nodes = 50000;
    static constexpr int flame_min_dist = 90;    //相邻不同名帧的最小色差阈值

    struct flame_node {
        string name;                  //显示名（拷贝，避免 VM 字符串被 GC 后悬垂）
        string source;                //源文件
        string color;                 //导出时预分配的颜色（含相邻去撞色）
        uint32_t line = 0;            //定义行号
        bool inlua = true;            //Lua 函数 / C 函数
        bool suspend = false;         //虚拟节点：协程挂起 / 线程阻塞段
        uint64_t pointer = 0;         //函数指针（children 的 key）
        uint64_t self_time = 0;       //纯自身耗时（exclusive，us）
        uint64_t total_time = 0;      //帧整段墙钟（inclusive，us）= 火焰图格宽
        uint64_t suspend_time = 0;    //本帧发起的挂起等待累计（us）
        uint64_t cpu_total = 0;       //导出时缓存：整棵子树的 CPU 口径宽度
        uint64_t call_count = 0;      //结算次数
        uint32_t depth = 0;           //所在层级（root=0），导出时用于 y 坐标
        flame_node* parent = nullptr; //非拥有，回溯栈路径用
        unordered_map<uint64_t, unique_ptr<flame_node>> children;
    };

    struct call_frame {
        bool inlua = true;
        bool tail = false;
        cpchar name = nullptr;
        cpchar source = nullptr;
        uint32_t line = 0;
        uint64_t pointer = 0;
        uint64_t sub_cost = 0;
        uint64_t call_tick = 0;
        flame_node* flame_pos = nullptr;  //本帧在调用树中的位置（pop 时无需回退，父帧自带）
    };

    struct call_info {
        lua_State* co = nullptr;
        uint64_t leave_tick = 0;
        list<call_frame> call_list;
    };

    class eval_data {
    public:
        //自定义比较函数
        bool operator<(const eval_data& b) const {
            if (total_time == b.total_time) return pointer > b.pointer;
            return total_time > b.total_time;
        }

        bool inlua = true;
        uint32_t line = 0;
        uint64_t min_time = 0;
        uint64_t max_time = 0;
        uint64_t pointer = 0;
        uint64_t call_tick = 0;
        uint64_t call_count = 0;
        uint64_t total_time = 0;
        uint64_t suspend_time = 0;
        cpchar source = nullptr;
        cpchar name = nullptr;
    };

    class profile : public lib_hooker {
    public:
        void enable() {
            t_profilable = true;
        }

        void disable() {
            t_profilable = false;
        }

        virtual void on_lib_load(lua_State* L, cpchar lib) {
            lua_guard g(L);
            lua_getglobal(L, lib);
            if (lua_istable(L, -1)) {
                lua_pushnil(L);
                while (lua_next(L, -2) != 0) {
                    if (lua_isfunction(L, -1)) {
                        auto name = std::format("{}.{}", lib, lua_tostring(L, -2));
                        m_c_names.emplace((uint64_t)lua_topointer(L, -1), std::move(name));
                    }
                    lua_pop(L, 1);
                }
            }
        }

        int ignore(lua_State* L, cpchar key) {
            lua_guard g(L);
            lua_getglobal(L, key);
            if (lua_istable(L, -1)) {
                lua_pushnil(L);
                while (lua_next(L, -2) != 0) {
                    if (lua_isfunction(L, -1)) {
                        auto buf = std::format("{}.{}", key, lua_tostring(L, -2));
                        m_ignore_funcs.emplace((uint64_t)lua_topointer(L, -1), std::move(buf));
                    }
                    lua_pop(L, 1);
                }
                return 0;
            }
            if (lua_isfunction(L, -1)) {
                m_ignore_funcs.emplace((uint64_t)lua_topointer(L, -1), key);
            }
            return 0;
        }

        void ignore_file(cpchar filename) {
            m_ignore_files.emplace(filename, true);
        }

        void ignore_func(cpchar funcname) {
            m_ignore_names.emplace(funcname, true);
        }

        int watch(lua_State* L) {
            cpchar name = lua_tolstring(L, 1, nullptr);
            if (lua_type(L, 2) == LUA_TTABLE) {
                lua_getfield(L, 2, name);
                if (lua_isfunction(L, -1)) {
                    uint64_t pointer = (uint64_t)lua_topointer(L, -1);
                    m_watch_funcs.emplace(pointer, name);
                }
                return 0;
            }
            m_watch_files.emplace(name, true);
            return 0;
        }

        int hook(lua_State* L) {
            auto luahook = [](lua_State* DL, lua_Debug* ar) {
                if (!t_profilable) return;
                lua_guard g(DL);
                lua_getfield(DL, LUA_REGISTRYINDEX, "profile");
                profile* prof = (profile*)lua_touserdata(DL, -1);
                if (prof) prof->prof_hook(DL, ar);
            };
            lua_guard g(L);
            lua_getglobal(L, "coroutine");
            lua_push_function(L, [&](lua_State* L) -> int {
                luaL_checktype(L, 1, LUA_TFUNCTION);
                lua_State* NL = lua_newthread(L);
                lua_pushvalue(L, 1);  /* move function to top */
                lua_sethook(NL, luahook, LUA_MASKCALL | LUA_MASKRET, 0);
                lua_xmove(L, NL, 1);  /* move function from L to NL */
                return 1;
            });
            lua_setfield(L, -2, "create");
            //save profile context
            lua_pushlightuserdata(L, this);
            lua_setfield(L, LUA_REGISTRYINDEX, "profile");
            //init lua ignore
            init_lua_profile(L);
            //调用树根节点
            m_flame_root.name = "root";
            m_flame_root.inlua = false;
            //hook self
            lua_sethook(L, luahook, LUA_MASKCALL | LUA_MASKRET, 0);
            return 0;
        }

        int dump(lua_State* L, int top = 0) {
            set<eval_data> evals;
            for (auto& [_, data] : m_evals) {
                evals.insert(data);
            }
            int i = 1;
            lua_newtable(L);
            for (auto& data : evals) {
                lua_newtable(L);
                native_to_lua(L, data.name);
                lua_setfield(L, -2, "name");
                native_to_lua(L, data.line);
                lua_setfield(L, -2, "line");
                native_to_lua(L, data.source);
                lua_setfield(L, -2, "src");
                native_to_lua(L, data.inlua ? "L" : "C");
                lua_setfield(L, -2, "flag");
                native_to_lua(L, round(double(data.total_time) / data.call_count) / 1000);
                lua_setfield(L, -2, "avg");
                native_to_lua(L, round(double(data.total_time * 1000) / m_all_times) / 10);
                lua_setfield(L, -2, "per");
                native_to_lua(L, round(double(data.suspend_time) / data.call_count) / 1000);
                lua_setfield(L, -2, "suspend");
                native_to_lua(L, double(data.min_time) / 1000);
                lua_setfield(L, -2, "min");
                native_to_lua(L, double(data.max_time) / 1000);
                lua_setfield(L, -2, "max");
                native_to_lua(L, double(data.total_time) / 1000);
                lua_setfield(L, -2, "all");
                native_to_lua(L, data.call_count);
                lua_setfield(L, -2, "count");
                lua_seti(L, -2, i++);
                if (top > 0 && i >= top) break;
            }
            m_evals.clear();
            m_all_times = 0;
            return 1;
        }

        bool flame(cpchar filename, bool include_suspend = true) {
            if (!filename || !*filename) return false;
            m_flame_include_suspend = include_suspend;
            std::ofstream file(filename, std::ios::out | std::ios::binary | std::ios::trunc);
            if (!file.is_open()) return false;
            constexpr double canvas_w = 1200.0;
            constexpr double row_h = 18.0;
            constexpr double pad = 10.0;
            constexpr double margin_x = 20.0;   //火焰图左右留白
            constexpr double top_h = 32.0;      //顶部标题 / 工具栏
            constexpr double bot_h = 28.0;      //底部悬停详情栏
            constexpr uint32_t max_row = 64;
            //总宽度：root 的当前口径跨度；为 0 时用 children 之和兜底
            if (!include_suspend) flame_prepare_cpu(m_flame_root);
            uint64_t all = flame_width_time(m_flame_root);
            if (all == 0) {
                for (auto& [_, child] : m_flame_root.children) {
                    all += flame_width_time(*child);
                }
            }
            if (all == 0) all = 1;
            double scale = (canvas_w - 2 * margin_x) / double(all);
            uint32_t rows = flame_row(m_flame_root, 0, max_row);
            double canvas_h = top_h + pad + (rows + 1) * row_h + pad + bot_h;

            std::ostringstream svg;
            svg << "<svg xmlns=\"http://www.w3.org/2000/svg\" version=\"1.1\" "
                << "width=\"" << canvas_w << "\" height=\"" << canvas_h << "\" "
                << "viewBox=\"0 0 " << canvas_w << " " << canvas_h << "\">\n";
            svg << "<title>lprofile flamegraph</title>\n";
            svg << "<defs><linearGradient id=\"fg-bg\" x1=\"0\" y1=\"0\" x2=\"0\" y2=\"1\">"
                << "<stop offset=\"5%\" stop-color=\"#eeeeee\"/>"
                << "<stop offset=\"95%\" stop-color=\"#eeeeb0\"/>"
                << "</linearGradient></defs>\n";
            svg << "<rect x=\"0\" y=\"0\" width=\"" << canvas_w << "\" height=\"" << canvas_h << "\" fill=\"url(#fg-bg)\"/>\n";
            svg << "<style>text{font:11px monospace;fill:#000000;pointer-events:none}"
                << "rect{stroke:#ffffff;stroke-width:0.5}"
                << "g.frame{cursor:pointer}"
                << "g.frame:hover rect{stroke:#333333;stroke-width:1}"
                << "g.frame:hover text{font-weight:bold}"
                << "#fg-unzoom{cursor:pointer;pointer-events:auto}</style>\n";
            svg << "<text x=\"" << canvas_w / 2 << "\" y=\"22\" text-anchor=\"middle\" "
                << "style=\"font-size:15px;font-family:Verdana,sans-serif\">Flame Graph</text>\n";
            svg << "<text id=\"fg-unzoom\" x=\"" << margin_x << "\" y=\"22\" opacity=\"0.25\">Reset Zoom</text>\n";
            svg << "<text id=\"fg-info\" x=\"" << canvas_w - margin_x << "\" y=\"22\" text-anchor=\"end\">total "
                << flame_num(double(all) / 1000.0) << " ms | nodes " << m_flame_nodes
                << " | " << (include_suspend ? "wall-clock (incl. suspend)" : "cpu-only (suspend excluded)")
                << " | click a frame to zoom</text>\n";
            uint32_t next_id = 0;
            flame_emit(m_flame_root, svg, scale, 0, margin_x, pad, row_h, max_row, double(all), rows, top_h, next_id, "", "");
            svg << "<text id=\"fg-details\" x=\"" << margin_x << "\" y=\"" << (canvas_h - 10) << "\">hover a frame for details</text>\n";
            svg << "<script type=\"text/javascript\"><![CDATA[\n" << flame_js() << "\n]]></script>\n";
            svg << "</svg>\n";
            file << svg.str();
            file.close();
            return true;
        }

    protected:
        flame_node* flame_child(flame_node* parent, call_frame& frame) {
            if (!parent) parent = &m_flame_root;
            auto key = frame.pointer;
            if (auto it = parent->children.find(key); it != parent->children.end()) {
                return it->second.get();
            }
            if (m_flame_nodes >= flame_max_nodes) return parent;
            auto node = make_unique<flame_node>();
            node->name = frame.name ? frame.name : "null";
            node->source = frame.source ? frame.source : "null";
            node->line = frame.line;
            node->inlua = frame.inlua;
            node->pointer = key;
            node->parent = parent;
            node->depth = parent->depth + 1;
            auto* raw = node.get();
            parent->children.emplace(key, std::move(node));
            ++m_flame_nodes;
            return raw;
        }

        flame_node* flame_suspend(flame_node* parent, call_frame& frame) {
            if (!parent) parent = &m_flame_root;
            if (auto it = parent->children.find(flame_suspend_key); it != parent->children.end()) {
                return it->second.get();
            }
            if (m_flame_nodes >= flame_max_nodes) return nullptr;
            auto node = make_unique<flame_node>();
            node->name = "suspend";
            node->source = frame.source ? frame.source : "";
            node->line = frame.line;
            node->inlua = false;
            node->suspend = true;
            node->parent = parent;
            node->depth = parent->depth + 1;
            auto* raw = node.get();
            parent->children.emplace(flame_suspend_key, std::move(node));
            ++m_flame_nodes;
            return raw;
        }

        void flame_reset(flame_node& node) {
            node.self_time = 0;
            node.total_time = 0;
            node.suspend_time = 0;
            node.cpu_total = 0;
            node.call_count = 0;
            for (auto& [_, child] : node.children) {
                flame_reset(*child);
            }
        }

        bool flame_filter(flame_node& node) {
            if (node.suspend_time > 0) return false;
            if (node.line == 0) return true;        //load 加载的块
            if (m_watch_funcs.contains(node.pointer)) return false;
            if (m_ignore_names.contains(node.name)) return true;
            if (!node.inlua && m_ignore_funcs.contains(node.pointer)) return true;
            if (m_watch_files.empty()) {
                return m_ignore_files.contains(node.source);
            }
            return m_watch_files.contains(node.source);
        }

        static string flame_escape(const string& s) {
            string out;
            out.reserve(s.size() + 8);
            for (char c : s) {
                switch (c) {
                    case '&': out += "&amp;"; break;
                    case '<': out += "&lt;"; break;
                    case '>': out += "&gt;"; break;
                    case '"': out += "&quot;"; break;
                    case '\'': out += "&apos;"; break;
                    default: out += c;
                }
            }
            return out;
        }

        static string flame_num(double v) {
            char buf[32] = {};
            snprintf(buf, sizeof(buf), "%.2f", v);
            return buf;
        }

        static uint32_t flame_mix(uint32_t h) {
            h ^= h >> 16; h *= 0x85ebca6bu;
            h ^= h >> 13; h *= 0xc2b2ae35u;
            h ^= h >> 16;
            return h;
        }
        
        static int flame_dist(const string& a, const string& b) {
            int ar = 0, ag = 0, ab = 0, br = 0, bg = 0, bb = 0;
            if (sscanf(a.c_str(), "rgb(%d,%d,%d)", &ar, &ag, &ab) != 3) return 9999;
            if (sscanf(b.c_str(), "rgb(%d,%d,%d)", &br, &bg, &bb) != 3) return 9999;
            return abs(ag - bg) + 2 * abs(ar - br) + abs(ab - bb);
        }
        
        static string flame_color(flame_node& node, uint32_t salt = 0) {
            uint32_t h = 2166136261u;
            for (unsigned char c : node.name) {
                h ^= c;
                h *= 16777619u;
            }
            if (salt) h ^= salt * 0x9e3779b9u;
            h = flame_mix(h);
            double v1 = double(h & 0xff) / 255.0;
            double v2 = double((h >> 8) & 0xff) / 255.0;
            double v3 = double((h >> 16) & 0xff) / 255.0;
            int r = 205 + int(50 * v3);
            int g = int(230 * v1);
            int b = int(55 * v2);
            char buf[48] = {};
            snprintf(buf, sizeof(buf), "rgb(%d,%d,%d)", r, g, b);
            return buf;
        }

        static cpchar flame_js() {
            return R"FGJS(
(function(){
  var W = 1200.0, PAD = 20, CW = W - 2 * PAD, zoomed = null;
  var frames = Array.prototype.slice.call(document.querySelectorAll('g.frame'));
  var info = document.getElementById('fg-info');
  var details = document.getElementById('fg-details');
  var unzoomBtn = document.getElementById('fg-unzoom');
  var base = info ? info.textContent : '';
  var idle = details ? details.textContent : '';
  if (!frames.length) return;
  //官方 update_text 思路：用 SVG 的 getSubStringLength 按真实像素测量，
  //二分找最长可容纳前缀，末尾补 ".."。zoom 后格子变宽会自动显示更多文字。
  function measurable(g) {
    var t = g.querySelector('text');
    if (!t || !t.getSubStringLength) return false;
    //窄帧的 text 初始为空，空文本上 getSubStringLength 会返回 0，
    //会被误判成"布局未完成"。临时填一个字符再测，测完还原。
    var old = t.textContent;
    t.textContent = g.getAttribute('data-name') || 'x';
    var ok = false;
    try { ok = t.getSubStringLength(0, 1) > 0; } catch (e) { ok = false; }
    t.textContent = old;
    return ok;
  }
  function update_text(g) {
    if (!measurable(g)) return;
    var r = g.querySelector('rect'), t = g.querySelector('text');
    var name = g.getAttribute('data-name') || '';
    var w = parseFloat(r.getAttribute('width')) - 6;
    t.textContent = name;
    if (w < 3 * 11 * 0.59) { t.textContent = ''; return; }
    if (t.getSubStringLength(0, name.length) <= w) return;
    var lo = 0, hi = name.length;
    while (lo < hi) {
      var mid = Math.floor((lo + hi + 1) / 2);
      if (t.getSubStringLength(0, mid) <= w) lo = mid; else hi = mid - 1;
    }
    t.textContent = lo < 2 ? '' : name.substring(0, lo - 2) + '..';
  }
  function init_texts() {
    frames.forEach(function(g) { update_text(g); });
  }
  function place(g, x, w, fill) {
    var r = g.querySelector('rect'), t = g.querySelector('text');
    r.setAttribute('x', x);
    r.setAttribute('width', w);
    if (fill) r.setAttribute('fill', fill);
    if (t) t.setAttribute('x', x + 3);
    update_text(g);
  }
  function reset() {
    frames.forEach(function(g) {
      g.style.display = '';
      g.removeAttribute('opacity');
      place(g, parseFloat(g.getAttribute('data-x')), parseFloat(g.getAttribute('data-w')),
            g.getAttribute('data-fill'));
    });
    zoomed = null;
    if (info) info.textContent = base;
    if (details) details.textContent = idle;
    if (unzoomBtn) unzoomBtn.setAttribute('opacity', '0.25');
  }
  function zoom(g) {
    var id = g.getAttribute('data-id');
    var tx = parseFloat(g.getAttribute('data-x'));
    var tw = parseFloat(g.getAttribute('data-w')) || 1;
    var anc = (g.getAttribute('data-anc') || '').split(',');
    var f = CW / tw;
    frames.forEach(function(o) {
      var oid = o.getAttribute('data-id');
      var oanc = (o.getAttribute('data-anc') || '').split(',');
      var below = anc.indexOf(oid) >= 0;
      var inside = (oid === id) || (oanc.indexOf(id) >= 0);
      if (!below && !inside) { o.style.display = 'none'; return; }
      o.style.display = '';
      if (below) {
        o.setAttribute('opacity', '0.5');
        place(o, PAD, CW, '#9aa0a6');
      } else {
        o.removeAttribute('opacity');
        var ox = parseFloat(o.getAttribute('data-x'));
        var ow = parseFloat(o.getAttribute('data-w'));
        place(o, PAD + (ox - tx) * f, ow * f, o.getAttribute('data-fill'));
      }
    });
    zoomed = id;
    if (info) info.textContent = 'zoom: ' + g.getAttribute('data-name')
      + ' | click the background or Reset Zoom';
    if (unzoomBtn) unzoomBtn.setAttribute('opacity', '1');
  }
  init_texts();
  if (typeof window !== 'undefined' && window.addEventListener) {
    window.addEventListener('load', init_texts);
  }
  document.documentElement.addEventListener('click', function(e) {
    if (e.target && e.target.getAttribute && e.target.getAttribute('id') === 'fg-unzoom') {
      reset(); return;
    }
    var g = (e.target && e.target.closest) ? e.target.closest('g.frame') : null;
    if (!g) { reset(); return; }
    if (zoomed === g.getAttribute('data-id')) reset(); else zoom(g);
  });
  document.documentElement.addEventListener('mouseover', function(e) {
    var g = (e.target && e.target.closest) ? e.target.closest('g.frame') : null;
    if (!g || !details) return;
    var tip = g.querySelector('title');
    details.textContent = tip ? tip.textContent : (g.getAttribute('data-name') || '');
  });
  document.documentElement.addEventListener('mouseout', function(e) {
    var g = (e.target && e.target.closest) ? e.target.closest('g.frame') : null;
    if (g && details) details.textContent = idle;
  });
})();
)FGJS";
        }

        static size_t flame_trunc(const string& s, size_t n) {
            if (s.size() <= n) return s.size();
            while (n > 0 && (static_cast<unsigned char>(s[n]) & 0xC0) == 0x80) n--;
            return n;
        }

        uint32_t flame_row(flame_node& node, uint32_t row, uint32_t cap) {
            if (row >= cap) return cap;
            bool hidden = &node != &m_flame_root && flame_filter(node);
            uint32_t child_row = hidden ? row : row + 1;
            uint32_t max_d = hidden ? (row > 0 ? row - 1 : 0) : row;
            for (auto& [_, child] : node.children) {
                max_d = (std::max)(max_d, flame_row(*child, child_row, cap));
            }
            return max_d;
        }

        uint64_t flame_prepare_cpu(flame_node& node) {
            uint64_t s = node.self_time;
            for (auto& [_, kid] : node.children) {
                s += flame_prepare_cpu(*kid);
            }
            node.cpu_total = s;
            return s;
        }
        
        uint64_t flame_width_time(flame_node& node) {
            return m_flame_include_suspend ? node.total_time : node.cpu_total;
        }

        double flame_span(flame_node& node, double scale) {
            if (!flame_filter(node)) return double(flame_width_time(node)) * scale;
            double s = 0.0;
            for (auto& [_, kid] : node.children) {
                s += flame_span(*kid, scale);
            }
            return s;
        }

        void flame_emit(flame_node& node, std::ostringstream& svg, double scale,
                        uint32_t row, double x0, double pad, double row_h,
                        uint32_t cap, double all, uint32_t rows, double top_h,
                        uint32_t& next_id, const string& anc,
                        const string& parent_color) {
            if (row > cap) return;
            bool is_root = &node == &m_flame_root;
            bool hidden = !is_root && flame_filter(node);
            double w = is_root ? double(all) * scale
                               : (hidden ? flame_span(node, scale)
                                         : double(flame_width_time(node)) * scale);
            if (w < 0.05) return;

            string fill = node.color.empty() ? flame_color(node) : node.color;
            string child_parent_color = hidden ? parent_color : fill;
            string child_anc = anc;
            if (!hidden) {
                uint32_t my_id = next_id++;
                child_anc = anc.empty() ? std::to_string(my_id) : anc + "," + std::to_string(my_id);
                double y = top_h + pad + double(int(rows) - int(row)) * row_h;
                string label;
                size_t max_chars = w > 20 ? size_t((w - 8) / 6.5) : 0;
                if (max_chars >= 3) {
                    size_t n = flame_trunc(node.name, max_chars);
                    if (n < node.name.size()) n = flame_trunc(node.name, max_chars - 1);
                    label = node.name.substr(0, n);
                    if (n < node.name.size()) label += "..";
                }
                uint64_t wtime = flame_width_time(node);
                double pct = all > 0 ? double(wtime) * 100.0 / all : 0.0;
                string tip = node.name + " | total " + flame_num(double(wtime) / 1000.0)
                    + " ms | self " + flame_num(double(node.self_time) / 1000.0)
                    + " ms | " + flame_num(pct) + "% | " + std::to_string(node.call_count)
                    + " calls | " + node.source + ":" + std::to_string(node.line);
                svg << "<g class=\"frame\" data-id=\"" << my_id
                    << "\" data-anc=\"" << flame_escape(anc) 
                    << "\" data-row=\"" << row
                    << "\" data-x=\"" << flame_num(x0)
                    << "\" data-w=\"" << flame_num(w)
                    << "\" data-fill=\"" << fill
                    << "\" data-name=\"" << flame_escape(node.name)
                    << "\"><title>" << flame_escape(tip) << "</title>"
                    << "<rect x=\"" << flame_num(x0) << "\" y=\"" << flame_num(y)
                    << "\" width=\"" << flame_num(w) << "\" height=\"" << flame_num(row_h - 1)
                    << "\" rx=\"2\" ry=\"2\" fill=\"" << fill << "\"/>";
                svg << "<text x=\"" << flame_num(x0 + 3) << "\" y=\"" << flame_num(y + row_h * 0.7)
                    << "\">" << flame_escape(label) << "</text>";
                svg << "</g>\n";
            }
            std::vector<flame_node*> kids;
            kids.reserve(node.children.size());
            for (auto& [_, child] : node.children) kids.push_back(child.get());
            std::sort(kids.begin(), kids.end(), [](flame_node* a, flame_node* b) {
                if (a->total_time != b->total_time) return a->total_time > b->total_time;
                return a->name < b->name;
            });
            string prev_color = parent_color.empty()
                ? (node.color.empty() ? flame_color(node) : node.color)
                : parent_color;
            string prev_name = node.name;
            for (auto* kid : kids) {
                string c = flame_color(*kid);
                if (kid->name != prev_name && !prev_color.empty() && flame_dist(c, prev_color) < flame_min_dist) {
                    for (uint32_t s = 1; s <= 12; ++s) {
                        string alt = flame_color(*kid, s);
                        if (flame_dist(alt, prev_color) >= flame_min_dist) { c = alt; break; }
                    }
                }
                kid->color = c;
                prev_color = c;
                prev_name = kid->name;
            }
            double kids_w = 0.0;
            for (auto* kid : kids) kids_w += flame_span(*kid, scale);
            double cx = x0 + (std::max)(0.0, (w - kids_w) * 0.5);
            uint32_t child_row = hidden ? row : row + 1;
            for (auto* kid : kids) {
                double kspan = flame_span(*kid, scale);
                if (cx + kspan > x0 + w + 0.5) break;   //不越出父格
                flame_emit(*kid, svg, scale, child_row, cx, pad, row_h, cap, all,
                           rows, top_h, next_id, child_anc, child_parent_color);
                cx += kspan;
            }
        }

        cpchar find_c_name(lua_State* L, uint64_t pointer, cpchar name) {
            if (auto it = m_c_names.find(pointer);  it != m_c_names.end()) {
                return it->second.c_str();
            }
            return name ? name : "C function";
        }

        void settle_frame(list<call_frame>& call_list, uint64_t now_tick, uint64_t co_cost) {
            call_frame& cur_frame = call_list.back();
            uint64_t diff = now_tick - cur_frame.call_tick;
            uint64_t call_cost = diff > cur_frame.sub_cost ? diff - cur_frame.sub_cost : 0;
            uint64_t suspend_cost = 0;
            if (m_suspend_funcs.contains(cur_frame.name)) {
                suspend_cost = call_cost;
                call_cost = 0;
            }
            record_eval(cur_frame, call_cost, suspend_cost);
            if (auto* node = cur_frame.flame_pos; node) {
                node->call_count++;
                node->self_time += call_cost;
                node->total_time += diff;
                node->suspend_time += suspend_cost;
            }
            bool is_top = call_list.size() == 1;
            if (is_top) {
                m_flame_root.total_time += diff;
            }
            call_list.pop_back();
            if (!call_list.empty()) {
                uint64_t rd_tick = now() - now_tick;
                call_list.back().sub_cost += (cur_frame.sub_cost + call_cost + suspend_cost + rd_tick + co_cost);
            }
        }

        void sync_call_list(lua_State* L, uint64_t nowtick, uint64_t co_cost) {
            auto& call_list = m_cur_ci->call_list;
            if (call_list.empty()) return;
            uint64_t top_ptr = call_list.back().pointer;
            lua_Debug ar;
            for (int d = 0; lua_getstack(L, d, &ar); d++) {
                lua_getinfo(L, "f", &ar);
                uint64_t ptr = (uint64_t)lua_topointer(L, -1);
                lua_pop(L, 1);
                if (ptr == top_ptr) return;    //顶帧还活着，无残留
            }
            //顶帧已不在栈中：结算它，然后重复检查新的顶帧
            while (!call_list.empty()) {
                top_ptr = call_list.back().pointer;
                bool alive = false;
                for (int d = 0; lua_getstack(L, d, &ar); d++) {
                    lua_getinfo(L, "f", &ar);
                    uint64_t ptr = (uint64_t)lua_topointer(L, -1);
                    lua_pop(L, 1);
                    if (ptr == top_ptr) { alive = true; break; }
                }
                if (alive) break;              //新的顶帧还活着，停止
                //真残留：按正常返回结算（与 RET 循环同一套记账逻辑）
                settle_frame(call_list, nowtick, co_cost);
            }
        }

        void prof_hook(lua_State* L, lua_Debug* arv) {
            uint64_t co_cost = 0;
            uint64_t nowtick = now();
            call_info* old_ci = m_cur_ci;
            if (old_ci && old_ci->co != L) {
                old_ci->leave_tick = nowtick;
            }
            if (auto it = m_call_infos.find(L); it != m_call_infos.end()) {
                m_cur_ci = it->second;
                if (old_ci != m_cur_ci && m_cur_ci->leave_tick > 0) {
                    co_cost = nowtick - m_cur_ci->leave_tick;
                }
            } else {
                m_cur_ci = new call_info{ L };
                m_call_infos.emplace(L, m_cur_ci);
            }
            if (arv->event != LUA_HOOKTAILCALL) {
                sync_call_list(L, nowtick, co_cost);
            }
            if (arv->event == LUA_HOOKCALL || arv->event == LUA_HOOKTAILCALL) {
                lua_Debug ar;
                lua_getstack(L, 0, &ar);
                lua_getinfo(L, "nSlf", &ar);
                lua_getinfo(L, "f", &ar);
                uint64_t func_ptr = (uint64_t)lua_topointer(L, -1);
                lua_pop(L, 1);
                call_frame frame;
                frame.source = ar.source;
                frame.pointer = func_ptr;
                frame.line = ar.linedefined;
                if (ar.what[0] == 'C') {
                    frame.inlua = false;
                    lua_Debug arv;
                    int i = 0;
                    while (true) {
                        if (!lua_getstack(L, ++i, &arv)) break;
                        lua_getinfo(L, "Sl", &arv);
                        if (arv.what[0] != 'C') {
                            frame.line = arv.currentline;
                            frame.source = arv.source;
                            break;
                        }
                    }
                }
                if (frame.inlua) {
                    frame.name = ar.name ? ar.name : "closure";
                } else {
                    frame.name = find_c_name(L, frame.pointer, ar.name);
                }
                frame.tail = arv->event == LUA_HOOKTAILCALL;
                frame.call_tick = now();
                auto& call_list = m_cur_ci->call_list;
                auto* parent_node = call_list.empty() ? &m_flame_root : call_list.back().flame_pos;
                frame.flame_pos = flame_child(parent_node, frame);
                call_list.push_back(frame);
                return;
            }
            if (arv->event == LUA_HOOKRET) {
                auto& call_list = m_cur_ci->call_list;
                if (call_list.empty()) return;
                while (true) {
                    uint64_t now_tick = now();
                    bool was_tail = call_list.back().tail;
                    settle_frame(call_list, now_tick, co_cost);
                    if (call_list.empty() || !was_tail) break;
                }
            }
        }

        bool is_filter(call_frame& frame) {
            //load加载的函数, 不记录
            if (frame.line == 0) return true;
            //观察的函数，需要记录
            if (m_watch_funcs.contains(frame.pointer)) return false;
            //命中函数名过滤，不记录
            if (m_ignore_names.contains(frame.name)) return true;
            //命中系统函数，不记录
            if (!frame.inlua) {
                if (m_ignore_funcs.contains(frame.pointer)) return true;
            }
            if (m_watch_files.empty()) {
                //关注文件为空，检查过滤文件
                return m_ignore_files.contains(frame.source);
            }
            return m_watch_files.contains(frame.source);
        }

        void record_eval(call_frame& frame, uint64_t call_cost, uint64_t suspend_cost = 0) {
            if (is_filter(frame) && suspend_cost == 0) return;
            m_all_times += call_cost;
            auto id = (uint64_t)frame.pointer;
            auto it = m_evals.find(id);
            if (it == m_evals.end()) {
                eval_data edata;
                edata.call_count++;
                edata.name = frame.name;
                edata.line = frame.line;
                edata.inlua = frame.inlua;
                edata.source = frame.source;
                edata.pointer = frame.pointer;
                edata.min_time = call_cost;
                edata.max_time = call_cost;
                edata.total_time += call_cost;
                edata.suspend_time = suspend_cost;
                m_evals.emplace(id, edata);
                return;
            }
            eval_data& edata = it->second;
            edata.call_count++;
            edata.total_time += call_cost;
            edata.suspend_time += suspend_cost;
            if (call_cost > edata.max_time) {
                edata.max_time = call_cost;
            }
            if (call_cost < edata.min_time) edata.min_time = call_cost;
        }

        void init_lua_profile(lua_State* L) {
            auto ignore_libs = {
                //lua system library
                "io", "os", "math", "utf8", "debug", "table", "string", "package", "profile", "coroutine",
            };
            auto ignores_funcs = {
                // lua system function
                "type", "next", "load", "print", "pcall", "pairs", "error", "assert", "rawget", "rawset",
                "rawlen", "xpcall", "ipairs", "select", "dofile", "require", "loadfile", "tostring",
                "tonumber", "rawequal", "setmetatable", "getmetatable", "collectgarbage",
            };
            for (auto& name : ignore_libs) {
                ignore(L, name);
                on_lib_load(L, name);
            }
            for (auto& name : ignores_funcs) {
                ignore(L, name);
            }
            // lua special function
            ignore_func("for iterator");
            m_suspend_funcs.emplace("coroutine.yield");
            m_suspend_funcs.emplace("coroutine.resume");
        }

        uint64_t now() {
            system_clock::duration dur = system_clock::now().time_since_epoch();
            return duration_cast<microseconds>(dur).count();
        }

    protected:
        uint64_t m_all_times = 0;
        flame_node m_flame_root;        //调用树根（所有顶层调用的虚拟父节点）
        size_t m_flame_nodes = 0;       //已创建的节点数（含 root 之外的全部节点）
        bool m_flame_include_suspend = true;  //本次导出的格宽口径（含/不含挂起等待）
        call_info* m_cur_ci = nullptr;
        unordered_set<string> m_suspend_funcs;
        unordered_map<uint64_t, eval_data> m_evals;
        unordered_map<string, bool> m_watch_files;
        unordered_map<string, bool> m_ignore_names;
        unordered_map<string, bool> m_ignore_files;
        unordered_map<uint64_t, string> m_watch_funcs;
        unordered_map<uint64_t, string> m_ignore_funcs;
        unordered_map<lua_State*, call_info*> m_call_infos;
        unordered_map<uint64_t, string> m_c_names;
    };
}
