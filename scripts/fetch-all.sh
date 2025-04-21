#!/bin/bash

set -e

error(){
    echo "ERROR: $*" 2>&1
}

warn(){
    echo "WARN: $*" 2>&1
}

info(){
    echo "INFO: $*"
}

move() {
    local file=$1
    local dest=$2
    mv "$file" "$dest" || return 1
    [ -f "$file.sig" ] && { mv "$file.sig" "$dest" || return 1; }
    return 0
}

remove() {
    local file=$1
    rm "$file" || return 1
    [ -f "$file.sig" ] && { rm "$file.sig" || return 1; }
    return 0
}

gpg="gpg --no-default-keyring --keyring keyring.gpg"
keyserver="keyserver.ubuntu.com"
processed=()
declare -a no_signature
declare -a verify_failed

verify(){
    local file=$1
    if ! missing_key=$($gpg --verify "$file".sig 2>&1); then
        [ -n "$2" ] && { error "Failed to verify $file"; return 1; }
        key=$(<<<"$missing_key" sed -nE 's/^.*using DSA key (.*)$/\1/p')
        echo "key missing! Trying to fetch key $key from $keyserver"
        $gpg  --keyserver "$keyserver" --recv-keys "$key"
        verify "$file" retrying
    fi;
}

fetch() {
    local file=$1
    if curl -OsSLf "https://ftp.gnu.org/gnu/bash/$file"; then
        if curl -OsSLf "https://ftp.gnu.org/gnu/bash/$file.sig"; then
            if ! verify "$file"; then
                verify_failed+=("$file")
                return 1;
            fi
        else
            warn "Failed to fetch signature for $file"
            no_signature+=("$file")
        fi
    else
        error "Failed to fetch $file"
        return 1
    fi
}

unpack_dir_doc(){
    <<<"$1" sed -E 's/^bash-doc-(.*)\.tar\.gz$/bash-\1/'
}

unpack_dir(){
    <<<"$1" sed -E 's/^bash-(.*)\.tar\.gz$/bash-\1/'
}


get() {
    local file=$1
    local dir=$2
    info "Trying to fetch documentation for $dir"
    mkdir -p "$dir"
    target_file="$dir/bashref.html"
    if [ -f "$target_file" ]; then
        warn "File $file has already been fetched, not the case, delete $target_file and try again"
        return 0
    fi
    fetch "$file"||return 1
    move "$file" "$dir"
    loc_in_tar=$(tar -C "$dir" -tf "$dir/$file" --no-anchored "bashref.html")
    if ! tar -C "$dir" -xf "$dir/$file" "$loc_in_tar" ; then
        error "Failed to extract documentation from $file"
        return 1
    fi
    mv "$dir/$loc_in_tar" "$target_file"
    rmdir -p "$(dirname "$dir/$loc_in_tar")" 2>/dev/null||:
    remove "$dir/$file"
    info "Documentation successfully written to $target_file"
}
install_file() {
    local file=$1
    local dir=$2
    if [ -n "$INSTALL_DIR" ]; then
        if [ -e "$INSTALL_DIR/$dir" ]; then
            warn "$INSTALL_DIR/$dir already exists, not installing"
            return 0
        fi
        cp -r "$dir" "$INSTALL_DIR"
    fi
}

get_from_doc_dist() {
    local file=$1
    local date=$2
    local dir
    dir=$(unpack_dir_doc "$file")||{ error "Failed to create directory name for $file"; return 1; }
    get "$file" "$dir"
    install_file "$file" "$dir"
    processed+=("{\"version\": \"$dir\", \"date\": \"$date\"}")
}

get_from_main_tar() {
    local file=$1
    local date=$2
    local dir
    dir=$(unpack_dir "$file")||{ error "Failed to create directory name for $file"; return 1; }
    get "$file" "$dir"
    install_file "$file" "$dir"
    processed+=("{\"version\": \"$dir\", \"date\": \"$date\"}")
}

