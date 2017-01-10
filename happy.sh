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
sidekiq_pid_file=tmp/pids/sidekiq.pid

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

mobile_asset_check() {
    local current_app=$(cat .current-app)
    local asset_name="$1"
    local zip_path="public/mobile_assets/${current_app}/${asset_name}.zip"

    if [[ -f ${zip_path} ]]; then
        cp ${zip_path} public/${asset_name}.zip
    else
        echo "WARNING: ${zip_path} not found"
    fi
}

mobile_assets_check() {
    mobile_asset_check "fonts"
    mobile_asset_check "images"
    mobile_asset_check "assets"
    mobile_asset_check "loading"
    mobile_asset_check "stylesheets"
    mobile_asset_check "javascripts"
    mobile_asset_check "advertisement"
    mobile_asset_check "BarCodeScan"
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
        mkdir -p {log/crontab,tmp/{rb,js,js.zip,pids,barcode,barcode.zip}} > /dev/null 2>&1
        mkdir -p public/gravatar > /dev/null 2>&1
        mobile_assets_check

        if [[ ! -f .unicorn-port ]]; then
            echo 4567 > .unicorn-port
            echo -e "\tgenerate .unicorn-port default 4567 $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        if [[ ! -f db/backup.sh ]]; then
            RACK_ENV=production $bundle_command exec rake g:script:backup:mysql_and_redis
            echo -e "\tgenerate db/backup.sh $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        if [[ ! -f log/backup.sh ]]; then
            RACK_ENV=production $bundle_command exec rake g:script:backup:log
            echo -e "\tgenerate log/backup.sh $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        if [[ ! -f config/redis.conf ]]; then
            RACK_ENV=production $bundle_command exec rake redis:generate_config
            echo -e "\tgenerate config/redis.conf $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        if [[ ! -f config/umeng_push_api_code_mapping.json ]]; then
            $bundle_command exec ruby lib/scripts/umeng_push_api_code_mapping.rb
            echo -e "\tgenerate config/umeng_push_api_code_mapping.json $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
        fi

        /bin/bash "$0" bundle
        RACK_ENV=production $bundle_command exec rake boom:setting
    ;;

    start)
        echo "## shell used: ${shell_used}"
        /bin/bash "$0" config

        /bin/bash "$0" redis:start
        /bin/bash "$0" sidekiq:start
        /bin/rm -f tmp/rb/*.rb > /dev/null 2>&1

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
        /bin/bash "$0" sidekiq:restart

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

    sidekiq:start)
        command_text="${bundle_command} exec sidekiq -r ./config/boot.rb -C ./config/sidekiq.yaml -e production -d"
        process_start "${sidekiq_pid_file}" 'sidekiq' "${command_text}"
    ;;

    sidekiq:stop)
        process_stop "${sidekiq_pid_file}" 'sidekiq'
    ;;

    sidekiq:restart)
        /bin/bash "$0" sidekiq:stop
        /bin/sleep 1
        echo -e '\n\n#-----------command sparate line----------\n\n'
        /bin/bash "$0" sidekiq:start
    ;;

    process_defender)
        process_checker "${redis_pid_file}" 'redis'
        process_checker "${sidekiq_pid_file}" 'sidekiq'
        process_checker "${unicorn_pid_file}" 'unicorn'
    ;;

    app_defender)
        echo -e $(date "+\n\n## app defender at %y-%m-%d %H:%M:%S\n")
        /bin/bash "$0" process_defender
        /bin/bash "$0" start
    ;;

    data:backup)
        timestamp=$(date "+%y%m%d%H%M%S")
        echo "mysqldump -hyonghui.idata.mobi -u -p yonghuibi > tmp/backup_$timestamp.sql"
    ;;

    data:import)
        usage="eg: $0 $1 remote_username remote_password local_password"
        [[ -z "$2" ]] && echo -e "\t# error:please tell remote database username\n\t${usage}" && exit
        [[ -z "$3" ]] && echo -e "\t# error:please tell remote database password\n\t${usage}" && exit
        [[ -z "$4" ]] && echo -e "\t# error:please tell local database password\n\t${usage}" && exit

        mysqldump -hyonghui.idata.mobi -u"$2" -p"$3" yonghuibi > tmp/remote-data.sql
        mysql -uroot -p"$4" yonghuibi < tmp/remote-data.sql

        run_state=$([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')
        echo -e '\t# import server database data to local'

        # bash "$0" copy_data "dev" "$4"
        # bash "$0" copy_data "test" "$4"
    ;;

    # only can run on my mac for unit test!
    data:copy)
        usage="eg: $0 $1 {dev,test} db_password"
        [[ -z "$2" ]] && echo -e "\t# error:please tell rack environment(dev/test)\n\t${usage}" && exit

        if [[ "$2" != "dev" && "$2" != "test" ]]; then
            echo -e "\t# error:rack environment only in (dev, test)\n\t${usage}" && exit
        fi

        db_name=$(test "$2" = "test" && echo "yonghuibi_test" || echo "yonghuibi_development")

        # echo "CREATE DATABASE ${db_name} DEFAULT CHARACTER SET UTF8 COLLATE UTF8_GENERAL_CI;"
        [[ -z "$3" ]] && echo -e "\t# error:please tell database password for ${db_name}(root)\n\t${usage}" && exit

        db_pwd="$3"
        mysqldump yonghuibi -uroot -p"${db_pwd}" --add-drop-table | mysql "${db_name}" -uroot -p"${db_pwd}"

        run_state=$(test $? -eq 0 && echo "successfully" || echo "failed")
        echo -e "\t# copy yonghuibi data to ${db_name} ${run_state}"
    ;;

    barcode)
        redis_key="*cache/barcode*$2*"
        echo "redis-cli keys '${redis_key}' | xargs -I key redis-cli get keys"
        redis-cli keys "${redis_key}" | xargs -I key redis-cli get key
    ;;

    system_monitor|sm)
        lib_utils_path=$(pwd)/lib/utils
        ruby -I ${lib_utils_path} -e 'load "simple_system_monitor.rb"; puts SimpleSystem::Monitor.report'
    ;;

    crontab:list)
        /usr/bin/crontab -l
    ;;
    crontab:edit)
        /usr/bin/crontab -e
    ;;
    crontab:clear)
        /usr/bin/crontab -r
    ;;
    crontab:update)
        $bundle_command exec whenever --update-crontab
    ;;

    git:push)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git push origin ${git_current_branch}
    ;;
    git:pull)
        git_current_branch=$(git rev-parse --abbrev-ref HEAD)
        git pull origin ${git_current_branch}
    ;;

    rspec:test)
        redis-cli keys '*:test*' | xargs redis-cli del
        $bundle_command exec rspec spec
    ;;
    rspec:seed)
        command_text="bundle exec rake seed:data:load RACK_ENV=test"
        echo "$ run \`${command_text}\`"
        ${command_text}
        echo "# task run $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
    ;;

    deploy:project)
        platform=$(uname -s | tr '[:upper:]' '[:lower:]')
        deploy_script="lib/scripts/deploy@${platform}.sh"

        if test ! -f ${deploy_script}
        then
            echo "Error: not found script ${deploy_script}"
            exit 2
        fi

        /bin/bash ${deploy_script}
    ;;

    deploy:init:seed)
        rack_env=production
        if [[ -n "$2" ]]; then
            rack_env="$2"
        fi

        command_text="bundle exec rake seed:data:load RACK_ENV=${rack_env} DISABLE_DATABASE_ENVIRONMENT_CHECK=1"
        echo "$ run \`${command_text}\`"
        ${command_text}
        echo "# task run $([[ $? -eq 0 ]] && echo 'successfully' || echo 'failed')"
    ;;
    deploy:server)
        git checkout ./
        /bin/bash "$0" git:pull
        /bin/bash "$0" crontab:update
        /bin/bash "$0" config
        RACK_ENV=production bundle exec rake db:migrate
    ;;

    assets:zip)
        app_name='null'
        if [[ -n "$2" ]]; then
            app_name="$2"
        fi

        public_dir=public/mobile_assets/${app_name}
        if [[ ! -d "$public_dir" ]]; then
            echo "error - unexpect app name: ${app_name}"
            exit
        fi

        /bin/cp app/assets/javascripts/report_template_v[1-9].js ./
        /usr/bin/zip javascripts.zip report_template_v[1-9].js
        /bin/mv javascripts.zip $public_dir
        /bin/rm report_template_v[1-9].js
        /usr/bin/unzip -v $public_dir/javascripts.zip

        /bin/cp app/assets/stylesheets/mobile*.css ./
        /usr/bin/zip stylesheets.zip mobile*.css
        /bin/mv stylesheets.zip $public_dir
        /bin/rm mobile*.css
        /usr/bin/unzip -v $public_dir/stylesheets.zip

        /usr/local/bin/git status
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
