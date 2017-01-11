#!/usr/bin/env bash
#
# Description: script jobs around unicorn/redis/sidekiq/mysql
# Author: jay@16/02/03
#
# Usage:
# ./unicorn.sh {config|start|stop|start_redis|stop_redis|restart|deploy|update_assets|import_data|copy_data}
#
unicorn_default_port=$(cat .unicorn-port)
unicorn_port=${2:-${unicorn_default_port}}
unicorn_env=${3:-'production'}
unicorn_config_file=config/unicorn.rb

unicorn_pid_file=tmp/pids/unicorn.pid
redis_pid_file=tmp/pids/redis.pid

# user bash environment for crontab job.
# shell_used=${SHELL##*/}
app_root_path=$(pwd)
shell_used='bash'
[[ $(uname -s) = Darwin ]] && shell_used='zsh'

[[ -f ~/.${shell_used}rc ]] && source ~/.${shell_used}rc &> /dev/null
[[ -f ~/.${shell_used}_profile ]] && source ~/.${shell_used}_profile &> /dev/null

bundle_command=$(rbenv which bundle)
sidekiq_command=$(rbenv which sidekiq)
gem_command=$(rbenv which gem)

export LANG=zh_CN.UTF-8
# put below config lines added to ~/.bashrc to make
# sure *rbenv* work normally,
#
#   export PATH="$HOME/.rbenv/bin:$HOME/.rbenv/shims:$PATH"
#   export RBENV_ROOT="$HOME/.rbenv"
#   if which rbenv > /dev/null; then eval "$(rbenv init -)"; fi
#
# use the current .ruby-version's command

process_start() {
    local pid_file="$1"
    local process_name="$2"
    local command_text="$3"

    echo "## start ${process_name}"
    if [[ -f ${pid_file} ]]; then
        local pid=$(cat ${pid_file})
        /bin/ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
        if [[ $? -gt 0 ]]; then
            echo "${process_name} not running then remove ${pid_file}"
            [[ -f ${pid_file} ]] && rm -f ${pid_file} &> /dev/null
        fi

        echo -e "\t ${process_name} already started"
        exit 0
    fi

    echo -e "\t$ run \`${command_text}\`"
    run_result=$($command_text) #> /dev/null 2>&1
    echo -e "\t# ${process_name} start $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')(${run_result})"
}

process_stop() {
    local pid_file="$1"
    local process_name="$2"
    local exec_status='failed'
    echo "## stop ${process_name}"

    if [[ ! -f ${pid_file} ]]; then
        echo -e "\t ${process_name} never started"
        exit 1
    fi

    cat "${pid_file}" | xargs -I pid kill -QUIT pid
    if [[ $? -eq 0  ]]; then
        rm -f ${pid_file} &> /dev/null
        exec_status='successfully'
    fi
    echo -e "\t ${process_name} stop ${exec_status}"
}

process_checker() {
    local pid_file="$1"
    local process_name="$2"

    if [[ ! -f ${pid_file} ]]; then
        echo "process(${process_name}): pid file not exist - ${pid_file}"
        return 1
    fi

    local pid=$(cat ${pid_file})
    ps ax | awk '{print $1}' | grep -e "^${pid}$" &> /dev/null
    if [[ $? -gt 0 ]]; then
        echo "process(${process_name}) is not running"
        [[ -f ${pid_file} ]] && rm -f ${pid_file} &> /dev/null
        return 2
    fi

    echo "process(${process_name}) is running"
    return 0
}

cd "${app_root_path}" || exit 1
case "$1" in
    gem)
        shift 1
        $gem_command "$@"
    ;;

    bundle)
        echo '## bundle install'
        $bundle_command install --local > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
          echo -e '\tbundle install --local successfully'
        else
          $bundle_command install
        fi
    ;;

    config|conf)
        if [[ ! -f config/redis.conf ]]; then
            RACK_ENV=production $bundle_command exec rake redis:generate_config
            echo -e "\tgenerate config/redis.conf $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        /bin/bash "$0" bundle
        RACK_ENV=production $bundle_command exec rake boom:setting
    ;;

    start)
        /bin/mkdir -p ./{log,tmp/pids}
        echo "## shell used: ${shell_used}"
        $bundle_command exec rake redis:generate_config

        /bin/bash "$0" redis:start

        command_text="$bundle_command exec unicorn -c ${unicorn_config_file} -p ${unicorn_port} -E ${unicorn_env} -D"
        process_start "${unicorn_pid_file}" 'unicorn' "${command_text}"
        echo -e "\t# port: ${unicorn_port}, environment: ${unicorn_env}"
    ;;

    stop)
        process_stop "${unicorn_pid_file}" 'unicorn'
    ;;

    restart)
        /bin/cat "${unicorn_pid_file}" | xargs -I pid kill -USR2 pid
    ;;

    restart:force)
        /bin/bash "$0" stop
        /bin/sleep 1
        echo -e '\n\n#-----------command sparate line----------\n\n'
        /bin/bash "$0" start
    ;;

    redis:start)
        process_start "${redis_pid_file}" 'redis' 'redis-server ./config/redis.conf'
    ;;

    redis:stop)
        process_stop "${redis_pid_file}" 'redis'
    ;;

    redis:restart)
        /bin/bash "$0" redis:stop
        /bin/sleep 1
        echo -e '\n\n#-----------command sparate line----------\n\n'
        /bin/bash "$0" redis:start
    ;;

    git:push)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git push origin ${git_current_branch}
    ;;
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;


    *)
        echo "warning: unkown params - $@"
        echo
        echo "Usage: "
        echo "   $0 {conf|config}"
        echo "   $0 start,stop,restart,restart:force"
        echo "   $0 redis:{start,stop,restart}"
        echo "   $0 sidekiq:{start,stop,restart}"
        echo "   $0 barcode:bookmark"
        echo "   $0 data:{backup,import,copy}"
        echo "   $0 {sm|system_monitor}"
        echo "   $0 rspec{seed,test}}"
        echo "   $0 crontab:{list|edit|clear|update}"
        echo "   $0 git:{pull|push}"
        echo "   $0 deploy:{server,project,init:seed}"
        echo "   $0 assets:zip"
        exit 2
        ;;
esac
