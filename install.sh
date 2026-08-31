#!/usr/bin/env bash
# Installs/updates this repo's shared Codex config (AGENTS.md, skills, the
# [tui] status line) and regenerates the `codex` account-switch shell function
# from profiles.d/*.conf. Safe to re-run — every step is idempotent and
# existing real files are backed up before being replaced.
set -Eeuo pipefail

readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly BASE_DIR="$HOME/.codex"
readonly PROFILES_DIR="$REPO_DIR/profiles.d"
readonly SHELL_BLOCK_BEGIN="# >>> codex-profile >>>"
readonly SHELL_BLOCK_END="# <<< codex-profile <<<"

log() { printf '%s\n' "$1"; }

require_dependency() {
	command -v "$1" >/dev/null 2>&1 || {
		echo "error: '$1' is required but not found in PATH." >&2
		exit 1
	}
}

# Symlinks source_path -> target_path. Backs up whatever already exists at
# target_path (real file or a symlink pointing somewhere else) instead of
# clobbering it, so a first run never loses existing config.
link_shared_item() {
	local source_path="$1" target_path="$2"

	if [ -L "$target_path" ] && [ "$(readlink "$target_path")" = "$source_path" ]; then
		log "  already linked: $target_path"
		return 0
	fi

	if [ -e "$target_path" ] || [ -L "$target_path" ]; then
		local backup_path="${target_path}.bak.$(date +%Y%m%d%H%M%S)"
		mv "$target_path" "$backup_path"
		log "  backed up existing $target_path -> $backup_path"
	fi

	mkdir -p "$(dirname "$target_path")"
	ln -s "$source_path" "$target_path"
	log "  linked $target_path -> $source_path"
}

