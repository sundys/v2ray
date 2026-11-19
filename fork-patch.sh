#!/usr/bin/env bash
# -------------------------------------------------------------
# fork-patch.sh — 重新应用 sundys/v2ray 对脚本的定制
#
# 背景：本仓库 fork 自 mack-a/v2ray-agent。执行 git merge upstream/master 后，
#      脚本里的定制会被上游内容覆盖，或产生冲突。解决冲突后运行本脚本，
#      即可把下列定制重新打到所有脚本上，不必手工逐处修改：
#        1) 项目链接 mack-a/v2ray-agent -> sundys/v2ray（只管项目链接，作者名等文案不动）
#        2) 伪装站菜单 1-9 项标题 -> 与 fodder/blog/unable/html1-9.zip 对应的分类名
#        3) 删除主菜单「推广区 / Promotion area」广告段
#        4) README 里的安装命令指向本 fork（避免照文档装成上游脚本）
#      脚本幂等：先移除旧的 fork-lock 标记再重新应用，重复执行结果一致；
#      各目标文件原有行尾（CRLF / LF）保持不变。
#
# 用法：
#      bash fork-patch.sh                    # 处理下方 TARGET_SPECS 中的全部文件
#      bash fork-patch.sh install.sh         # 只处理指定文件
# -------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

FORK_REPO="sundys/v2ray"           # 本 fork
UPSTREAM_REPO="mack-a/v2ray-agent" # 上游
# 伪装站菜单 1-9 的标题，顺序对应 fodder/blog/unable/html1.zip … html9.zip
MENU_TITLES=(weather music tech video game news finance traffic tools)
# 伪装站（nginx 站点）目录：本 fork 改为 /var/www/html/
SITE_DIR_UPSTREAM="/usr/share/nginx/html/"
SITE_DIR_FORK="/var/www/html/"

# 目标文件清单：路径|伪装站菜单|推广区广告|站点目录|文件头说明|类型(sh=脚本需语法校验, md=文档)
# 只有主脚本有整套定制；英文版有菜单、广告与站点目录；其余文件仅需替换项目链接
TARGET_SPECS=(
    "install.sh|1|1|1|1|sh"
    "shell/install_en.sh|1|1|1|1|sh"
    "shell/init_tls.sh|0|0|1|0|sh"
    "shell/docker_reality.sh|0|0|0|0|sh"
    "shell/empty_login_history.sh|0|0|0|0|sh"
    "shell/ufw_remove.sh|0|0|0|0|sh"
    "README.md|0|0|0|0|md"
    "documents/en/README_EN.md|0|0|0|0|md"
)

die() {
    echo "fork-patch: $*" >&2
    exit 1
}

command -v awk >/dev/null 2>&1 || die "缺少 awk"

