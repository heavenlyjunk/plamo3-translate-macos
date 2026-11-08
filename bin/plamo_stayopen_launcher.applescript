-- PLaMo Translate: stay-open Dock launcher, with model selection on first run.
-- Export as Application with "Stay open after run handler" checked.

property serverWasSeen : false
property startedAt : missing value
property launchRequested : false

on run
    set serverWasSeen to false
    set launchRequested to false
    set startedAt to current date
    my openTranslator()
end run

on reopen
    if my serverIsRunning() then
        if my serverIsReady() then
            do shell script "/usr/bin/open http://127.0.0.1:7860/"
        else
            display dialog "選択済みのモデルを読み込んでいます。読み込みが完了すると翻訳画面が開きます。" buttons {"OK"} default button "OK"
        end if
    else
        if launchRequested then
            display dialog "モデルの起動処理中です。起動できない場合はログを確認してください。" buttons {"OK"} default button "OK"
        else
            my openTranslator()
        end if
    end if
end reopen

on openTranslator()
    if my serverIsRunning() then
        if my serverIsReady() then
            do shell script "/usr/bin/open http://127.0.0.1:7860/"
        end if
        return
    end if

    set optionsList to {"0.8B（最軽量）", "2B（軽量）", "8B（中規模）", "31B（最大）"}
    set chosenItems to choose from list optionsList with title "PLaMo 3 Translate" with prompt "起動するモデルを選択してください。" default items {"31B（最大）"} OK button name "起動" cancel button name "キャンセル" without multiple selections allowed
    if chosenItems is false then
        tell current application to quit
        return
    end if

    set selectionText to item 1 of chosenItems
    if selectionText starts with "0.8B" then
        set sizeKey to "0.8b"
    else if selectionText starts with "2B" then
        set sizeKey to "2b"
    else if selectionText starts with "8B" then
        set sizeKey to "8b"
    else
        set sizeKey to "31b"
    end if

    set homeDir to POSIX path of (path to home folder)
    set launcherPath to homeDir & "MyProject/bin/start_plamo.sh"
    set logDir to homeDir & "Library/Application Support/PLaMoTranslate"
    do shell script "/bin/mkdir -p " & quoted form of logDir
    set shellCommand to "/usr/bin/nohup /bin/bash " & quoted form of launcherPath & " " & quoted form of sizeKey & " >> " & quoted form of (logDir & "/dock_launcher.log") & " 2>&1 < /dev/null &"
    set launchRequested to true
    set startedAt to current date
    do shell script shellCommand
end openTranslator

on serverIsRunning()
    set homeDir to POSIX path of (path to home folder)
    set pidFile to homeDir & "Library/Application Support/PLaMoTranslate/server.pid"
    set guiScript to homeDir & "MyProject/bin/translate_gui.py"
    set commandText to "p=$(/bin/cat " & quoted form of pidFile & " 2>/dev/null) || exit 1; " & ¬
        "case \"$p\" in ''|*[!0-9]*) exit 1;; esac; " & ¬
        "/bin/ps -ww -p \"$p\" -o command= | /usr/bin/grep -Fq " & quoted form of guiScript
    try
        do shell script commandText
        return true
    on error
        return false
    end try
end serverIsRunning

on serverIsReady()
    try
        do shell script "/usr/bin/curl -fsS --connect-timeout 1 --max-time 2 http://127.0.0.1:7860/ > /dev/null"
        return true
    on error
        return false
    end try
end serverIsReady

on idle
    if my serverIsRunning() then
        set serverWasSeen to true
    else
        if serverWasSeen then
            tell current application to quit
        else if startedAt is not missing value then
            if ((current date) - startedAt) > 650 then
                tell current application to quit
            end if
        end if
    end if
    return 3
end idle

on quit
    if my serverIsRunning() then
        set homeDir to POSIX path of (path to home folder)
        set pidFile to homeDir & "Library/Application Support/PLaMoTranslate/server.pid"
        try
            do shell script "p=$(/bin/cat " & quoted form of pidFile & "); /bin/kill -TERM \"$p\""
        end try
    end if
    continue quit
end quit