link_shared_files() {
	log "Linking shared config into $BASE_DIR..."
	link_shared_item "$REPO_DIR/shared/AGENTS.md" "$BASE_DIR/AGENTS.md"

	local skill_dir
	for skill_dir in "$REPO_DIR"/shared/skills/*/; do
		[ -d "$skill_dir" ] || continue
		local skill_name
		skill_name="$(basename "$skill_dir")"
		link_shared_item "${skill_dir%/}" "$BASE_DIR/skills/$skill_name"
	done
}

# config.toml is never symlinked into the repo: Codex rewrites it constantly
# (project trust levels, model selection, `codex mcp add`) and it holds MCP
# server definitions that may carry secrets. So the managed [tui] keys are
# rewritten IN PLACE and every other line is passed through untouched.
apply_status_line_config() {
	log "Applying the status line config to $BASE_DIR/config.toml..."
	local config_file="$BASE_DIR/config.toml"

	mkdir -p "$BASE_DIR"
	[ -f "$config_file" ] || : >"$config_file"
	cp "$config_file" "${config_file}.bak.$(date +%Y%m%d%H%M%S)"

	# The block is handed to awk as a FILE PATH, not as a -v value: BSD awk
	# (macOS) rejects newlines inside a -v assignment, so getline is what keeps
	# this working on both awk flavors.
	local block_file tmp_file
	block_file=$(mktemp)
	tmp_file=$(mktemp)
	grep -v '^#' "$REPO_DIR/shared/statusline.toml" | sed '/^$/d' >"$block_file"

	LC_ALL=C awk -v blockfile="$block_file" '
		function print_block(   line) {
			while ((getline line < blockfile) > 0) print line
			close(blockfile)
		}
		/^[ \t]*\[/ {
			skipping = 0
			in_tui = ($0 ~ /^[ \t]*\[tui\][ \t]*$/)
			print
			if (in_tui && !inserted) { print_block(); inserted = 1 }
			next
		}
		skipping { if (index($0, "]") > 0) skipping = 0; next }
		in_tui && /^[ \t]*(status_line|status_line_use_colors|terminal_title)[ \t]*=/ {
			if (index($0, "[") > 0 && index($0, "]") == 0) skipping = 1
			next
		}
		{ print }
		END { if (!inserted) { print ""; print "[tui]"; print_block() } }
	' "$config_file" >"$tmp_file"

	cat "$tmp_file" >"$config_file"
	rm -f "$tmp_file" "$block_file"
	log "  rewrote [tui] status_line / terminal_title (other keys preserved)"
}

# Profiles other than the base one (e.g. ~/.codex-betha) don't hold their own
# copy of the shared files — they mirror BASE_DIR, one hop away. config.toml is
# mirrored too, which is what makes MCP servers and the status line identical
# across accounts while auth.json, history and sessions stay per-profile.
# Runs after apply_status_line_config so BASE_DIR/config.toml already exists.
mirror_shared_files_into_other_profiles() {
	local conf_file
	for conf_file in "$PROFILES_DIR"/*.conf; do
		[ -f "$conf_file" ] || continue
		local PROFILE_CODEX_HOME=""
		# shellcheck source=/dev/null
		source "$conf_file"
		[ -z "$PROFILE_CODEX_HOME" ] && continue
		[ "$PROFILE_CODEX_HOME" = "$BASE_DIR" ] && continue

		log "Mirroring shared config into $PROFILE_CODEX_HOME..."
		mkdir -p "$PROFILE_CODEX_HOME"
		link_shared_item "$BASE_DIR/AGENTS.md" "$PROFILE_CODEX_HOME/AGENTS.md"
		link_shared_item "$BASE_DIR/skills" "$PROFILE_CODEX_HOME/skills"
		link_shared_item "$BASE_DIR/config.toml" "$PROFILE_CODEX_HOME/config.toml"
	done
}

# profiles.d/*.conf is machine-local (gitignored) — a fresh clone starts
# empty. Seed it with a single default profile so `codex` works right away.
bootstrap_default_profile() {
	mkdir -p "$PROFILES_DIR"
	if ! ls "$PROFILES_DIR"/*.conf >/dev/null 2>&1; then
		cp "$REPO_DIR/profiles.d/personal.conf.example" "$PROFILES_DIR/personal.conf"
		log "  created $PROFILES_DIR/personal.conf from template"
	fi
}

# Builds the invocation for one profile. A profile pointed at ~/.codex runs
# with CODEX_HOME unset rather than set to its own default, so that a stale
# exported CODEX_HOME from an outer shell can never leak into it.
build_profile_invocation() {
	local codex_home="$1" theme="$2" extra_flags="$3"
	local flags=""
	[ -n "$theme" ] && flags+=" -c tui.theme=$(printf '%q' "$theme")"
	[ -n "$extra_flags" ] && flags+=" $extra_flags"

	if [ "$codex_home" = "$HOME/.codex" ]; then
		printf 'command env -u CODEX_HOME codex%s' "$flags"
	else
		printf 'CODEX_HOME=%q command codex%s' "$codex_home" "$flags"
	fi
}

# Codex has no command-based status line — its [tui].status_line is a fixed
# catalog of built-in items with no free-text entry, so the profile's label
# and color cannot be rendered inside the TUI the way they are on Claude
# Code's statusline. This banner is the stand-in: one line, printed only when
# stdout is a terminal so it never pollutes a pipe.
generate_shell_function_block() {
	local case_body="" default_case_line=""
	local conf_file

	for conf_file in "$PROFILES_DIR"/*.conf; do
		[ -f "$conf_file" ] || continue

		local PROFILE_COMMAND="" PROFILE_CODEX_HOME="" PROFILE_LABEL="" PROFILE_COLOR="" \
			PROFILE_IS_DEFAULT="false" PROFILE_THEME="" PROFILE_EXTRA_CODEX_FLAGS=""
		# shellcheck source=/dev/null
		source "$conf_file"

		local invocation
		invocation="$(build_profile_invocation "$PROFILE_CODEX_HOME" "$PROFILE_THEME" "$PROFILE_EXTRA_CODEX_FLAGS")"
		local launch
		launch="$(printf '_codex_profile_banner %q %q; %s' "$PROFILE_LABEL" "$PROFILE_COLOR" "$invocation")"

		case_body+=$(printf '\t%s) shift; %s "$@" ;;\n' "$PROFILE_COMMAND" "$launch")
		case_body+=$'\n'

		if [ "$PROFILE_IS_DEFAULT" = "true" ]; then
			default_case_line=$(printf '\t*)        %s "$@" ;;' "$launch")
		fi
	done

	cat <<SCRIPT
$SHELL_BLOCK_BEGIN
# Generated by install.sh from profiles.d/*.conf — do not edit by hand.
_codex_profile_banner() {
	[ -t 1 ] || return 0
	local label="\$1" hex="\$2"
	printf '\\033[1m\\033[38;2;%d;%d;%dm%s\\033[0m\\n' \\
		"\$((16#\${hex:0:2}))" "\$((16#\${hex:2:2}))" "\$((16#\${hex:4:2}))" "\$label"
}

codex() {
	case "\$1" in
${case_body}${default_case_line}
	esac
}
$SHELL_BLOCK_END
SCRIPT
}

# Replaces the block between the markers (if present) and appends the fresh
# one — safe to run repeatedly without duplicating or losing the rest of the
# rc file's content.
update_shell_rc_block() {
	local rc_file="$1" new_block="$2"
	[ -f "$rc_file" ] || return 0

	cp "$rc_file" "${rc_file}.bak.$(date +%Y%m%d%H%M%S)"

	local tmp_file
	tmp_file=$(mktemp)
	if grep -qF "$SHELL_BLOCK_BEGIN" "$rc_file"; then
		LC_ALL=C awk -v begin="$SHELL_BLOCK_BEGIN" -v end="$SHELL_BLOCK_END" '
			$0 == begin {skip=1}
			!skip {print}
			$0 == end {skip=0}
		' "$rc_file" >"$tmp_file"
	else
		cp "$rc_file" "$tmp_file"
	fi

	{
		cat "$tmp_file"
		echo
		printf '%s\n' "$new_block"
	} >"$rc_file"
	rm -f "$tmp_file"
	log "  updated $rc_file"
}

install_shell_function() {
	log "Updating the codex() shell function..."
	local block
	block="$(generate_shell_function_block)"
	update_shell_rc_block "$HOME/.zshrc" "$block"
	update_shell_rc_block "$HOME/.bashrc" "$block"
}

main() {
	require_dependency awk

	bootstrap_default_profile
	link_shared_files
	apply_status_line_config
	mirror_shared_files_into_other_profiles
	install_shell_function

	log ""
	log "Done. Open a new shell (or run 'exec \$SHELL') to pick up the codex() function."
}

main