# -------------------------------------------------------------
# 处理单个文件：fork_patch_file <路径> <菜单> <广告> <站点目录> <文件头> <类型 sh|md>
# -------------------------------------------------------------
fork_patch_file() {
    local target=$1 with_menu=$2 with_ad=$3 with_sitedir=$4 with_header=$5 kind=${6:-sh}
    local orig_bytes strip_bytes
    local work_dir work

    # 记录原文件行尾：内部统一按 LF 处理，落地前再还原
    # （部分环境 grep/awk 会自动吞掉 CR，故用字节数比对来判断）
    orig_bytes=$(wc -c <"${target}")
    strip_bytes=$(tr -d '\r' <"${target}" | wc -c)
    local orig_eol=lf
    if [[ "${orig_bytes}" -gt "${strip_bytes}" ]]; then
        orig_eol=crlf
    fi

    work_dir=$(mktemp -d) || die "无法创建临时目录"
    work="${work_dir}/$(basename "${target}")"
    tr -d '\r' <"${target}" >"${work}" || die "无法读取 ${target}"

    apply() {
        local program=$1
        shift
        awk -v fork="${FORK_REPO}" -v up="${UPSTREAM_REPO}" "$@" "${program}" "${work}" >"${work}.new"
        mv "${work}.new" "${work}"
    }

    # 0. 移除上一次的 fork-lock 标记（保证可重复执行）
    #    >>> / <<< 块内只丢注释行，实体行保留、稍后整体重写
    apply '
{
    if (skip) {
        if ($0 ~ /# <<< fork-lock/) { skip = 0; next }
        if ($0 ~ /^[ \t]*#/) next
        print
        next
    }
    if ($0 ~ /# >>> fork-lock/) { skip = 1; next }
    if ($0 ~ /^[ \t]*#/ && index($0, "fork-lock")) next
    print
}'

    # 1. 项目链接：mack-a/v2ray-agent -> sundys/v2ray
    sed "s|${UPSTREAM_REPO}|${FORK_REPO}|g" "${work}" >"${work}.new"
    mv "${work}.new" "${work}"

    # 1.1 伪装站（nginx 站点）目录：/usr/share/nginx/html/ -> /var/www/html/
    #     带末尾斜杠与不带斜杠（如 init_tls.sh 的 root 行）两种写法都替换；
    #     凡含该字面路径的非注释行，替换后都在其上方留 fork-lock 标记。
    if [[ "${with_sitedir}" == "1" ]]; then
        apply '
{
    if ($0 !~ /^[ \t]*#/ &&
        (index($0, up_site) || index($0, up_site_ns) ||
         index($0, fork_site) || index($0, fork_site_ns)))
        print "    # fork-lock: nginx 站点目录改为 " fork_site
    if (index($0, up_site)) gsub(up_site, fork_site)
    if (index($0, up_site_ns)) gsub(up_site_ns, fork_site_ns)
    print
}' -v up_site="${SITE_DIR_UPSTREAM}" -v fork_site="${SITE_DIR_FORK}" \
            -v up_site_ns="${SITE_DIR_UPSTREAM%/}" -v fork_site_ns="${SITE_DIR_FORK%/}"
    fi

    # 2. 伪装站菜单 1-9 标题（定位「第 10 项 + 前 9 项依次编号」的菜单块，再整体重写）
    if [[ "${with_menu}" == "1" ]]; then
        apply '
{ line[NR] = $0 }
function menu_num(s,   m) {
    if (match(s, /^[ \t]*echoContent yellow "[0-9]+\./)) {
        m = substr(s, RSTART, RLENGTH)
        sub(/^[ \t]*echoContent yellow "/, "", m)
        sub(/\..*$/, "", m)
        return m + 0
    }
    return 0
}
END {
    n = NR
    idx = 0
    for (i = 10; i <= n; i++) {
        if (line[i] !~ /^[ \t]*echoContent yellow "10\./) continue
        ok = 1
        for (k = 1; k <= 9; k++)
            if (menu_num(line[i - 10 + k]) != k) { ok = 0; break }
        if (ok) { idx = i; break }
    }
    if (idx == 0) {
        printf "fork-patch: 未找到伪装站菜单（第 10 项及其前 9 项），请手动核对 updateNginxBlog\n" > "/dev/stderr"
        exit 1
    }
    start = idx - 9
    split(titles, t, " ")
    for (i = 1; i <= n; i++) {
        if (i == start) {
            print "    # >>> fork-lock: 伪装站模板标题（对应 fodder/blog/unable/html1-9.zip）"
            for (k = 1; k <= 9; k++)
                print "    echoContent yellow \"" k "." t[k] "\""
            print "    # <<< fork-lock"
            i = idx - 1
            continue
        }
        print line[i]
    }
}' -v titles="$(printf '%s ' "${MENU_TITLES[@]}")"
    fi

    # 3. 删除主菜单「推广区 / Promotion area」广告段（并留下 fork-lock 标记）
    if [[ "${with_ad}" == "1" ]]; then
        apply '
{ line[NR] = $0 }
END {
    n = NR
    anchor = 0
    for (i = 1; i <= n; i++)
        if (line[i] ~ /^[ \t]*checkWgetShowProgress[ \t]*$/) { anchor = i; break }
    if (anchor == 0) {
        printf "fork-patch: 未找到主菜单锚点 checkWgetShowProgress，请手动核对 menu\n" > "/dev/stderr"
        exit 1
    }
    adStart = 0
    for (i = anchor + 1; i <= n; i++) {
        if (line[i] ~ /echoContent red "\\n=+ *[^"]*(推广区|Promotion)/) { adStart = i; break }
        if (line[i] ~ /^[ \t]*echoContent red "=+/) break
    }
    marker = "    # fork-lock: 上游主菜单「推广区」广告段已删除（合并上游时请勿恢复）"
    end = 0
    for (i = anchor + 1; i <= n; i++)
        if (line[i] ~ /^[ \t]*echoContent red "=+/) { end = i; break }
    if (end == 0) {
        printf "fork-patch: 未找到主菜单分隔线，请手动核对 menu\n" > "/dev/stderr"
        exit 1
    }
    for (i = 1; i < (adStart > 0 ? adStart : end); i++) print line[i]
    print marker
    for (i = end; i <= n; i++) print line[i]
}'
    fi

    # 4. 改动所在函数处加定位标记（仅 shell 脚本）
    if [[ "${kind}" == "sh" ]]; then
        apply '
BEGIN {
    m["nginxBlog() {"]        = "本函数内模板下载地址指向本 fork (" fork ")"
    m["updateNginxBlog() {"]  = "本函数内模板下载地址与伪装站菜单标题为本 fork 定制"
    m["updateV2RayAgent() {"] = "自更新下载地址指向本 fork (" fork ")"
    m["subscribe() ("]        = "本函数内 sing-box.json 下载地址指向本 fork (" fork ")"
}
{
    ind = ""
    if (match($0, /^[ \t]*/)) ind = substr($0, 1, RLENGTH)
    s = $0
    sub(/^[ \t]*/, "", s)
    if (s in m) print ind "# fork-lock: " m[s]
    if (index($0, "Github：https://github.com/" fork)) print ind "# fork-lock: 项目地址指向本 fork (" fork ")"
    print
}'
    fi

    # 5. 文件头说明块
    if [[ "${with_header}" == "1" ]]; then
        apply '
NR == 1 {
    print
    print "# >>> fork-lock: " fork " 定制版（上游 " up "）"
    print "# 定制点均以 fork-lock 注释标记；合并上游后执行 fork-patch.sh 重新应用："
    print "#   1) 模板/脚本下载地址 -> " fork "  2) 伪装站菜单 1-9 标题  3) 移除主菜单推广区广告"
    print "#   4) nginx 站点目录 -> " fork_site
    print "# <<< fork-lock"
    next
}
{ print }' -v fork_site="${SITE_DIR_FORK}"
    fi

    # 6. 还原行尾、校验并落地
    if [[ "${orig_eol}" == "crlf" ]]; then
        sed 's/$/\r/' "${work}" >"${work}.eol"
        mv "${work}.eol" "${work}"
    fi

    if [[ "${kind}" == "sh" ]] && ! bash -n "${work}" 2>/dev/null; then
        rm -rf "${work_dir}"
        die "语法校验失败：${target} 未改动"
    fi

    if cmp -s "${work}" "${target}"; then
        rm -rf "${work_dir}"
        echo "fork-patch: ${target} 无需改动（定制已就位）"
    else
        cp "${target}" "${target}.forkpatch.bak"
        cat "${work}" >"${target}"
        rm -rf "${work_dir}"
        echo "fork-patch: ${target} 已重新应用定制（原文件备份：${target}.forkpatch.bak）"
    fi
}

# -------------------------------------------------------------
# 入口
# -------------------------------------------------------------
if [[ $# -gt 0 ]]; then
    [[ -f "$1" ]] || die "找不到目标文件：$1"
    # 指定文件时按文件名识别定制范围
    spec=""
    for entry in "${TARGET_SPECS[@]}"; do
        IFS='|' read -r spec_path spec_menu spec_ad spec_sitedir spec_header spec_kind <<<"${entry}"
        if [[ "$(basename "${spec_path}")" == "$(basename "$1")" ]]; then
            spec="${spec_menu}|${spec_ad}|${spec_sitedir}|${spec_header}|${spec_kind}"
            break
        fi
    done
    [[ -n "${spec}" ]] || die "未知的定制范围：$1（请加入 TARGET_SPECS）"
    IFS='|' read -r spec_menu spec_ad spec_sitedir spec_header spec_kind <<<"${spec}"
    fork_patch_file "$1" "${spec_menu}" "${spec_ad}" "${spec_sitedir}" "${spec_header}" "${spec_kind}"
    exit 0
fi

patched=0
for entry in "${TARGET_SPECS[@]}"; do
    IFS='|' read -r spec_path spec_menu spec_ad spec_sitedir spec_header spec_kind <<<"${entry}"
    if [[ ! -f "${SCRIPT_DIR}/${spec_path}" ]]; then
        echo "fork-patch: 跳过不存在的 ${spec_path}"
        continue
    fi
    fork_patch_file "${SCRIPT_DIR}/${spec_path}" "${spec_menu}" "${spec_ad}" "${spec_sitedir}" "${spec_header}" "${spec_kind}"
    patched=$((patched + 1))
done
[[ "${patched}" -gt 0 ]] || die "没有可处理的文件"
