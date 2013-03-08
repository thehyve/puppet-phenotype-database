# Custom type. Adds a new phenotypedbapp resource to the system.
#
# NB: Automation of : https://github.com/thehyve/GSCF/blob/master/INSTALLATION.md
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
class phenotypedb::phenotypedbapp (
    $databasename     = 'gscfwww',
    $dbusername       = 'gscf',
    $dbuserpassword,
    $appurl,          /* include final slash */
    $vhost_servername,
    $adminuserpwd     = 'admin123',
    $modules          = ['sam','metabolomics'],
    $phenotypedbwarid = '17',
    $system_user      = 'phenotype',
    $number           = 0,
    $memory           = '512m',
    $webapp_base      = '/home'
) {
    require phenotypedb
    require apache::mod::proxy_http
    include postgresql::server

    # make database instance in postgresql with name $databasename,
    # and add the user defined in $dbusername
    postgresql::db { $databasename:
        user     => $dbusername,
        password => $dbuserpassword,
    }

    $tomcat_home = "/home/$system_user"


    $temporary_dir  = "/tmp"
    $deployment_dir = "$tomcat_home/tomcat/webapps"
    $downloaded_war = "$temporary_dir/gscf-${phenotypedbwarid}.war"
    $deployed_war   = "$deployment_dir/gscf-${phenotypedbwarid}.war"
    $download_url   = "https://trac.nbic.nl/gscf/downloads/${phenotypedbwarid}"

    tomcat::webapp { $system_user:
        username        => $system_user,
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
    exec { "download-phenotypedbapp-war":
        # don't download it directly to webapps because tomcat will start
        # reading the war before the download is finished and error out on a
        # 'corrupt' zip file
        command => "/usr/bin/wget -O '${downloaded_war}' '${download_url}' \
                   && find '$deployment_dir' -name '*.war' -delete \
                   && mv '${downloaded_war}' '${deployed_war}'",
        creates => $deployed_war,
        timeout => 1200,
    }

    apache::mod { 'rewrite': }
    ->
    apache::mod { 'proxy_balancer': }
    ->
    apache::mod { 'proxy_ajp': }
    ->
    apache::mod { 'proxy_html': }
    ->
    apache::vhost::proxy { 'gscf':
        servername => $vhost_servername,
        port       => 80,
        dest       => "balancer://gscf-cluster/gscf-$phenotypedbwarid/",
        #dest       => "http://localhost:8080/gscf-${phenotypedbwarid}",
        vhost_name => '*',
        template   => 'phenotypedb/gscf_site_apache.conf.erb',
    }


  # install modules (sam, metabolomics, etc)
  # TODO
}
