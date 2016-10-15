define teamcity_agent::agent(
    $user        = 'teamcity',
    $server_url  = undef,
    $agent_name  = undef,
    $own_address = undef,
    $own_port    = undef,
    $properties  = undef,
    $port_base   = 9090,
    $with_cron   = true,
    $no_proxy    = false
) {
    $user_dir = "/home/${user}"
    $agent_root = "${user_dir}/agent"

    if ! is_integer($name) and $own_port == undef { 
        fail('Agent ports can only be autogenerated when $name is a number')
    }
    if $agent_name == undef {
        if is_integer($name) {
            $agent_name_auto = sprintf("${fqdn}-%02d", $name)
        } else {
            $agent_name_auto = $name
        }
        $agent_dir = "${agent_root}/${agent_name_auto}"
    } else {
        $agent_dir = "${agent_root}/${agent_name}"
    }
    if ! defined(Package['wget']) {
        package { 'wget': ensure => installed }
    } 
    if ! defined(Package['unzip']) {
        package { 'unzip': ensure => installed }
    } 
    if ! defined(File[$agent_root]) {
        file { $agent_root:
            ensure => directory,
            owner => $user
        } 
    }
    if $no_proxy {
        $wget_options = "--no-proxy"
    }
    $download_command = "wget ${wget_options} ${server_url}/update/buildAgent.zip"
    if ! defined(Exec[$download_command]) {
        exec { $download_command:
            cwd => $user_dir,
            path => '/usr/bin',
            creates => "${user_dir}/buildAgent.zip",
            user => $user,
            require => Package['wget']
        }
    }
    $unzip_command = "unzip buildAgent.zip -d ${agent_dir}"
    exec { $unzip_command:
        cwd => $user_dir,
        path => '/usr/bin',
        creates => $agent_dir,
        user => $user,
        require => [Package['unzip'], Exec[$download_command], File[$agent_root]]
    }
    file { "${agent_dir}/conf/buildAgent.properties":
        ensure => 'present',
        replace => 'no',
        content => template('teamcity_agent/buildAgent.properties.erb'),
        owner => $user,
        require => Exec[$unzip_command]
    }
    file { "${agent_dir}/bin/agent.sh":
        mode => '0755',
        require => Exec[$unzip_command]
    }
    if $with_cron and ! defined(Cron["teamcity_agent-${name}"]) {
        cron { "teamcity_agent-${name}":
            command => "${agent_dir}/bin/agent.sh start >/dev/null 2>&1",
            user => $user,
            minute => '*/5',
            require => File["${agent_dir}/bin/agent.sh"]
        }
    }
}