write_processed() {
    out=bash_versions.json
    {
        echo "["
        printf "    %s" "${processed[1]}"
        for ((i = 1; i < ${#processed[@]}; i++)) do
            printf ",\n    %s" "${processed[$i]}"
        done
        printf "\n]"
    } > "$out"

    if [ -n "$JINSTALL_DIR" ] && [[ $(realpath "$JINSTALL_DIR") != $(realpath .) ]]; then
        cp "$out" "$JINSTALL_DIR/$out"
    fi
}

main() {
    [ -n "$INSTALL_DIR" ] || { warn "Install directory not specified"; }
    [ -n "$JINSTALL_DIR" ] || { warn "Json install directory not specified"; }


    get_from_doc_dist  bash-doc-2.0.tar.gz    1996-12-31
    get_from_doc_dist  bash-doc-2.01.tar.gz   1997-06-05
    get_from_doc_dist  bash-doc-2.02.tar.gz   1998-04-18
    get_from_doc_dist  bash-doc-2.03.tar.gz   1999-02-19
    get_from_doc_dist  bash-doc-2.04.tar.gz   2000-03-21
    get_from_doc_dist  bash-doc-2.05.tar.gz   2001-04-09
    get_from_doc_dist  bash-doc-2.05a.tar.gz  2001-11-16
    get_from_doc_dist  bash-doc-2.05b.tar.gz  2002-07-17
    get_from_doc_dist  bash-doc-3.0.tar.gz    2004-08-03
    get_from_doc_dist  bash-doc-3.1.tar.gz    2005-12-08
    get_from_doc_dist  bash-doc-3.2.tar.gz    2006-10-11

    get_from_main_tar bash-4.0.tar.gz         2009-02-20
    get_from_main_tar bash-4.1.tar.gz         2009-12-31
    get_from_main_tar bash-4.2.tar.gz         2011-02-13
    get_from_main_tar bash-4.2.53.tar.gz      2014-11-07
    get_from_main_tar bash-4.3.tar.gz         2014-02-26
    get_from_main_tar bash-4.3.30.tar.gz      2014-11-07
    get_from_main_tar bash-4.4-beta.tar.gz    2015-10-12
    get_from_main_tar bash-4.4-beta2.tar.gz   2016-07-11
    get_from_main_tar bash-4.4-rc1.tar.gz     2016-02-24
    get_from_main_tar bash-4.4-rc2.tar.gz     2016-08-22
    get_from_main_tar bash-4.4.tar.gz         2016-09-15
    get_from_main_tar bash-4.4.12.tar.gz      2017-10-13
    get_from_main_tar bash-4.4.18.tar.gz      2018-01-30
    get_from_main_tar bash-5.0-alpha.tar.gz   2018-05-22
    get_from_main_tar bash-5.0-beta.tar.gz    2018-09-17
    get_from_main_tar bash-5.0-beta2.tar.gz   2018-11-28
    get_from_main_tar bash-5.0-rc1.tar.gz     2018-12-20
    get_from_main_tar bash-5.0.tar.gz         2019-01-07
    get_from_main_tar bash-5.1-alpha.tar.gz   2020-06-16
    get_from_main_tar bash-5.1-beta.tar.gz    2020-09-09
    get_from_main_tar bash-5.1-rc1.tar.gz     2020-10-05
    get_from_main_tar bash-5.1-rc2.tar.gz     2020-11-03
    get_from_main_tar bash-5.1-rc3.tar.gz     2020-11-17
    get_from_main_tar bash-5.1.tar.gz         2020-12-06
    get_from_main_tar bash-5.1.8.tar.gz       2021-06-15
    get_from_main_tar bash-5.1.12.tar.gz      2022-01-04
    get_from_main_tar bash-5.1.16.tar.gz      2022-01-04
    get_from_main_tar bash-5.2-alpha.tar.gz   2022-01-20
    get_from_main_tar bash-5.2-beta.tar.gz    2022-04-13
    get_from_main_tar bash-5.2-rc1.tar.gz     2022-06-17
    get_from_main_tar bash-5.2-rc2.tar.gz     2022-07-25
    get_from_main_tar bash-5.2-rc3.tar.gz     2022-08-26
    get_from_main_tar bash-5.2-rc4.tar.gz     2022-09-09
    get_from_main_tar bash-5.2.tar.gz         2022-09-26
    get_from_main_tar bash-5.2.9.tar.gz       2022-11-07
    get_from_main_tar bash-5.2.15.tar.gz      2022-12-13
    get_from_main_tar bash-5.2.21.tar.gz      2023-11-09
    get_from_main_tar bash-5.3-alpha.tar.gz   2024-04-22
    get_from_main_tar bash-5.2.32.tar.gz      2024-08-02
    get_from_main_tar bash-5.2.37.tar.gz      2024-09-23
    get_from_main_tar bash-5.3-beta.tar.gz    2024-12-17
    get_from_main_tar bash-5.3-rc1.tar.gz     2025-04-07

    write_processed

}


main
