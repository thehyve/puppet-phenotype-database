# Custom type. Adds a new phenotypedbapp resource to the system.
#
# NB: Automation of steps described in : https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md
#
# == Parameters:
#
# $databasename:: (optional, defaults to 'gscf-www') e.g. 'gscfwww'
# $dbusername:: (optional, defaults to 'gscf')
# $dbuserpassword:: password in ?? format
# $appurl:: url of the instance (e.g. ?)
# $adminuserpwd:: (optional, defaults to 'admin123') app admin password
# $modules:: (optional, defaults to ['sam', 'metabolomics'] ) array with list of extra modules to install
#
define phenotypedb::phenotypedbapp (
    $vhost_servername,
    $dbuserpassword,
    $instancename,        /* e.g. 'testserver1' cases where we want multiple instances of gscf on the same server */
    $vhost_serveraliases, /* e.g. 'test.gscf.mysite.com' or an array of different aliases */
    $appurl,              /* include final slash, used in grails & gscf config file  */
    $databasename        = 'gscfwww',
    $dbusername          = 'gscf',
    $vhost_port          = undef,
    $adminuserpwd        = 'admin123',
    $modules             = [],

    $server              = 'https://ci.ctmmtrait.nl',
    $plan                = 'PD-PDM',
    $artifact            = 'PhenotypeDatabase-WAR/gscf-0.9.1.3.war',
    $phenotypedbwarid    = 9,

    $system_user         = 'phenotype',
    $number              = 0, /* related to tomcat port, but you can read this as the "server number", i.e. first server is 0, next one is 1, etc */
    $memory              = '512m', /* max memory size to allocate for tomcat */
    $webapp_base         = '/home',
    $base_domain         = '',
    $ssl                 = false,
    $ssl_cert            = undef,
    $ssl_key             = undef,
    $metabolomicsdb      = undef,
    $metabolomicsmongodb = undef,

    $proxytimeout        = 7200
) {
    # the dependencies:
    require phenotypedb
    require apache::mod::proxy_http

    # make database instance in postgresql with name $databasename,
    # and add the user defined in $dbusername
    postgresql::server::db { $databasename:
        user     => $dbusername,
        password => $dbuserpassword,
    }

    # add and configure tomcat instance for $system_user and deploy the phenotype .war to
    # the correct tomcat location:
    $tomcat_home    = "/home/$system_user"
    $download_dir   = "/opt/distr"
    $downloaded_war = "$download_dir/gscf-${instancename}.war"
    if $phenotypedbwarid == 'latest' {
        $download_url   = "${server}/browse/$plan/latest/artifact/shared/$artifact"
    }
    else {
        $download_url   = "${server}/browse/$plan-$phenotypedbwarid/artifact/shared/$artifact"
    }

    $uploaddir      = "$tomcat_home/uploads"

    tomcat_distr::webapp { $system_user:
        username         => $system_user,   # info: the tomcat_distr::webapp script already ensures user is created as well
        webapp_base      => $webapp_base,
        number           => $number,
        source           => $downloaded_war,
        context          => "gscf-${instancename}",
        listen_ajp       => true,
        clean_on_changed => true,
        java_opts        => "-server -Dorg.apache.jasper.runtime.BodyContentImpl.LIMIT_BUFFER=true \
                             -Dmail.mime.decodeparameters=true -Xms${memory} -Xmx${memory} \
                             -XX:MaxPermSize=256m -Djava.awt.headless=true",
    }

    file { "$tomcat_home/.gscf":
        ensure  => 'directory',
        mode    => '700',
        owner   => $system_user,
    }
    ->
    file { "$tomcat_home/.gscf/production.properties":
        ensure  => file,
        content => template("phenotypedb/production.properties"),
        mode    => '600',
        owner   => $system_user,
    }
    ->
    # deploy .war :
    exec { "download-phenotypedbapp-war-${downloaded_war}":
        # don't download it directly to webapps because tomcat will start
        # reading the war before the download is finished and error out on a
        # 'corrupt' zip file
        command => "/usr/bin/wget -O '${downloaded_war}' '${download_url}'",
        cwd     => $download_dir,
        creates => $downloaded_war,
        timeout => 1200,
    }
    ->
    file { $downloaded_war: }

    file { $uploaddir:
        ensure => 'directory',
        owner  => $system_user
    }

    $port = $vhost_port ? {
        undef   => $ssl ? { true => 443, default => 80 },
        default => $vhost_port,
    }
    apache_ext::vhost::proxy_ex { $instancename:
        vhost_servername    => $vhost_servername,
        vhost_serveraliases => $serveraliases,
        dest                => "balancer://gscf-cluster/gscf-$instancename/",
        port                => $port,
        enable_ssl          => $ssl,
        ssl_cert            => $ssl_cert,
        ssl_key             => $ssl_key,
        priority            => 10,
        template            => 'phenotypedb/gscf_site_apache.conf.erb',
        extra_variables     => {
            ajp_port        => "8${number}09",
            instancename    => $instancename,
            timeout         => $proxytimeout
        },
    }

    install_modules { $modules:
        base_domain => $base_domain,
        system_user => $system_user,
        ssl         => $ssl,
        ssl_cert    => $ssl_cert,
        ssl_key     => $ssl_key,
        metadb      => $metabolomicsdb,
        metamongodb => $metabolomicsmongodb,
        number      => $number,
        appurl      => $appurl,
    }
}

define install_modules(
    $base_domain,
    $system_user,
    $ssl      = false,
    $ssl_cert = undef,
    $ssl_key  = undef,
    $metadb   = undef,
    $metamongodb = 'metabolomicsModuleWWW',
    $number   = undef,
    $appurl   = undef,
) {
    case $name {
        "metabocloud$system_user": {
            metabocloud::install { "metabocloud": 
                destination => "/var/www/metabocloud.com/",
                domain      => "www.metabocloud.com",
            }
        }
        "metabolomics$system_user": {
            metabolomics_module::install { "metabolomics_module_$system_user":
                domain      => "metabolomics.$base_domain",
                base_url    => $base_domain,
                system_user => $system_user,
                ssl         => $ssl,
                ssl_cert    => $ssl_cert,
                ssl_key     => $ssl_key,
		metadb	    => $metadb,
		mongodb     => $metamongodb,
		number	    => $number,
		appurl	    => $appurl,
            }
        }
        "sam": {
            $vhost_port       = 80
            $vhost_name       = '*'
            $serveraliases    = ''
            $vhost_accessLog  = true
            $vhost_servername = "sam.$base_domain"
            $vhost_dest       = "balancer://gscf-cluster/sam/"
            $number           = "1"
            $instancename     = "sam"

            apache_ext::vhost::proxy { "sam":
                servername            => "sam.$base_domain",
                port                  => 80,
                dest                  => "balancer://gscf-cluster/sam/",
                vhost_name            => '*',
                configuration_content => template("phenotypedb/sam_conf.erb"),
            }
        }
    }
}
