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
    $databasename     = 'gscfwww',
    $dbusername       = 'gscf',
    $dbuserpassword,
    $appurl,          /* include final slash, used in grails & gscf config file  */
    $vhost_servername,
    $vhost_serveraliases, /* e.g. 'test.gscf.mysite.com' or an array of different aliases */
    $vhost_port       = 80,
    $adminuserpwd     = 'admin123',
    $modules          = ['sam','metabolomics'],
    $phenotypedbwarid = '17',
    $instancename, /* e.g. 'testserver1' cases where we want multiple instances of gscf on the same server */
    $system_user      = 'phenotype',
    $number           = 0, /* related to tomcat port, but you can read this as the "server number", i.e. first server is 0, next one is 1, etc */
    $memory           = '512m', /* max memory size to allocate for tomcat */
    $webapp_base      = '/home'
) {
    # the dependencies:
    require phenotypedb
    require apache::mod::proxy_http
    require postgresql::server
    
    # make database instance in postgresql with name $databasename,
    # and add the user defined in $dbusername
    postgresql::db { $databasename:
        user     => $dbusername,
        password => $dbuserpassword,
    }


    # add and configure tomcat instance for $system_user and deploy the phenotype .war to 
    # the correct tomcat location: 
    $tomcat_home = "/home/$system_user"
    $temporary_dir  = "/tmp"
    $deployment_dir = "$tomcat_home/tomcat/webapps"
    $downloaded_war = "$temporary_dir/gscf-${instancename}.war"
    $deployed_war   = "$deployment_dir/gscf-${instancename}.war"
    $download_url   = "https://ci.ctmmtrait.nl/browse/PD-PDBM/latest/artifact/shared/PhenotypeDatabase-war/gscf-0.9.1.5.war"    
        
    tomcat::webapp { $system_user:
        username        => $system_user,   # info: the tomcat::webapp script already ensures user is created as well 
        webapp_base     => $webapp_base,
        number          => $number,
        java_opts       => "-server -Dorg.apache.jasper.runtime.BodyContentImpl.LIMIT_BUFFER=true -Dmail.mime.decodeparameters=true -Xms${memory} -Xmx${memory} -XX:MaxPermSize=128m -Djava.awt.headless=true",
    } 
    ->
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
    exec { "download-phenotypedbapp-war-${deployed_war}":
        # don't download it directly to webapps because tomcat will start
        # reading the war before the download is finished and error out on a
        # 'corrupt' zip file
        command => "/usr/bin/wget -O '${downloaded_war}' '${download_url}' \
                   && find '$deployment_dir' -name '*.war' -delete \
                   && mv '${downloaded_war}' '${deployed_war}'",
        creates => $deployed_war,
        timeout => 1200,
    }

    # these are set here as they are also used in the template further below:
    $vhost_name = '*'
    $serveraliases = $vhost_serveraliases
    $vhost_accessLog = true
    $vhost_dest = "balancer://gscf-cluster/gscf-$instancename/"
    # make sure necessary apache mods are available and 
    # add new virtual host in apache:  
    apache_ext::vhost::proxy { $instancename:
        servername => $vhost_servername,
        port       => $vhost_port,
        dest       => $vhost_dest,
        vhost_name => $vhost_name,
        configuration_content   => template("phenotypedb/gscf_site_apache.conf.erb"),
    }

  # install modules (sam, metabolomics, etc)
  # TODO
}
